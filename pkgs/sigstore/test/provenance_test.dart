// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:sigstore/provenance.dart';
import 'package:test/test.dart';

import 'provenance_fixtures.dart';

void main() {
  group('GitHubRepository.tryParse', () {
    void expectRepo(String source, String? slug) {
      expect(
        GitHubRepository.tryParse(source)?.slug,
        slug,
        reason: 'parsing "$source"',
      );
    }

    test('accepts the forms found in pubspecs and provenance', () {
      expectRepo('https://github.com/dieter/helpful', 'dieter/helpful');
      expectRepo('https://github.com/dieter/helpful/', 'dieter/helpful');
      expectRepo('https://github.com/dieter/helpful.git', 'dieter/helpful');
      expectRepo('http://github.com/dieter/helpful', 'dieter/helpful');
      expectRepo('https://www.github.com/dieter/helpful', 'dieter/helpful');
      expectRepo('  https://github.com/dieter/helpful  ', 'dieter/helpful');
      expectRepo(
        'git+https://github.com/dieter/helpful@refs/tags/v1.0.0',
        'dieter/helpful',
      );
    });

    test('ignores the subdirectory of a monorepo package', () {
      expectRepo(
        'https://github.com/dart-lang/tools/tree/main/pkgs/graphs',
        'dart-lang/tools',
      );
    });

    test('rejects everything that is not a GitHub repository', () {
      expectRepo('https://gitlab.com/dieter/helpful', null);
      expectRepo('https://example.com/dieter/helpful', null);
      // A suffix check on the host would accept this one.
      expectRepo('https://github.com.evil.example/dieter/helpful', null);
      expectRepo('https://notgithub.com/dieter/helpful', null);
      expectRepo('https://github.com/dieter', null);
      expectRepo('https://github.com/', null);
      expectRepo('ftp://github.com/dieter/helpful', null);
      expectRepo('dieter/helpful', null);
      expectRepo('', null);
    });

    test('compares case-insensitively but does not match by suffix', () {
      final helpful = GitHubRepository.tryParse(
        'https://github.com/dieter/helpful',
      );
      expect(
        helpful,
        GitHubRepository.tryParse('https://github.com/Dieter/Helpful.git'),
      );
      expect(
        helpful.hashCode,
        GitHubRepository.tryParse(
          'https://github.com/Dieter/Helpful.git',
        ).hashCode,
      );
      // `endsWith`-style matching would consider these equal.
      expect(
        helpful,
        isNot(
          GitHubRepository.tryParse('https://github.com/evil-dieter/helpful'),
        ),
      );
      expect(
        helpful,
        isNot(GitHubRepository.tryParse('https://github.com/evil/helpful')),
      );
    });

    test('renders as the canonical url', () {
      final helpful = GitHubRepository('dieter', 'helpful');
      expect(helpful.url, 'https://github.com/dieter/helpful');
      expect(helpful.toString(), helpful.url);
      expect(helpful.slug, 'dieter/helpful');
    });
  });

  group('GitHubRepository.tryParseSlug', () {
    void expectRepo(String source, String? slug) {
      expect(
        GitHubRepository.tryParseSlug(source)?.slug,
        slug,
        reason: 'parsing "$source"',
      );
    }

    test('accepts slugs and urls', () {
      expectRepo('dieter/helpful', 'dieter/helpful');
      expectRepo('dieter/helpful.git', 'dieter/helpful');
      expectRepo('  dieter/helpful  ', 'dieter/helpful');
      expectRepo('https://github.com/dieter/helpful', 'dieter/helpful');
      expectRepo('https://github.com/dieter/helpful.git', 'dieter/helpful');
    });

    test('rejects everything else', () {
      expectRepo('helpful', null);
      expectRepo('dieter/helpful/extra', null);
      expectRepo('/helpful', null);
      expectRepo('dieter/', null);
      expectRepo('gitlab.com:dieter/helpful', null);
      expectRepo('https://gitlab.com/dieter/helpful', null);
      expectRepo('', null);
    });
  });

  group('GitHubWorkflowIdentity.tryParse', () {
    test('splits repository, path and ref', () {
      final identity = GitHubWorkflowIdentity.tryParse(
        'https://github.com/dart-lang/setup-dart/.github/workflows/'
        'publish.yml@refs/tags/v2',
      )!;
      expect(identity.repository.slug, 'dart-lang/setup-dart');
      expect(identity.path, '.github/workflows/publish.yml');
      expect(identity.ref, 'refs/tags/v2');
      expect(
        identity.workflow,
        'dart-lang/setup-dart/.github/workflows/publish.yml',
      );
      expect(
        identity.toString(),
        'https://github.com/dart-lang/setup-dart/.github/workflows/'
        'publish.yml@refs/tags/v2',
      );
    });

    test('rejects identities without a workflow path or ref', () {
      expect(
        GitHubWorkflowIdentity.tryParse(
          'https://github.com/dart-lang/setup-dart@refs/tags/v2',
        ),
        isNull,
      );
      expect(
        GitHubWorkflowIdentity.tryParse(
          'https://github.com/dart-lang/setup-dart/.github/workflows/p.yml',
        ),
        isNull,
      );
      expect(
        GitHubWorkflowIdentity.tryParse(
          'https://github.com/dart-lang/setup-dart/.github/workflows/p.yml@',
        ),
        isNull,
      );
      expect(
        GitHubWorkflowIdentity.tryParse('mailto:someone@example.com'),
        isNull,
      );
      expect(GitHubWorkflowIdentity.tryParse(''), isNull);
    });
  });

  group('BuildProvenance.parseBundle', () {
    test('extracts the repository, ref, commit and subjects', () {
      final provenance = BuildProvenance.parseBundle(
        buildProvenanceBundleJson(
          subjectName: 'helpful-0.1.2.tar.gz',
          subjectSha256: 'ABC123',
          ref: 'refs/tags/v0.1.2',
          commitSha: 'deadbeef',
        ),
      );
      expect(provenance.sourceRepository.slug, 'dieter/helpful');
      expect(provenance.sourceRef, 'refs/tags/v0.1.2');
      expect(provenance.workflowPath, '.github/workflows/release.yml');
      expect(provenance.commitSha, 'deadbeef');
      expect(provenance.subjects.single.name, 'helpful-0.1.2.tar.gz');
      // Digests are compared in lowercase.
      expect(provenance.subjects.single.sha256, 'abc123');
      expect(
        provenance.builder!.workflow,
        'dart-lang/setup-dart/.github/workflows/publish.yml',
      );
      // Not recorded in this statement.
      expect(provenance.repositoryId, isNull);
      expect(provenance.repositoryOwnerId, isNull);
      expect(provenance.runUrl, isNull);
    });

    test('extracts the repository ids and run url when recorded', () {
      final provenance = BuildProvenance.parseBundle(
        buildProvenanceBundleJson(
          repositoryId: '1339313025',
          repositoryOwnerId: '27859082',
          runUrl: 'https://github.com/dieter/helpful/actions/runs/1/attempts/1',
        ),
      );
      expect(provenance.repositoryId, '1339313025');
      expect(provenance.repositoryOwnerId, '27859082');
      expect(
        provenance.runUrl,
        'https://github.com/dieter/helpful/actions/runs/1/attempts/1',
      );
    });

    test('tolerates a missing commit and builder', () {
      final provenance = BuildProvenance.parseBundle(
        buildProvenanceBundleJson(commitSha: null, builderId: null),
      );
      expect(provenance.commitSha, isNull);
      expect(provenance.builder, isNull);
    });

    test('parses the provenance of a real bundle', () {
      final provenance = BuildProvenance.parseBundle(helpfulBundleJson);
      expect(provenance.sourceRepository.slug, 'mosuem/helpful');
      expect(provenance.sourceRef, 'refs/heads/main');
      expect(provenance.workflowPath, '.github/workflows/publish.yaml');
      expect(provenance.commitSha, '63216a3022ed606538399634cd1c525f8bd4657f');
      expect(provenance.repositoryId, '1339313025');
      expect(provenance.repositoryOwnerId, '27859082');
      expect(
        provenance.runUrl,
        'https://github.com/mosuem/helpful/actions/runs/33514943555/attempts/1',
      );
      expect(
        provenance.builder!.workflow,
        'dart-lang/setup-dart/.github/workflows/publish.yml',
      );
      expect(
        provenance.builder!.ref,
        'refs/heads/publish-package-attestations',
      );
      // `dart-lang/setup-dart` signs the archive under a generic name.
      expect(provenance.subjects.single.name, 'package.tar.gz');
      expect(provenance.subjects.single.sha256, helpfulArchiveSha256);
    });

    test('rejects a bundle without a DSSE envelope', () {
      // The bundle of a plain artifact signature carries no statement at all -
      // there is nothing to bind it to a package.
      expect(
        () => BuildProvenance.parseBundle(sampleBundleJson),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('carries no build provenance'),
          ),
        ),
      );
    });

    test('rejects a statement that is not SLSA build provenance', () {
      expect(
        () => BuildProvenance.parseBundle(
          buildProvenanceBundleJson(
            predicateType: 'https://slsa.dev/verification_summary/v1',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BuildProvenance.parseBundle(
          buildProvenanceBundleJson(
            statementType: 'https://in-toto.io/Statement/v0.1',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BuildProvenance.parseBundle(
          buildProvenanceBundleJson(payloadType: 'application/json'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a build from a non-GitHub repository', () {
      expect(
        () => BuildProvenance.parseBundle(
          buildProvenanceBundleJson(
            repository: 'https://gitlab.com/dieter/helpful',
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('not a GitHub repository'),
          ),
        ),
      );
    });

    test('rejects malformed input', () {
      expect(
        () => BuildProvenance.parseBundle('not json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BuildProvenance.parseBundle('[]'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BuildProvenance.parseBundle('{"dsseEnvelope": 42}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BuildProvenance.parseBundle(
          '{"dsseEnvelope": {"payloadType": "application/vnd.in-toto+json", '
          '"payload": "bm90IGpzb24="}}',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('TransparencyLogEntry.tryParseBundle', () {
    test('extracts the log index and integration time of a real bundle', () {
      final entry = TransparencyLogEntry.tryParseBundle(helpfulBundleJson)!;
      expect(entry.logIndex, 2676401329);
      expect(entry.integratedTime, DateTime.utc(2026, 9, 1, 13, 42, 37));
    });

    test('extracts the entry of a bundle without a DSSE envelope', () {
      final entry = TransparencyLogEntry.tryParseBundle(sampleBundleJson)!;
      expect(entry.logIndex, 79571823);
      expect(entry.integratedTime, DateTime.utc(2024, 3, 19, 17, 26, 26));
    });

    test('returns null without a log entry', () {
      expect(
        TransparencyLogEntry.tryParseBundle(buildProvenanceBundleJson()),
        isNull,
      );
      expect(
        TransparencyLogEntry.tryParseBundle(
          '{"verificationMaterial": {"tlogEntries": [{"logIndex": "x"}]}}',
        ),
        isNull,
      );
      expect(TransparencyLogEntry.tryParseBundle('not json'), isNull);
      expect(TransparencyLogEntry.tryParseBundle('[]'), isNull);
    });
  });
}
