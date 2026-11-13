// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:sigstore/provenance.dart';
import 'package:sigstore/sigstore.dart';
import 'package:test/test.dart';

import 'provenance_fixtures.dart';

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

    test('verifies a package attestation over the archive digest', () {
      // The flow of `pub` and `pub.dev`: verify the bundle over the sha256 of
      // the archive, then bind the signed statement to the package with
      // `package:sigstore/provenance.dart`. The identity reported here is
      // what `GitHubWorkflowIdentity.tryParse` must understand.
      final client = SigstoreClient.create();
      final bundle = SigstoreBundle.fromJson(helpfulBundleJson);
      final policy = SigstoreVerificationPolicy.create(
        '',
        githubActionsOidcIssuer,
        true,
        false,
        '',
        '',
      );

      final result = client.verify(
        hexToBytes(helpfulArchiveSha256),
        true,
        bundle,
        policy,
      );
      expect(result.isValid(), isTrue);
      expect(result.verifiedIssuer(), githubActionsOidcIssuer);

      final signer = GitHubWorkflowIdentity.tryParse(
        result.verifiedIdentity(),
      )!;
      expect(
        signer.workflow,
        'dart-lang/setup-dart/.github/workflows/publish.yml',
      );
      expect(signer.ref, 'refs/heads/publish-package-attestations');

      final errors = checkProvenancePolicy(
        packageName: 'helpful',
        packageVersion: '0.1.5',
        archiveSha256: helpfulArchiveSha256,
        provenance: BuildProvenance.parseBundle(helpfulBundleJson),
        signer: signer,
        trustedSignerWorkflows: const {
          'dart-lang/setup-dart/.github/workflows/publish.yml',
        },
        oidcIssuer: result.verifiedIssuer(),
        expectedRepository: 'https://github.com/mosuem/helpful',
      );
      expect(errors, isEmpty);

      // A different archive fails signature verification before any policy
      // is evaluated.
      expect(
        () => client.verify(
          hexToBytes('a' * 64),
          true,
          SigstoreBundle.fromJson(helpfulBundleJson),
          policy,
        ),
        throwsA(isA<SigstoreError>()),
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
