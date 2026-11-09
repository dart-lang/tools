// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'dart:async' show TimeoutException;
import 'dart:convert' show jsonDecode, utf8;
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:args/args.dart';
import 'package:boring/src/hook_helpers/hashes.dart' as current;
import 'package:boring/src/hook_helpers/targets.dart';
import 'package:crypto/crypto.dart' show sha256;

const _hashesFile = 'lib/src/hook_helpers/hashes.dart';
const _connectionTimeout = Duration(seconds: 30);
const _downloadTimeout = Duration(minutes: 5);
const _defaultMaxAttempts = 4;
final _sha256DigestPattern = RegExp(r'^sha256:([0-9a-f]{64})$');

/// Pins the prebuilt libraries of a GitHub release in
/// lib/src/hook_helpers/hashes.dart: the repository, the tag, the commit they
/// were built from, and the SHA-256 hashes of the release assets built by
/// tool/precompile_binaries.dart.
///
/// Usage: `dart run tool/regenerate_hashes.dart [options] [tag]`
///
/// Without arguments, re-pins the current release, which the `generated` job
/// of .github/workflows/boring.yaml uses to check hashes.dart. The `pin` job
/// of .github/workflows/boring_binaries.yaml passes the new release's tag,
/// `--source-commit`, and `--assets` with the libraries it just built.
///
/// Fails without writing anything if an asset of a prebuilt target is missing
/// from a release built by that workflow, so that a failed or partial release
/// can't break the `fetch` build mode for that target. Releases built elsewhere
/// (`sourceCommit` is empty) may predate some targets.
Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  if (options == null) return;

  final repository = options.option('repository')!;
  final tag = options.rest.isNotEmpty
      ? options.rest.single
      : current.releaseTag;
  final assetsDir = options.option('assets');
  final sourceCommit =
      options.option('source-commit') ??
      await _sourceCommit(repository: repository, tag: tag);

  stdout.writeln(
    assetsDir == null
        ? 'Hashing the assets of release $tag of $repository...'
        : 'Hashing the assets of release $tag of $repository in $assetsDir...',
  );

  final targetAssetNames = [
    for (final (os, arch, iosSdk) in prebuiltTargets)
      for (final static in [false, true])
        releaseAssetName(os, arch, iosSdk: iosSdk, static: static),
  ];

  final ({Map<String, String> hashes, List<String> missing}) resolved;
  try {
    resolved = assetsDir != null
        ? await _hashLocalAssets(Directory(assetsDir), targetAssetNames)
        : await resolveRemoteAssetHashes(
            repository: repository,
            tag: tag,
            assetNames: targetAssetNames,
            githubToken:
                Platform.environment['GITHUB_TOKEN'] ??
                Platform.environment['GH_TOKEN'],
          );
  } on DownloadException catch (e) {
    stderr.writeln('Not updating $_hashesFile: $e');
    exit(1);
  }

  _checkMissingAssets(
    hashes: resolved.hashes,
    missing: resolved.missing,
    repository: repository,
    tag: tag,
    sourceCommit: sourceCommit,
  );

  await _writeHashesFile(
    repository: repository,
    tag: tag,
    sourceCommit: sourceCommit,
    fileHashes: resolved.hashes,
  );
}

ArgResults? _parseArgs(List<String> args) {
  final parser = ArgParser()
    ..addOption(
      'repository',
      help: 'The GitHub repository (owner/name) of the release.',
      defaultsTo: current.releaseRepository,
    )
    ..addOption(
      'source-commit',
      help:
          'The commit of this repository that the libraries were built from. '
          'Defaults to the commit of the tag, looked up with git ls-remote.',
    )
    ..addOption(
      'assets',
      help:
          'A directory with the release assets to hash instead of downloading '
          'them.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults options;
  try {
    options = parser.parse(args);
    if (options.rest.length > 1) {
      throw FormatException('Expected at most one tag, got ${options.rest}.');
    }
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${_usage(parser)}');
    exit(64);
  }
  if (options.flag('help')) {
    stdout.writeln(_usage(parser));
    return null;
  }
  return options;
}

void _checkMissingAssets({
  required Map<String, String> hashes,
  required List<String> missing,
  required String repository,
  required String tag,
  required String sourceCommit,
}) {
  if (missing.isEmpty) return;
  final summary =
      '${missing.length} of the ${hashes.length + missing.length} '
      'assets of the prebuilt targets are missing from release $tag of '
      '$repository:\n  ${missing.join('\n  ')}';
  if (sourceCommit.isNotEmpty) {
    stderr.writeln('Not updating $_hashesFile: $summary');
    exit(1);
  }
  stdout.writeln(
    'Warning: $summary\nThe release wasn\'t built by this repository.',
  );
}

Future<void> _writeHashesFile({
  required String repository,
  required String tag,
  required String sourceCommit,
  required Map<String, String> fileHashes,
}) async {
  final buffer = StringBuffer()
    ..write(await _licenseHeader())
    ..writeln()
    ..writeln('// coverage:ignore-file')
    ..writeln('// THIS FILE IS GENERATED BY `tool/regenerate_hashes.dart`.')
    ..writeln()
    ..writeln(
      '/// The GitHub repository of the release with the prebuilt '
      'libraries.',
    )
    ..writeln("const releaseRepository = '$repository';")
    ..writeln()
    ..writeln('/// The tag of the release with the prebuilt libraries.')
    ..writeln("const releaseTag = '$tag';")
    ..writeln()
    ..writeln(
      '/// The commit of this repository that the libraries were built '
      'from, or empty',
    )
    ..writeln('/// if they were built elsewhere. The `analyze` job of')
    ..writeln(
      '/// .github/workflows/boring.yaml checks that the native sources '
      "haven't",
    )
    ..writeln('/// changed since.')
    ..writeln("const sourceCommit = '$sourceCommit';")
    ..writeln()
    ..writeln('/// Mapping from release asset name (see `releaseAssetName`) to')
    ..writeln('/// SHA-256 hash.')
    ..writeln('const fileHashes = <String, String>{');
  for (final MapEntry(:key, :value) in fileHashes.entries) {
    buffer
      ..writeln("  '$key':")
      ..writeln("      '$value',");
  }
  buffer.writeln('};');

  await File(_hashesFile).writeAsString(buffer.toString());
  final format = await Process.run(Platform.resolvedExecutable, [
    'format',
    _hashesFile,
  ]);
  if (format.exitCode != 0) {
    stderr.writeln('dart format failed:\n${format.stdout}\n${format.stderr}');
    exit(format.exitCode);
  }
  stdout.writeln(
    'Updated $_hashesFile with the ${fileHashes.length} hashes of release '
    '$tag of $repository'
    '${sourceCommit.isEmpty ? '' : ', built from $sourceCommit'}.',
  );
}

Future<({Map<String, String> hashes, List<String> missing})> _hashLocalAssets(
  Directory directory,
  List<String> assetNames,
) async {
  final hashes = <String, String>{};
  final missing = <String>[];
  for (final assetName in assetNames) {
    final bytes = await _readLocal(directory, assetName);
    if (bytes == null) {
      missing.add(assetName);
      continue;
    }
    final hash = sha256.convert(bytes).toString();
    hashes[assetName] = hash;
    stdout.writeln('  $assetName: $hash');
  }
  return (hashes: hashes, missing: missing);
}

/// Resolves the SHA-256 hashes for [assetNames] in GitHub release [tag] of
/// [repository].
///
/// Queries the GitHub Releases API first so all asset SHA-256 digests are
/// retrieved in a single metadata request when available, falling back to
/// downloading individual release assets (with retries on transient failures)
/// if the API is unavailable or an older release lacks asset digests.
Future<({Map<String, String> hashes, List<String> missing})>
resolveRemoteAssetHashes({
  required String repository,
  required String tag,
  required List<String> assetNames,
  Uri? apiBaseUri,
  Uri? downloadBaseUri,
  String? githubToken,
  int maxAttempts = _defaultMaxAttempts,
  Future<void> Function(Duration) delay = Future<void>.delayed,
}) async {
  final effectiveApiBase = apiBaseUri ?? Uri.parse('https://api.github.com');
  final effectiveDownloadBase =
      downloadBaseUri ?? Uri.parse('https://github.com');
  final httpClient = HttpClient()
    ..connectionTimeout = _connectionTimeout
    ..findProxy = HttpClient.findProxyFromEnvironment;
  try {
    final apiResult = await _fetchReleaseDigests(
      httpClient,
      apiBaseUri: effectiveApiBase,
      repository: repository,
      tag: tag,
      githubToken: githubToken,
      maxAttempts: maxAttempts,
      delay: delay,
    );
    switch (apiResult) {
      case _ReleaseNotFound():
        for (final assetName in assetNames) {
          stdout.writeln('  Missing: $assetName');
        }
        return (hashes: <String, String>{}, missing: List.of(assetNames));
      case _ReleaseApiUnavailable(:final reason):
        stdout.writeln(
          '  Note: GitHub Releases API unavailable ($reason); '
          'falling back to asset downloads.',
        );
        return await _downloadMissingDigests(
          httpClient,
          downloadBaseUri: effectiveDownloadBase,
          repository: repository,
          tag: tag,
          assetNames: assetNames,
          apiAssets: null,
          maxAttempts: maxAttempts,
          delay: delay,
        );
      case _ReleaseDigestsLoaded(:final assets):
        return await _downloadMissingDigests(
          httpClient,
          downloadBaseUri: effectiveDownloadBase,
          repository: repository,
          tag: tag,
          assetNames: assetNames,
          apiAssets: assets,
          maxAttempts: maxAttempts,
          delay: delay,
        );
    }
  } finally {
    httpClient.close(force: true);
  }
}

Future<({Map<String, String> hashes, List<String> missing})>
_downloadMissingDigests(
  HttpClient httpClient, {
  required Uri downloadBaseUri,
  required String repository,
  required String tag,
  required List<String> assetNames,
  required Map<String, String?>? apiAssets,
  required int maxAttempts,
  required Future<void> Function(Duration) delay,
}) async {
  final hashes = <String, String>{};
  final missing = <String>[];
  for (final assetName in assetNames) {
    if (apiAssets != null) {
      if (!apiAssets.containsKey(assetName)) {
        stdout.writeln('  Missing: $assetName');
        missing.add(assetName);
        continue;
      }
      if (apiAssets[assetName] case final digest?) {
        hashes[assetName] = digest;
        stdout.writeln('  $assetName: $digest');
        continue;
      }
    }
    final assetUrl = downloadBaseUri.resolve(
      '/$repository/releases/download/$tag/$assetName',
    );
    final bytes = await _fetchWithRetry(
      httpClient,
      assetUrl,
      maxAttempts: maxAttempts,
      delay: delay,
    );
    if (bytes == null) {
      missing.add(assetName);
      continue;
    }
    final hash = sha256.convert(bytes).toString();
    hashes[assetName] = hash;
    stdout.writeln('  $assetName: $hash');
  }
  return (hashes: hashes, missing: missing);
}

Future<_ReleaseApiResult> _fetchReleaseDigests(
  HttpClient client, {
  required Uri apiBaseUri,
  required String repository,
  required String tag,
  required String? githubToken,
  required int maxAttempts,
  required Future<void> Function(Duration) delay,
}) async {
  final url = apiBaseUri.resolve('/repos/$repository/releases/tags/$tag');
  final headers = <String, String>{
    HttpHeaders.acceptHeader: 'application/vnd.github+json',
    HttpHeaders.userAgentHeader: 'dart-pkg-boring',
    'X-GitHub-Api-Version': '2022-11-28',
    if (githubToken != null && githubToken.isNotEmpty)
      HttpHeaders.authorizationHeader: 'Bearer $githubToken',
  };

  for (var attempt = 1; ; attempt++) {
    try {
      final response = await _sendGet(client, url, headers: headers);
      return _parseReleaseApiResponse(response);
    } on _RetryableFailure catch (failure) {
      if (attempt >= maxAttempts) {
        return _ReleaseApiUnavailable(failure.message);
      }
      final backoff = Duration(seconds: 1 << (attempt - 1));
      stdout.writeln(
        '  Retrying GitHub Releases API after ${failure.summary} '
        'in ${backoff.inSeconds}s (attempt ${attempt + 1} of $maxAttempts)...',
      );
      await delay(backoff);
    }
  }
}

_ReleaseApiResult _parseReleaseApiResponse(
  ({int statusCode, List<int> bytes}) response,
) {
  if (response.statusCode == HttpStatus.notFound) {
    return const _ReleaseNotFound();
  }
  if (response.statusCode != HttpStatus.ok) {
    return _ReleaseApiUnavailable('HTTP ${response.statusCode}');
  }
  try {
    final decoded = jsonDecode(utf8.decode(response.bytes));
    if (decoded is! Map<String, Object?>) {
      return const _ReleaseApiUnavailable('unexpected JSON root');
    }
    final rawAssets = decoded['assets'];
    if (rawAssets is! List<Object?>) {
      return const _ReleaseApiUnavailable('missing assets list');
    }
    final assets = <String, String?>{};
    for (final item in rawAssets) {
      if (item case {'name': final String name, 'digest': final rawDigest}) {
        final match = rawDigest is String
            ? _sha256DigestPattern.firstMatch(rawDigest)
            : null;
        assets[name] = match?.group(1);
      }
    }
    return _ReleaseDigestsLoaded(assets);
  } on FormatException catch (e) {
    return _ReleaseApiUnavailable('invalid JSON: $e');
  }
}

/// The license header of the existing hashes.dart, whose copyright year is the
/// year the file was created, or a new one for the current year.
Future<String> _licenseHeader() async {
  final file = File(_hashesFile);
  if (await file.exists()) {
    final header = (await file.readAsLines())
        .takeWhile((line) => line.startsWith('//'))
        .toList();
    if (header.length == 3 && header.first.startsWith('// Copyright (c) ')) {
      return '${header.join('\n')}\n';
    }
  }
  return '// Copyright (c) ${DateTime.now().year}, the Dart project authors. '
      'Please see the AUTHORS file\n'
      '// for details. All rights reserved. Use of this source code is '
      'governed by a\n'
      '// BSD-style license that can be found in the LICENSE file.\n';
}

String _usage(ArgParser parser) =>
    'Usage: dart run tool/regenerate_hashes.dart [options] [tag]\n\n'
    'Pins the prebuilt libraries of the GitHub release [tag] (default: '
    '${current.releaseTag}).\n\n'
    '${parser.usage}';

/// The commit that the libraries of release [tag] were built from.
///
/// Keeps the current one if the release is unchanged. Otherwise looks up the
/// tag's commit with `git ls-remote`, which unlike the GitHub API isn't rate
/// limited, if the release is in this repository, that is, if it was built by
/// .github/workflows/boring_binaries.yaml.
Future<String> _sourceCommit({
  required String repository,
  required String tag,
}) async {
  if (repository == current.releaseRepository && tag == current.releaseTag) {
    return current.sourceCommit;
  }
  if (!tag.startsWith('boring-binaries-')) {
    // A release of another repository, such as mosuem/boring.
    return '';
  }
  final result = await Process.run('git', [
    'ls-remote',
    'https://github.com/$repository.git',
    'refs/tags/$tag',
    'refs/tags/$tag^{}',
  ]);
  if (result.exitCode != 0) {
    stderr.writeln(
      'Failed to look up the commit of tag $tag with git ls-remote:\n'
      '${result.stderr}\n'
      'Pass it with --source-commit.',
    );
    exit(1);
  }
  final lines = (result.stdout as String).trim().split('\n');
  // The peeled commit of an annotated tag comes last; a lightweight tag only
  // has the one line.
  final commit = lines.last.split(RegExp(r'\s+')).first;
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
    stderr.writeln(
      'Tag $tag not found in $repository. Pass the commit the libraries were '
      'built from with --source-commit.',
    );
    exit(1);
  }
  return commit;
}

Future<List<int>?> _readLocal(Directory directory, String assetName) async {
  final file = File.fromUri(directory.uri.resolve(assetName));
  if (!await file.exists()) {
    stdout.writeln('  Missing: ${file.path}');
    return null;
  }
  return file.readAsBytes();
}

/// Downloads [url] with retries on transient errors, or returns `null` if
/// there is no such asset (`HTTP 404`).
///
/// Throws a [DownloadException] for any other failure, which must not be
/// mistaken for a missing asset.
Future<List<int>?> _fetchWithRetry(
  HttpClient client,
  Uri url, {
  required int maxAttempts,
  required Future<void> Function(Duration) delay,
}) async {
  for (var attempt = 1; ; attempt++) {
    try {
      final response = await _sendGet(client, url);
      if (response.statusCode == HttpStatus.notFound) {
        stdout.writeln('  Missing: $url');
        return null;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw DownloadException('$url returned status ${response.statusCode}.');
      }
      return response.bytes;
    } on _RetryableFailure catch (failure) {
      if (attempt >= maxAttempts) {
        throw DownloadException(failure.message);
      }
      final backoff = Duration(seconds: 1 << (attempt - 1));
      stdout.writeln(
        '  Retrying $url after ${failure.summary} '
        'in ${backoff.inSeconds}s (attempt ${attempt + 1} of $maxAttempts)...',
      );
      await delay(backoff);
    }
  }
}

Future<({int statusCode, List<int> bytes})> _sendGet(
  HttpClient client,
  Uri url, {
  Map<String, String> headers = const {},
}) async {
  try {
    final request = await client.getUrl(url).timeout(_connectionTimeout);
    for (final MapEntry(:key, :value) in headers.entries) {
      request.headers.set(key, value);
    }
    final response = await request.close().timeout(_connectionTimeout);
    final statusCode = response.statusCode;
    final retryable =
        statusCode == HttpStatus.requestTimeout ||
        (statusCode >= 500 && statusCode < 600);
    if (retryable) {
      await response.drain<void>().timeout(_connectionTimeout);
      throw _RetryableFailure(
        message: '$url returned status $statusCode.',
        summary: 'HTTP $statusCode',
      );
    }
    if (statusCode != HttpStatus.ok) {
      await response.drain<void>().timeout(_connectionTimeout);
      return (statusCode: statusCode, bytes: const <int>[]);
    }
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add).timeout(_downloadTimeout);
    return (statusCode: statusCode, bytes: builder.takeBytes());
  } on IOException catch (e) {
    throw _RetryableFailure(
      message: 'Failed to download $url: $e',
      summary: '$e',
    );
  } on TimeoutException catch (e) {
    throw _RetryableFailure(
      message: 'Timed out downloading $url: $e',
      summary: 'timeout',
    );
  }
}

sealed class _ReleaseApiResult {
  const _ReleaseApiResult();
}

final class _ReleaseDigestsLoaded extends _ReleaseApiResult {
  final Map<String, String?> assets;

  const _ReleaseDigestsLoaded(this.assets);
}

final class _ReleaseNotFound extends _ReleaseApiResult {
  const _ReleaseNotFound();
}

final class _ReleaseApiUnavailable extends _ReleaseApiResult {
  final String reason;

  const _ReleaseApiUnavailable(this.reason);
}

final class _RetryableFailure implements Exception {
  final String message;
  final String summary;

  const _RetryableFailure({required this.message, required this.summary});
}

final class DownloadException implements Exception {
  final String message;

  DownloadException(this.message);

  @override
  String toString() => message;
}
