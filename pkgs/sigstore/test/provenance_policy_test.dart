// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:sigstore/provenance.dart';
import 'package:test/test.dart';

import 'provenance_fixtures.dart';

const _trustedWorkflow = 'dart-lang/setup-dart/.github/workflows/publish.yml';

const _trustedSigner = 'https://github.com/$_trustedWorkflow@refs/tags/v2';

const _archiveSha256 =
    '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';

/// Runs the policy for `helpful 1.0.0`, published from `dieter/helpful`.
List<String> check({
  String packageName = 'helpful',
  String packageVersion = '1.0.0',
  String archiveSha256 = _archiveSha256,
  String subjectName = 'helpful-1.0.0.tar.gz',
  String subjectSha256 = _archiveSha256,
  String repository = 'https://github.com/dieter/helpful',
  String? builderId = _trustedSigner,
  String signerIdentity = _trustedSigner,
  Set<String> trustedSignerWorkflows = const {_trustedWorkflow},
  String? oidcIssuer = githubActionsOidcIssuer,
  String? declaredPackageName,
  String? declaredPackageVersion,
  String? expectedRepository = 'https://github.com/dieter/helpful',
  String? configuredRepository,
  bool requireRepository = true,
  bool requireTaggedSignerRef = true,
}) {
  return checkProvenancePolicy(
    packageName: packageName,
    packageVersion: packageVersion,
    archiveSha256: archiveSha256,
    provenance: BuildProvenance.parseBundle(
      buildProvenanceBundleJson(
        subjectName: subjectName,
        subjectSha256: subjectSha256,
        repository: repository,
        builderId: builderId,
      ),
    ),
    signer: GitHubWorkflowIdentity.tryParse(signerIdentity)!,
    trustedSignerWorkflows: trustedSignerWorkflows,
    oidcIssuer: oidcIssuer,
    declaredPackageName: declaredPackageName,
    declaredPackageVersion: declaredPackageVersion,
    expectedRepository: expectedRepository,
    configuredRepository: configuredRepository,
    requireRepository: requireRepository,
    requireTaggedSignerRef: requireTaggedSignerRef,
  );
}

void main() {
  test(
    'accepts a package built by the trusted workflow from its repository',
    () {
      expect(check(), isEmpty);
    },
  );

  test('accepts the provenance of a real bundle', () {
    final errors = checkProvenancePolicy(
      packageName: 'helpful',
      packageVersion: '0.1.5',
      archiveSha256: helpfulArchiveSha256,
      provenance: BuildProvenance.parseBundle(helpfulBundleJson),
      // The identity `package:sigstore` reports for this bundle.
      signer: GitHubWorkflowIdentity.tryParse(
        'https://github.com/$_trustedWorkflow@'
        'refs/heads/publish-package-attestations',
      )!,
      trustedSignerWorkflows: const {_trustedWorkflow},
      oidcIssuer: githubActionsOidcIssuer,
      expectedRepository: 'https://github.com/mosuem/helpful',
      configuredRepository: 'mosuem/helpful',
    );
    expect(errors, isEmpty);
  });

  group('signer', () {
    test('rejects a signature from an untrusted workflow', () {
      // The case the client used to accept: a cryptographically valid bundle
      // from any GitHub Actions workflow in any repository.
      final errors = check(
        signerIdentity:
            'https://github.com/evil/evil/.github/workflows/sign.yml@'
            'refs/tags/v1',
        builderId:
            'https://github.com/evil/evil/.github/workflows/sign.yml@'
            'refs/tags/v1',
      );
      expect(errors, hasLength(1));
      expect(errors.single, contains('not a workflow trusted to publish'));
      expect(errors.single, contains(_trustedWorkflow));
    });

    test('matches the trusted workflows case-insensitively', () {
      expect(
        check(
          signerIdentity:
              'https://github.com/Dart-Lang/Setup-Dart/.github/workflows/'
              'publish.yml@refs/tags/v2',
        ),
        isEmpty,
      );
    });

    test('requires a trusted workflow to be given', () {
      final errors = check(trustedSignerWorkflows: const {});
      expect(errors.single, contains('not a workflow trusted to publish'));
    });

    test('rejects the trusted workflow at a mutable ref', () {
      final errors = check(
        signerIdentity: 'https://github.com/$_trustedWorkflow@refs/heads/main',
        builderId: 'https://github.com/$_trustedWorkflow@refs/heads/main',
      );
      expect(errors.single, contains('only tagged releases'));
    });

    test('accepts the trusted workflow at a branch unless required', () {
      expect(
        check(
          signerIdentity:
              'https://github.com/$_trustedWorkflow@refs/heads/main',
          builderId: 'https://github.com/$_trustedWorkflow@refs/heads/main',
          requireTaggedSignerRef: false,
        ),
        isEmpty,
      );
    });

    test(
      'rejects the trusted workflow at a ref that is not a branch or tag',
      () {
        final errors = check(
          signerIdentity:
              'https://github.com/$_trustedWorkflow@refs/pull/1/merge',
          builderId: 'https://github.com/$_trustedWorkflow@refs/pull/1/merge',
          requireTaggedSignerRef: false,
        );
        expect(errors.single, contains('not a branch or tag ref'));
      },
    );

    test('rejects a builder that disagrees with the signer', () {
      final errors = check(
        builderId:
            'https://github.com/evil/evil/.github/workflows/sign.yml@'
            'refs/tags/v1',
      );
      expect(errors.single, contains('but was signed by'));
    });

    test('rejects a non-GitHub issuer', () {
      final errors = check(oidcIssuer: 'https://accounts.google.com');
      expect(errors.single, contains('was issued by'));
    });

    test('does not check an unknown issuer', () {
      expect(check(oidcIssuer: null), isEmpty);
    });
  });

  group('subject', () {
    test('rejects an attestation for another package', () {
      // All packages are signed by the same workflow, so without this check a
      // compromised repository could serve the archive and attestation of one
      // package under the name of another.
      final errors = check(subjectName: 'evil-1.0.0.tar.gz');
      expect(errors.single, contains('not for "helpful-1.0.0.tar.gz"'));
    });

    test('rejects an attestation for another version', () {
      final errors = check(subjectName: 'helpful-1.0.1.tar.gz');
      expect(errors.single, contains('not for "helpful-1.0.0.tar.gz"'));
    });

    test('accepts the generic subject name of the publishing workflow', () {
      expect(check(subjectName: 'package.tar.gz'), isEmpty);
    });

    test('rejects an attestation for other bytes', () {
      final errors = check(subjectSha256: 'a' * 64);
      expect(errors.single, contains('but this archive has sha256'));
    });

    test('compares digests case-insensitively', () {
      expect(check(archiveSha256: _archiveSha256.toUpperCase()), isEmpty);
    });

    test('rejects an archive whose pubspec declares another package', () {
      expect(
        check(declaredPackageName: 'helpful', declaredPackageVersion: '1.0.0'),
        isEmpty,
      );
      expect(
        check(declaredPackageName: 'evil').single,
        contains('declares `name: evil`'),
      );
      expect(
        check(declaredPackageVersion: '1.0.1').single,
        contains('declares `version: 1.0.1`'),
      );
    });
  });

  group('repository', () {
    test('rejects a build from another repository', () {
      final errors = check(repository: 'https://github.com/evil/helpful');
      expect(errors.single, contains('was built from'));
    });

    test('rejects a repository that only matches by suffix', () {
      final errors = check(
        repository: 'https://github.com/evil-dieter/helpful',
      );
      expect(errors.single, contains('was built from'));
    });

    test('accepts a monorepo subdirectory url', () {
      expect(
        check(
          repository: 'https://github.com/dart-lang/tools',
          expectedRepository:
              'https://github.com/dart-lang/tools/tree/main/pkgs/helpful',
        ),
        isEmpty,
      );
    });

    test('accepts a differently spelled url for the same repository', () {
      expect(
        check(expectedRepository: 'https://github.com/Dieter/helpful.git'),
        isEmpty,
      );
    });

    test('rejects a package that does not declare a repository', () {
      // Without a repository in the pubspec the attestation is unbound: it
      // only says that some trusted workflow built these bytes.
      final errors = check(expectedRepository: null);
      expect(errors.single, contains('does not have a `repository` field'));
      expect(check(expectedRepository: '  '), hasLength(1));
    });

    test('accepts a missing repository unless required', () {
      expect(
        check(expectedRepository: null, requireRepository: false),
        isEmpty,
      );
    });

    test('rejects a non-GitHub repository in the pubspec', () {
      final errors = check(
        expectedRepository: 'https://gitlab.com/dieter/helpful',
      );
      expect(errors.single, contains('only supported for GitHub'));
    });
  });

  group('configured repository', () {
    test('accepts a matching slug or url', () {
      expect(check(configuredRepository: 'dieter/helpful'), isEmpty);
      expect(check(configuredRepository: 'Dieter/Helpful'), isEmpty);
      expect(
        check(configuredRepository: 'https://github.com/dieter/helpful'),
        isEmpty,
      );
      expect(check(configuredRepository: ''), isEmpty);
    });

    test('rejects a build from a repository other than the configured one', () {
      // The `repository:` field inside the archive is under the control of
      // whoever built the archive. The configured repository is not.
      final errors = check(configuredRepository: 'dart-lang/helpful');
      expect(errors.single, contains('does not match the configured'));
      expect(
        check(configuredRepository: 'not a repository').single,
        contains('does not match the configured'),
      );
    });
  });
}
