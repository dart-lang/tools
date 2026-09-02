// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'dart:io';
import 'package:sigstore/sigstore.dart';

void main() async {
  print('Initializing Sigstore Dart Client...');
  final client = SigstoreClient.create();
  print('Client created successfully.');

  final fixtureFile = File('test/fixtures/sample_bundle.json');
  final artifactFile = File('test/fixtures/a.txt');

  if (!fixtureFile.existsSync() || !artifactFile.existsSync()) {
    print('Sample fixture files not found.');
    return;
  }

  final bundleJson = await fixtureFile.readAsString();
  final artifactBytes = await artifactFile.readAsBytes();

  print('Parsing Sigstore Bundle...');
  final bundle = SigstoreBundle.fromJson(bundleJson);
  print('Rekor Log Index: ${bundle.getRekorLogIndex()}');

  print('Verifying artifact...');
  final policy = SigstoreVerificationPolicy.create(
    'https://github.com/sigstore-conformance/extremely-dangerous-public-oidc-beacon/.github/workflows/extremely-dangerous-oidc-beacon.yml@refs/heads/main',
    'https://token.actions.githubusercontent.com',
    true,
    false,
    '',
    '',
  );

  final result = client.verify(artifactBytes, false, bundle, policy);

  print('Verification valid: ${result.isValid()}');
  print('Verified Identity: ${result.verifiedIdentity()}');
  print('Verified Issuer: ${result.verifiedIssuer()}');
}
