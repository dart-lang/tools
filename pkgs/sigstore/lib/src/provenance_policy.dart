// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'provenance.dart';

/// Checks a cryptographically verified package attestation against the
/// provenance policy shared by `pub` and `pub.dev`, and returns the list of
/// violations - empty if the attestation is acceptable.
///
/// The policy answers three questions about the archive with the lowercase
/// hex-encoded sha256 digest [archiveSha256], which was published as
/// [packageName] at [packageVersion]:
///
/// * *Who signed?* [signer] must be one of [trustedSignerWorkflows], given as
///   `<owner>/<repo>/<path>` (see [GitHubWorkflowIdentity.workflow]), and
///   [oidcIssuer] - if known - must be [githubActionsOidcIssuer]. With
///   [requireTaggedSignerRef] the signing workflow must additionally have run
///   at a tag (`refs/tags/...`) rather than a branch. If [provenance] names a
///   builder, it must agree with [signer].
/// * *What was signed?* A subject of [provenance] must be named
///   `<packageName>-<packageVersion>.tar.gz` or `package.tar.gz`, and its
///   digest must be [archiveSha256]. If the `pubspec.yaml` inside the archive
///   has been read, pass its `name` and `version` as [declaredPackageName] and
///   [declaredPackageVersion]: they must match [packageName] and
///   [packageVersion].
/// * *Where was it built?* [BuildProvenance.sourceRepository] must be the
///   GitHub repository in [expectedRepository] - the `repository:` field of
///   the `pubspec.yaml` inside the archive. With [requireRepository] a missing
///   [expectedRepository] is a violation: an attestation that is not bound to
///   a repository proves nothing beyond "somebody's trusted workflow built
///   this". If the package repository has automated publishing configured for
///   a GitHub repository, pass it as [configuredRepository] (a slug or URL, see
///   [GitHubRepository.tryParseSlug]): the source repository must match it
///   too.
///
/// [archiveSha256] and [signer] must come from verified material: the digest
/// `package:sigstore` verified the bundle over, and the identity it reported.
/// [packageVersion] and [declaredPackageVersion] are compared as strings, so
/// pass them in canonical form.
///
/// This is separate from the cryptographic verification so that the policy
/// can be exercised without doing (or faking) it.
List<String> checkProvenancePolicy({
  required String packageName,
  required String packageVersion,
  required String archiveSha256,
  required BuildProvenance provenance,
  required GitHubWorkflowIdentity signer,
  required Set<String> trustedSignerWorkflows,
  String? oidcIssuer,
  String? declaredPackageName,
  String? declaredPackageVersion,
  String? expectedRepository,
  String? configuredRepository,
  bool requireRepository = true,
  bool requireTaggedSignerRef = false,
}) {
  final errors = <String>[];

  if (oidcIssuer != null && oidcIssuer != githubActionsOidcIssuer) {
    errors.add(
      'Attestation was issued by "$oidcIssuer", '
      'expected "$githubActionsOidcIssuer".',
    );
  }

  // Who signed? Only a small set of workflows may sign packages.
  final trusted = trustedSignerWorkflows.map((w) => w.toLowerCase()).toSet();
  if (!trusted.contains(signer.workflow.toLowerCase())) {
    errors.add(
      'Attestation was signed by "${signer.workflow}", which is not a '
      'workflow trusted to publish packages. Trusted workflows: '
      '${(trustedSignerWorkflows.toList()..sort()).join(', ')}.',
    );
  } else if (requireTaggedSignerRef && !signer.ref.startsWith('refs/tags/')) {
    // TODO(https://github.com/dart-lang/pub/issues/4942): Pin the signing
    // workflow by the `job_workflow_sha` certificate extension once
    // `package:sigstore` exposes it. A ref is mutable, a sha is not.
    errors.add(
      'Attestation was signed by "${signer.workflow}" at "${signer.ref}", '
      'but only tagged releases of the publishing workflow are trusted.',
    );
  } else if (!signer.ref.startsWith('refs/tags/') &&
      !signer.ref.startsWith('refs/heads/')) {
    errors.add(
      'Attestation was signed by "${signer.workflow}" at "${signer.ref}", '
      'which is not a branch or tag ref.',
    );
  }
  final builder = provenance.builder;
  if (builder != null &&
      builder.workflow.toLowerCase() != signer.workflow.toLowerCase()) {
    errors.add(
      'Attestation states it was built by "${builder.workflow}" but was '
      'signed by "${signer.workflow}".',
    );
  }

  // What was signed? Without this an attestation for one package could be
  // served for another - all packages share the same signer identity.
  //
  // The subject name does not bind the package name or version: the
  // `dart-lang/setup-dart` publishing workflow signs the archive as
  // `package.tar.gz`. The binding is the digest - the package name and
  // version are bound through the `pubspec.yaml` inside the archive, which
  // is covered by `archiveSha256`.
  const genericSubject = 'package.tar.gz';
  final expectedSubject = '$packageName-$packageVersion.tar.gz';
  ProvenanceSubject? subject;
  for (final s in provenance.subjects) {
    if (s.name == expectedSubject || s.name == genericSubject) {
      subject = s;
      break;
    }
  }
  if (subject == null) {
    errors.add(
      'Attestation is for '
      '${provenance.subjects.map((s) => '"${s.name}"').join(', ')}, '
      'not for "$expectedSubject" or "$genericSubject".',
    );
  } else if (subject.sha256 != archiveSha256.toLowerCase()) {
    errors.add(
      'Attestation is for an archive with sha256 "${subject.sha256}", '
      'but this archive has sha256 "$archiveSha256".',
    );
  }

  if (declaredPackageName != null && declaredPackageName != packageName) {
    errors.add(
      'The pubspec.yaml of the attested archive declares `name: '
      '$declaredPackageName`, expected `$packageName`.',
    );
  }
  if (declaredPackageVersion != null &&
      declaredPackageVersion != packageVersion) {
    errors.add(
      'The pubspec.yaml of the attested archive declares `version: '
      '$declaredPackageVersion`, expected `$packageVersion`.',
    );
  }

  // Where was it built? This is the binding the whole feature rests on.
  if (expectedRepository == null || expectedRepository.trim().isEmpty) {
    if (requireRepository) {
      errors.add(
        'The pubspec.yaml of $packageName $packageVersion does not have a '
        '`repository` field, so the attestation cannot be bound to the '
        'repository it claims to come from '
        '("${provenance.sourceRepository.url}").',
      );
    }
  } else {
    final expected = GitHubRepository.tryParse(expectedRepository);
    if (expected == null) {
      errors.add(
        'Package attestation verification is currently only supported for '
        'GitHub repositories, but the pubspec.yaml of $packageName '
        '$packageVersion declares `repository: $expectedRepository`.',
      );
    } else if (expected != provenance.sourceRepository) {
      errors.add(
        'Attestation states the package was built from '
        '"${provenance.sourceRepository.url}", but the pubspec.yaml of '
        '$packageName $packageVersion declares `repository: '
        '$expectedRepository`.',
      );
    }
  }

  // When the package repository has automated publishing configured for a
  // GitHub repository, the source repository must also match that (and not
  // just the self-asserted `repository:` field inside the archive).
  if (configuredRepository != null && configuredRepository.trim().isNotEmpty) {
    final configured = GitHubRepository.tryParseSlug(configuredRepository);
    if (configured == null || configured != provenance.sourceRepository) {
      errors.add(
        'Attestation states the package was built from '
        '"${provenance.sourceRepository.url}", which does not match the '
        'configured GitHub Actions automated publishing repository '
        '"$configuredRepository".',
      );
    }
  }

  return errors;
}
