// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

/// The real Sigstore bundle for `helpful 0.1.5`, built from `mosuem/helpful`
/// and signed by `dart-lang/setup-dart/.github/workflows/publish.yml`.
///
/// See [helpfulArchiveSha256] for the digest of the archive it attests.
final String helpfulBundleJson = File(
  'test/fixtures/helpful_bundle.sigstore.json',
).readAsStringSync();

/// The sha256 of `helpful-0.1.5.tar.gz`, the subject of [helpfulBundleJson].
const helpfulArchiveSha256 =
    'c8ecfa61100ece1a55fcb52716db74f92b6debeb7577a4b8ca4548f440bfa6bf';

/// The bundle of a plain artifact signature from the Sigstore conformance
/// suite, which carries no statement at all.
final String sampleBundleJson = File(
  'test/fixtures/sample_bundle.json',
).readAsStringSync();

/// Decodes a lowercase hex-encoded digest.
List<int> hexToBytes(String hex) => [
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

/// Builds a Sigstore bundle carrying a SLSA build provenance statement.
///
/// The bundle is not signed: it is meant for tests of the parsing and of the
/// verification policy, which operate on material that has already been
/// cryptographically verified.
String buildProvenanceBundleJson({
  String subjectName = 'foo-1.0.0.tar.gz',
  String subjectSha256 =
      '0000000000000000000000000000000000000000000000000000000000000000',
  String repository = 'https://github.com/dieter/helpful',
  String ref = 'refs/tags/v1.0.0',
  String workflowPath = '.github/workflows/release.yml',
  String? commitSha = 'c0ffee7891abbe3dab159e9d0187fc1042d5e0cd',
  String? builderId =
      'https://github.com/dart-lang/setup-dart/.github/workflows/'
      'publish.yml@refs/tags/v2',
  Object? repositoryId,
  Object? repositoryOwnerId,
  String? runUrl,
  String statementType = 'https://in-toto.io/Statement/v1',
  String predicateType = 'https://slsa.dev/provenance/v1',
  String payloadType = 'application/vnd.in-toto+json',
}) {
  final statement = {
    '_type': statementType,
    'subject': [
      {
        'name': subjectName,
        'digest': {'sha256': subjectSha256},
      },
    ],
    'predicateType': predicateType,
    'predicate': {
      'buildDefinition': {
        'buildType': 'https://actions.github.io/buildtypes/workflow/v1',
        'externalParameters': {
          'workflow': {
            'ref': ref,
            'repository': repository,
            'path': workflowPath,
          },
        },
        if (repositoryId != null || repositoryOwnerId != null)
          'internalParameters': {
            'github': {
              'repository_id': ?repositoryId,
              'repository_owner_id': ?repositoryOwnerId,
            },
          },
        if (commitSha != null)
          'resolvedDependencies': [
            {
              'uri': 'git+$repository@$ref',
              'digest': {'gitCommit': commitSha},
            },
          ],
      },
      'runDetails': {
        if (builderId != null) 'builder': {'id': builderId},
        if (runUrl != null) 'metadata': {'invocationId': runUrl},
      },
    },
  };
  return json.encode({
    'mediaType': 'application/vnd.dev.sigstore.bundle.v0.3+json',
    'dsseEnvelope': {
      'payload': base64.encode(utf8.encode(json.encode(statement))),
      'payloadType': payloadType,
      'signatures': [
        {'sig': 'not-a-real-signature'},
      ],
    },
  });
}

/// Re-encodes the DSSE payload of [bundleJson] in the URL-safe alphabet,
/// without padding - the other base64 form ProtoJSON permits.
String withUrlSafeUnpaddedPayload(String bundleJson) {
  final bundle = json.decode(bundleJson) as Map<String, Object?>;
  final envelope = bundle['dsseEnvelope'] as Map<String, Object?>;
  final payload = base64.decode(envelope['payload'] as String);
  final reencoded = base64Url.encode(payload).replaceAll('=', '');
  // Make sure the test is not vacuous.
  if (reencoded == envelope['payload']) {
    throw StateError('payload is unchanged by re-encoding');
  }
  envelope['payload'] = reencoded;
  return json.encode(bundle);
}
