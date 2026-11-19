// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show TimeoutException;
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:hooks/hooks.dart';

import 'hashes.dart' show fileHashes, releaseRepository, releaseTag;
import 'targets.dart'
    show libraryFileName, releaseAssetName, releaseAssetUrl, targetTripleFor;

/// How long to wait for the connection and for each response.
const _connectionTimeout = Duration(seconds: 30);

/// How long to wait for the whole library to download.
const _downloadTimeout = Duration(minutes: 5);

const _checkoutHint =
    'To build boring locally from source instead, set '
    '`buildMode: checkout` in your pubspec.yaml under '
    '`hooks.user_defines.boring`.';

/// Downloads and verifies the pre-built library for the target of [input] from
/// the GitHub release [releaseTag] of [releaseRepository], caching it in
/// [HookInput.outputDirectoryShared].
///
/// Throws a [BuildError] if no hash is registered in [fileHashes] for the
/// target, if downloading fails, or if the downloaded file's SHA-256 checksum
/// does not match [fileHashes].
Future<Uri> fetchPrebuiltLibrary(
  HookInput input, {
  required bool static,
}) async {
  final targetOS = input.config.code.targetOS;
  final targetArch = input.config.code.targetArchitecture;
  final iosSdk = targetOS == OS.iOS ? input.config.code.iOS.targetSdk : null;

  final assetRemoteName = releaseAssetName(
    targetOS,
    targetArch,
    iosSdk: iosSdk,
    static: static,
  );
  final expectedHash = fileHashes[assetRemoteName];

  if (expectedHash == null || expectedHash.isEmpty) {
    final target = targetTripleFor(targetOS, targetArch, iosSdk: iosSdk);
    throw BuildError(
      message:
          'No prebuilt boring binary is available for $target '
          '($assetRemoteName) in release $releaseTag of $releaseRepository.\n'
          '$_checkoutHint',
    );
  }

  final fileName = libraryFileName(targetOS, static: static);
  final cachedFile = File.fromUri(
    input.outputDirectoryShared
        .resolve('$releaseTag/$assetRemoteName/')
        .resolve(fileName),
  );
  if (await cachedFile.exists()) {
    final cachedHash = sha256
        .convert(await cachedFile.readAsBytes())
        .toString();
    if (cachedHash == expectedHash) {
      stdout.writeln(
        'boring: using cached prebuilt binary ($assetRemoteName).',
      );
      return cachedFile.uri;
    }
  }

  final binaryUrl = releaseAssetUrl(
    repository: releaseRepository,
    tag: releaseTag,
    assetName: assetRemoteName,
  );
  stdout.writeln('boring: fetching prebuilt binary from $binaryUrl...');

  final bytes = await _download(binaryUrl);
  final actualHash = sha256.convert(bytes).toString();

  if (actualHash != expectedHash) {
    throw BuildError(
      message:
          'SHA256 hash mismatch for prebuilt binary $assetRemoteName.\n'
          'Expected: $expectedHash\n'
          'Actual:   $actualHash\n'
          '$_checkoutHint',
    );
  }

  stdout.writeln('boring: verified SHA256 checksum ($actualHash).');

  await cachedFile.parent.create(recursive: true);
  await cachedFile.writeAsBytes(bytes);
  return cachedFile.uri;
}

/// Downloads [url], or throws a [BuildError] if the download fails.
///
/// Honors the `HTTPS_PROXY` family of environment variables, which the hooks
/// runner passes through to hooks, and gives up on a connection that hangs.
/// Follows redirects, such as GitHub's to its release asset storage, only to
/// `https` URLs.
Future<List<int>> _download(Uri url) async {
  final client = HttpClient()
    ..connectionTimeout = _connectionTimeout
    ..findProxy = HttpClient.findProxyFromEnvironment;
  try {
    final response = await _getFollowingHttpsRedirects(client, url);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw BuildError(
        message:
            'Failed to download prebuilt boring binary from $url '
            '(HTTP ${response.statusCode}).\n'
            '$_checkoutHint',
      );
    }
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add).timeout(_downloadTimeout);
    return builder.takeBytes();
  } on IOException catch (e) {
    throw BuildError(
      message:
          'Network error downloading prebuilt boring binary from $url: $e\n'
          '$_checkoutHint',
    );
  } on TimeoutException catch (e) {
    throw BuildError(
      message:
          'Timed out downloading prebuilt boring binary from $url: $e\n'
          '$_checkoutHint',
    );
  } finally {
    client.close(force: true);
  }
}

/// The most redirects [_getFollowingHttpsRedirects] follows.
const _maxRedirects = 5;

/// Sends a GET request for [url] with [client] and follows redirects only to
/// `https` URLs, so that the request never leaves TLS, unlike [HttpClient]'s
/// own redirect handling, which also follows redirects to `http` URLs.
///
/// Throws a [BuildError] if [url] is not an `https` URL, for a redirect to
/// another scheme or an invalid redirect location, or for too many redirects.
Future<HttpClientResponse> _getFollowingHttpsRedirects(
  HttpClient client,
  Uri url,
) async {
  if (url.scheme != 'https') {
    throw BuildError(
      message:
          'Refusing to download the prebuilt boring binary from $url, which '
          'is not an https URL.\n'
          '$_checkoutHint',
    );
  }
  var currentUrl = url;
  for (var redirects = 0; ; redirects++) {
    final request = await client.getUrl(currentUrl).timeout(_connectionTimeout);
    request.followRedirects = false;
    final response = await request.close().timeout(_connectionTimeout);
    final location = response.headers.value(HttpHeaders.locationHeader);
    if (!response.isRedirect || location == null) return response;
    await response.drain<void>().timeout(_connectionTimeout);
    final Uri nextUrl;
    try {
      nextUrl = currentUrl.resolve(location);
    } on FormatException catch (e) {
      throw BuildError(
        message:
            'Received invalid redirect location "$location" from $currentUrl '
            'while downloading the prebuilt boring binary from $url: $e\n'
            '$_checkoutHint',
      );
    }
    if (nextUrl.scheme != 'https') {
      throw BuildError(
        message:
            'Refusing to follow the redirect from $currentUrl to $nextUrl, '
            'which is not an https URL, while downloading the prebuilt '
            'boring binary from $url.\n'
            '$_checkoutHint',
      );
    }
    if (redirects == _maxRedirects) {
      throw BuildError(
        message:
            'Too many redirects downloading the prebuilt boring binary from '
            '$url.\n'
            '$_checkoutHint',
      );
    }
    currentUrl = nextUrl;
  }
}
