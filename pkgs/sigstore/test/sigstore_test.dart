// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:sigstore/sigstore.dart';
import 'package:test/test.dart';

void main() {
  late String fixtureBundleJson;
  late List<int> artifactBytes;

  setUpAll(() async {
    final fixtureFile = File('test/fixtures/sample_bundle.json');
    fixtureBundleJson = await fixtureFile.readAsString();
    final artifactFile = File('test/fixtures/a.txt');
    artifactBytes = await artifactFile.readAsBytes();
  });

  group('SigstoreClient', () {
    test('creates client instance', () {
      final client = SigstoreClient.create();
      expect(client, isNotNull);
    });

    test('parses bundle from JSON and inspects metadata', () {
      final bundle = SigstoreBundle.fromJson(fixtureBundleJson);
      expect(bundle, isNotNull);

      final logIndex = bundle.getRekorLogIndex();
      expect(logIndex, equals(79571823));

      final exportedJson = bundle.toJson();
      expect(exportedJson, isNotNull);
      final decoded = jsonDecode(exportedJson) as Map<String, Object?>;
      expect(
        decoded['mediaType'],
        equals('application/vnd.dev.sigstore.bundle.v0.3+json'),
      );
    });

    test('throws SigstoreError on invalid bundle JSON', () {
      expect(
        () => SigstoreBundle.fromJson('not-a-valid-json'),
        throwsA(isA<SigstoreError>()),
      );
    });

    test('verifies artifact with policy', () {
      final client = SigstoreClient.create();
      final bundle = SigstoreBundle.fromJson(fixtureBundleJson);

      final policy = SigstoreVerificationPolicy.create(
        'https://github.com/sigstore-conformance/extremely-dangerous-public-oidc-beacon/.github/workflows/extremely-dangerous-oidc-beacon.yml@refs/heads/main',
        'https://token.actions.githubusercontent.com',
        true,
        false,
        '',
        '',
      );

      final result = client.verify(artifactBytes, false, bundle, policy);

      expect(result.isValid(), isTrue);
      expect(
        result.verifiedIdentity(),
        equals(
          'https://github.com/sigstore-conformance/extremely-dangerous-public-oidc-beacon/.github/workflows/extremely-dangerous-oidc-beacon.yml@refs/heads/main',
        ),
      );
      expect(
        result.verifiedIssuer(),
        equals('https://token.actions.githubusercontent.com'),
      );
    });

    test('refreshes trusted root from TUF repository', () async {
      final client = SigstoreClient.create();
      final tempDir = Directory.systemTemp.createTempSync('tuf_test');
      try {
        final trustedRootJson = await client.refreshTrustedRoot(
          'https://tuf-repo-cdn.sigstore.dev',
          tempDir.path,
        );
        expect(trustedRootJson, isNotEmpty);
        final decoded = jsonDecode(trustedRootJson) as Map<String, Object?>;
        expect(
          decoded['mediaType'],
          equals('application/vnd.dev.sigstore.trustedroot+json;version=0.1'),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('throws SigstoreError on invalid TUF repository URL', () async {
      final client = SigstoreClient.create();
      final tempDir = Directory.systemTemp.createTempSync('tuf_invalid_test');
      try {
        await expectLater(
          client.refreshTrustedRoot('not-a-valid-url', tempDir.path),
          throwsA(isA<SigstoreError>()),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
