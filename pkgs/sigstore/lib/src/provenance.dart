// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

/// The OIDC issuer of tokens minted by GitHub Actions.
const githubActionsOidcIssuer = 'https://token.actions.githubusercontent.com';

const _inTotoStatementType = 'https://in-toto.io/Statement/v1';
const _inTotoPayloadType = 'application/vnd.in-toto+json';
const _slsaProvenancePredicateType = 'https://slsa.dev/provenance/v1';

/// A GitHub repository, identified by its [owner] and [name].
///
/// GitHub treats owner and repository names case-insensitively, and so does
/// [operator ==].
class GitHubRepository {
  /// The user or organization owning the repository.
  final String owner;

  /// The name of the repository within [owner].
  final String name;

  /// Creates a reference to the repository [name] of [owner].
  GitHubRepository(this.owner, this.name);

  /// Parses a reference to a GitHub repository, or returns `null` if [source]
  /// does not denote one.
  ///
  /// Accepts the forms used in `pubspec.yaml`'s `repository:` field and in
  /// SLSA provenance statements:
  ///
  /// * `https://github.com/<owner>/<repo>`
  /// * `https://github.com/<owner>/<repo>.git`
  /// * `git+https://github.com/<owner>/<repo>@<ref>`
  /// * `https://github.com/<owner>/<repo>/tree/<ref>/<dir>` (monorepos)
  ///
  /// Everything after `<repo>` is ignored: a package living in a subdirectory
  /// of a monorepo is published from the repository as a whole, so the
  /// subdirectory carries no information for verification.
  static GitHubRepository? tryParse(String source) {
    var s = source.trim();
    if (s.isEmpty) return null;
    // Provenance uses SPDX-style download locations such as
    // `git+https://github.com/dart-lang/pub@refs/tags/v1.0.0`.
    if (s.startsWith('git+')) {
      s = s.substring('git+'.length);
      final at = s.lastIndexOf('@');
      if (at > 0) s = s.substring(0, at);
    }
    final uri = Uri.tryParse(s);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    // Compare the full host: `endsWith('github.com')` would also accept
    // `github.com.example.com`.
    final host = uri.host.toLowerCase();
    if (host != 'github.com' && host != 'www.github.com') return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;
    final owner = segments[0];
    var name = segments[1];
    if (name.endsWith('.git')) {
      name = name.substring(0, name.length - '.git'.length);
    }
    if (owner.isEmpty || name.isEmpty) return null;
    return GitHubRepository(owner, name);
  }

  /// Parses an `<owner>/<repo>` slug, as used by the GitHub API and in OIDC
  /// claims, or any of the URL forms accepted by [tryParse].
  ///
  /// Returns `null` if [source] is neither.
  static GitHubRepository? tryParseSlug(String source) {
    final fromUrl = tryParse(source);
    if (fromUrl != null) return fromUrl;
    final trimmed = source.trim();
    if (trimmed.isEmpty || trimmed.contains(':')) return null;
    final parts = trimmed.split('/');
    if (parts.length != 2) return null;
    final owner = parts[0];
    var name = parts[1];
    if (name.endsWith('.git')) {
      name = name.substring(0, name.length - '.git'.length);
    }
    if (owner.isEmpty || name.isEmpty) return null;
    return GitHubRepository(owner, name);
  }

  /// `<owner>/<name>`, as used by the GitHub API and in OIDC claims.
  String get slug => '$owner/$name';

  /// The canonical url of this repository.
  String get url => 'https://github.com/$owner/$name';

  @override
  bool operator ==(Object other) =>
      other is GitHubRepository &&
      owner.toLowerCase() == other.owner.toLowerCase() &&
      name.toLowerCase() == other.name.toLowerCase();

  @override
  int get hashCode => Object.hash(owner.toLowerCase(), name.toLowerCase());

  @override
  String toString() => url;
}

/// The identity of a GitHub Actions workflow, as asserted by GitHub.
///
/// This is the `job_workflow_ref` claim of the GitHub Actions OIDC token,
/// which Fulcio puts in the subject alternative name of the signing
/// certificate. For a reusable workflow it identifies the *reusable* workflow
/// - the trusted builder - and not the repository that called it.
class GitHubWorkflowIdentity {
  /// The repository containing the workflow file.
  final GitHubRepository repository;

  /// The path of the workflow file within [repository], e.g.
  /// `.github/workflows/publish.yml`.
  final String path;

  /// The git ref the workflow ran at, e.g. `refs/tags/v2`.
  final String ref;

  /// Creates the identity of the workflow at [path] in [repository], running
  /// at [ref].
  GitHubWorkflowIdentity({
    required this.repository,
    required this.path,
    required this.ref,
  });

  /// Parses an identity of the form
  /// `https://github.com/<owner>/<repo>/<path>@<ref>`, or returns `null` if
  /// [identity] is not of that form.
  ///
  /// This is the form of the verified identity that `package:sigstore` reports
  /// for a bundle signed from GitHub Actions.
  static GitHubWorkflowIdentity? tryParse(String identity) {
    final at = identity.lastIndexOf('@');
    if (at <= 0) return null;
    final url = identity.substring(0, at);
    final ref = identity.substring(at + 1);
    if (ref.isEmpty) return null;
    final repository = GitHubRepository.tryParse(url);
    if (repository == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 3) return null;
    return GitHubWorkflowIdentity(
      repository: repository,
      path: segments.sublist(2).join('/'),
      ref: ref,
    );
  }

  /// `<owner>/<repo>/<path>` - the workflow without the ref it ran at.
  String get workflow => '${repository.slug}/$path';

  @override
  String toString() => '${repository.url}/$path@$ref';
}

/// An entry of the `subject` list of an in-toto statement.
class ProvenanceSubject {
  /// The name of the artifact, e.g. `package.tar.gz`.
  final String name;

  /// The lowercase hex-encoded sha256 digest, or `null` if the subject is not
  /// identified by a sha256.
  final String? sha256;

  /// Creates a subject [name] with the digest [sha256].
  ProvenanceSubject(this.name, this.sha256);
}

/// The SLSA build provenance of an artifact, as carried in the DSSE envelope
/// of a Sigstore bundle.
class BuildProvenance {
  /// The repository the build ran for.
  ///
  /// This is `github.repository` of the workflow run - for a reusable
  /// workflow, the repository that *called* the trusted builder. It is filled
  /// in by GitHub from the run context and cannot be set by the caller.
  final GitHubRepository sourceRepository;

  /// The ref of [sourceRepository] the build ran at, e.g. `refs/tags/v1.0.0`.
  final String? sourceRef;

  /// The path of the caller's workflow file.
  final String? workflowPath;

  /// The commit the build ran at, if recorded.
  final String? commitSha;

  /// The immutable id of [sourceRepository], if recorded.
  ///
  /// GitHub fills this in from the run context (`internalParameters.github`),
  /// it cannot be set by the caller of the workflow. Unlike the name of a
  /// repository, the id survives renames and transfers.
  final String? repositoryId;

  /// The immutable id of the owner of [sourceRepository], if recorded.
  final String? repositoryOwnerId;

  /// The URL of the workflow run (`runDetails.metadata.invocationId`), if
  /// recorded.
  final String? runUrl;

  /// The builder as self-reported in the statement.
  ///
  /// Note that the authoritative statement about who signed is the certificate
  /// identity, not this field.
  final GitHubWorkflowIdentity? builder;

  /// The artifacts the statement is about.
  final List<ProvenanceSubject> subjects;

  /// Creates a build provenance from its parts.
  BuildProvenance({
    required this.sourceRepository,
    required this.sourceRef,
    required this.workflowPath,
    required this.commitSha,
    required this.builder,
    required this.subjects,
    this.repositoryId,
    this.repositoryOwnerId,
    this.runUrl,
  });

  /// Extracts the build provenance from the DSSE envelope of the Sigstore
  /// bundle in [bundleJson].
  ///
  /// Throws a [FormatException] if [bundleJson] is not a bundle carrying a
  /// SLSA build provenance statement.
  ///
  /// This does not validate any signature. Only use the result if
  /// `package:sigstore` has verified the very same [bundleJson].
  factory BuildProvenance.parseBundle(String bundleJson) {
    final Object? decoded;
    try {
      decoded = json.decode(bundleJson);
    } on FormatException catch (e) {
      throw FormatException('Attestation is not valid JSON: ${e.message}');
    }
    final bundle = _expectMap(decoded, 'bundle');
    final envelope = bundle['dsseEnvelope'];
    if (envelope == null) {
      throw const FormatException(
        'Attestation does not contain a `dsseEnvelope`, so it carries no '
        'build provenance.',
      );
    }
    final dsse = _expectMap(envelope, 'dsseEnvelope');
    final payloadType = dsse['payloadType'];
    if (payloadType != _inTotoPayloadType) {
      throw FormatException(
        'Attestation payload has type `$payloadType`, '
        'expected `$_inTotoPayloadType`.',
      );
    }
    final encodedPayload = dsse['payload'];
    if (encodedPayload is! String) {
      throw const FormatException('Attestation has no `payload`.');
    }
    final Object? decodedStatement;
    try {
      // ProtoJSON permits the standard and the URL-safe alphabet, with or
      // without padding, and `sigstore-rust` accepts all of these when it
      // verifies the envelope. Accept the same forms here, so that a payload
      // the verifier accepted never fails to parse. All of them decode to the
      // same bytes.
      decodedStatement = json.decode(
        utf8.decode(base64.decode(base64.normalize(encodedPayload))),
      );
    } on FormatException catch (e) {
      throw FormatException(
        'Attestation payload is not valid base64-encoded JSON: ${e.message}',
      );
    }
    final statement = _expectMap(decodedStatement, 'statement');

    final type = statement['_type'];
    if (type != _inTotoStatementType) {
      throw FormatException(
        'Attestation statement has type `$type`, '
        'expected `$_inTotoStatementType`.',
      );
    }
    final predicateType = statement['predicateType'];
    if (predicateType != _slsaProvenancePredicateType) {
      throw FormatException(
        'Attestation has predicate type `$predicateType`, '
        'expected `$_slsaProvenancePredicateType`.',
      );
    }

    final subjects = <ProvenanceSubject>[];
    final subjectList = statement['subject'];
    if (subjectList is! List || subjectList.isEmpty) {
      throw const FormatException('Attestation statement has no `subject`.');
    }
    for (final subject in subjectList) {
      final s = _expectMap(subject, 'subject');
      final name = s['name'];
      if (name is! String) {
        throw const FormatException('Attestation subject has no `name`.');
      }
      final digest = s['digest'];
      final sha256 = digest is Map ? digest['sha256'] : null;
      subjects.add(
        ProvenanceSubject(name, sha256 is String ? sha256.toLowerCase() : null),
      );
    }

    final predicate = _expectMap(statement['predicate'], 'predicate');
    final buildDefinition = _expectMap(
      predicate['buildDefinition'],
      'buildDefinition',
    );
    final externalParameters = _expectMap(
      buildDefinition['externalParameters'],
      'externalParameters',
    );
    final workflow = _expectMap(externalParameters['workflow'], 'workflow');

    final repositoryField = workflow['repository'];
    if (repositoryField is! String) {
      throw const FormatException(
        'Attestation does not state the repository it was built from.',
      );
    }
    final sourceRepository = GitHubRepository.tryParse(repositoryField);
    if (sourceRepository == null) {
      throw FormatException(
        'Attestation was built from `$repositoryField`, which is not a GitHub '
        'repository. Only GitHub is supported for now.',
      );
    }

    String? commitSha;
    final resolvedDependencies = buildDefinition['resolvedDependencies'];
    if (resolvedDependencies is List) {
      for (final dependency in resolvedDependencies) {
        if (dependency is! Map) continue;
        final uri = dependency['uri'];
        if (uri is! String) continue;
        if (GitHubRepository.tryParse(uri) != sourceRepository) continue;
        final digest = dependency['digest'];
        final gitCommit = digest is Map ? digest['gitCommit'] : null;
        if (gitCommit is String) {
          commitSha = gitCommit;
          break;
        }
      }
    }

    GitHubWorkflowIdentity? builder;
    String? runUrl;
    final runDetails = predicate['runDetails'];
    if (runDetails is Map) {
      final builderField = runDetails['builder'];
      final id = builderField is Map ? builderField['id'] : null;
      if (id is String) builder = GitHubWorkflowIdentity.tryParse(id);
      final metadata = runDetails['metadata'];
      final invocationId = metadata is Map ? metadata['invocationId'] : null;
      if (invocationId is String && invocationId.isNotEmpty) {
        runUrl = invocationId;
      }
    }

    String? repositoryId;
    String? repositoryOwnerId;
    final internalParameters = buildDefinition['internalParameters'];
    final github = internalParameters is Map
        ? internalParameters['github']
        : null;
    if (github is Map) {
      repositoryId = _idString(github['repository_id']);
      repositoryOwnerId = _idString(github['repository_owner_id']);
    }

    final ref = workflow['ref'];
    final path = workflow['path'];
    return BuildProvenance(
      sourceRepository: sourceRepository,
      sourceRef: ref is String ? ref : null,
      workflowPath: path is String ? path : null,
      commitSha: commitSha,
      builder: builder,
      subjects: subjects,
      repositoryId: repositoryId,
      repositoryOwnerId: repositoryOwnerId,
      runUrl: runUrl,
    );
  }
}

/// The entry of a Sigstore bundle in the transparency log (Rekor).
class TransparencyLogEntry {
  /// The index of the entry in the log.
  final int logIndex;

  /// The time the log integrated the entry.
  final DateTime integratedTime;

  /// Creates a log entry from its parts.
  TransparencyLogEntry({required this.logIndex, required this.integratedTime});

  /// Extracts the first transparency log entry from the Sigstore bundle in
  /// [bundleJson], or returns `null` if the bundle has none (or is not a
  /// bundle at all).
  ///
  /// This does not validate the inclusion proof of the entry. Only use the
  /// result if `package:sigstore` has verified the very same [bundleJson]: the
  /// inclusion proof is checked there.
  static TransparencyLogEntry? tryParseBundle(String bundleJson) {
    final Object? decoded;
    try {
      decoded = json.decode(bundleJson);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final material = decoded['verificationMaterial'];
    final entries = material is Map ? material['tlogEntries'] : null;
    if (entries is! List || entries.isEmpty) return null;
    final entry = entries.first;
    if (entry is! Map) return null;
    // Both are int64 values, encoded as strings in the JSON form of the
    // bundle protobuf.
    final logIndex = int.tryParse('${entry['logIndex']}');
    final integratedTime = int.tryParse('${entry['integratedTime']}');
    if (logIndex == null || integratedTime == null) return null;
    return TransparencyLogEntry(
      logIndex: logIndex,
      integratedTime: DateTime.fromMillisecondsSinceEpoch(
        integratedTime * 1000,
        isUtc: true,
      ),
    );
  }
}

Map<String, Object?> _expectMap(Object? value, String what) {
  if (value is! Map<String, Object?>) {
    throw FormatException('Attestation `$what` is not a JSON object.');
  }
  return value;
}

/// The GitHub id in [value], or `null` if there is none.
///
/// GitHub records its ids as strings, as they are in the OIDC token claims
/// they come from. Tolerate a tool that emits them as the numbers they are.
String? _idString(Object? value) => switch (value) {
  final String id when id.isNotEmpty => id,
  final int id => '$id',
  _ => null,
};
