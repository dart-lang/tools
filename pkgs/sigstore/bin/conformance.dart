// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'dart:io';

import 'package:args/args.dart';
import 'package:sigstore/sigstore.dart';

String _resolvePath(String path) {
  if (path.isEmpty || path.startsWith('/')) {
    return path;
  }
  final base =
      Platform.environment['CONFORMANCE_CWD'] ?? Directory.current.path;
  return '$base/$path';
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: conformance <sign-bundle|verify-bundle> [options] '
      '<artifact-file>',
    );
    exit(1);
  }

  final command = args[0];
  final restArgs = args.sublist(1);

  if (command == 'verify-bundle') {
    await _handleVerifyBundle(restArgs);
  } else if (command == 'sign-bundle') {
    await _handleSignBundle(restArgs);
  } else {
    stderr.writeln('Error: Unknown command "$command"');
    exit(1);
  }
}

Future<void> _handleVerifyBundle(List<String> args) async {
  final parser = ArgParser(allowTrailingOptions: true)
    ..addOption('bundle', mandatory: true)
    ..addOption('certificate-identity', mandatory: false)
    ..addOption('certificate-oidc-issuer', mandatory: false)
    ..addOption('key', mandatory: false)
    ..addOption('trusted-root', mandatory: false)
    ..addOption('signing-config', mandatory: false)
    ..addFlag('staging', defaultsTo: false)
    ..addFlag('offline', defaultsTo: false);

  ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    stderr.writeln('Error parsing arguments: $e');
    exit(1);
  }

  if (results.rest.isEmpty) {
    stderr.writeln('Error: Missing artifact argument');
    exit(1);
  }

  final artifactArg = results.rest.first;
  final bundlePath = _resolvePath(results['bundle'] as String);
  final expectedIdentity = results['certificate-identity'] as String? ?? '';
  final expectedIssuer = results['certificate-oidc-issuer'] as String? ?? '';
  final isOffline = results['offline'] as bool;
  final isStaging = results['staging'] as bool;

  final bundleFile = File(bundlePath);
  if (!bundleFile.existsSync()) {
    stderr.writeln('Error: Bundle file does not exist: $bundlePath');
    exit(1);
  }

  String bundleJson;
  try {
    bundleJson = await bundleFile.readAsString();
  } catch (e) {
    stderr.writeln('Error reading bundle file: $e');
    exit(1);
  }

  var trustedRootJson = '';
  if (results['trusted-root'] != null) {
    final trPath = _resolvePath(results['trusted-root'] as String);
    final trFile = File(trPath);
    if (trFile.existsSync()) {
      trustedRootJson = await trFile.readAsString();
    }
  }

  var publicKeyPem = '';
  if (results['key'] != null) {
    final keyPath = _resolvePath(results['key'] as String);
    final keyFile = File(keyPath);
    if (keyFile.existsSync()) {
      publicKeyPem = await keyFile.readAsString();
    }
  }

  var isDigest = false;
  List<int> artifactBytes;
  if (artifactArg.startsWith('sha256:')) {
    isDigest = true;
    final hexStr = artifactArg.substring('sha256:'.length);
    artifactBytes = _hexToBytes(hexStr);
  } else {
    final resolvedArtifact = _resolvePath(artifactArg);
    final artifactFile = File(resolvedArtifact);
    if (!artifactFile.existsSync()) {
      stderr.writeln('Error: Artifact file does not exist: $resolvedArtifact');
      exit(1);
    }
    artifactBytes = await artifactFile.readAsBytes();
  }

  try {
    final client = SigstoreClient.create();
    final bundle = SigstoreBundle.fromJson(bundleJson);
    final policy = SigstoreVerificationPolicy.create(
      expectedIdentity,
      expectedIssuer,
      isOffline,
      isStaging,
      trustedRootJson,
      publicKeyPem,
    );

    final result = client.verify(artifactBytes, isDigest, bundle, policy);
    if (result.isValid()) {
      print('OK: Verification successful');
      exit(0);
    } else {
      stderr.writeln('FAIL: Verification failed');
      exit(1);
    }
  } catch (e) {
    stderr.writeln('FAIL: Verification error: $e');
    exit(1);
  }
}

Future<void> _handleSignBundle(List<String> args) async {
  stderr.writeln(
    'FAIL: Keyless signing is not supported by this verification-only client.',
  );
  exit(1);
}

List<int> _hexToBytes(String hex) {
  if (hex.length % 2 != 0) {
    throw const FormatException('Hex string must have an even length');
  }
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}
