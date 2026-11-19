// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:args/args.dart';
import 'package:boring/src/hook_helpers/hashes.dart' as current;
import 'package:boring/src/hook_helpers/targets.dart';
import 'package:crypto/crypto.dart' show sha256;

const _hashesFile = 'lib/src/hook_helpers/hashes.dart';

/// The workflow that builds, attests, and releases the prebuilt libraries.
const _binariesWorkflow = '.github/workflows/boring_binaries.yaml';

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
///
/// For releases built by that workflow, also fails without writing anything
/// unless `gh attestation verify` confirms that every asset has a provenance
/// attestation from that workflow on main, built from `sourceCommit`, so that
/// only libraries that this repository built from its own sources get pinned.
/// This requires the GitHub CLI (`gh`); pass `--no-verify-attestations` to
/// skip the check, for example when `gh` isn't available.
Future<void> main(List<String> args) async {
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
    ..addFlag(
      'verify-attestations',
      help:
          'Verify the provenance attestations of the assets of releases built '
          'by $_binariesWorkflow with `gh attestation verify`.',
      defaultsTo: true,
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
    return;
  }

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

  final verifyAttestations =
      options.flag('verify-attestations') && sourceCommit.isNotEmpty;
  if (options.flag('verify-attestations') && sourceCommit.isEmpty) {
    stdout.writeln(
      'Not verifying provenance attestations: the release wasn\'t built by '
      '$_binariesWorkflow of this repository.',
    );
  }

  final fileHashes = <String, String>{};
  final missing = <String>[];
  // The files to verify the provenance attestations of, by asset name.
  final assetFiles = <String, File>{};
  // Holds the downloaded assets while their attestations are verified.
  final downloadDir = verifyAttestations && assetsDir == null
      ? await Directory.systemTemp.createTemp('boring_release_assets_')
      : null;
  final httpClient = HttpClient()
    ..findProxy = HttpClient.findProxyFromEnvironment;
  try {
    for (final (os, arch, iosSdk) in prebuiltTargets) {
      for (final static in [false, true]) {
        final assetName = releaseAssetName(
          os,
          arch,
          iosSdk: iosSdk,
          static: static,
        );
        final bytes = assetsDir != null
            ? await _readLocal(Directory(assetsDir), assetName)
            : await _fetch(
                httpClient,
                releaseAssetUrl(
                  repository: repository,
                  tag: tag,
                  assetName: assetName,
                ),
              );
        if (bytes == null) {
          missing.add(assetName);
          continue;
        }
        final hash = sha256.convert(bytes).toString();
        fileHashes[assetName] = hash;
        stdout.writeln('  $assetName: $hash');
        if (verifyAttestations) {
          if (downloadDir != null) {
            final file = File.fromUri(downloadDir.uri.resolve(assetName));
            await file.writeAsBytes(bytes);
            assetFiles[assetName] = file;
          } else {
            assetFiles[assetName] = File.fromUri(
              Directory(assetsDir!).uri.resolve(assetName),
            );
          }
        }
      }
    }

    if (missing.isNotEmpty) {
      final summary =
          '${missing.length} of the ${fileHashes.length + missing.length} '
          'assets of the prebuilt targets are missing from release $tag of '
          '$repository:\n  ${missing.join('\n  ')}';
      if (sourceCommit.isNotEmpty) {
        throw _AbortException('Not updating $_hashesFile: $summary');
      }
      stdout.writeln(
        'Warning: $summary\nThe release wasn\'t built by this repository.',
      );
    }

    if (verifyAttestations) {
      await _verifyAttestations(
        repository: repository,
        sourceCommit: sourceCommit,
        assetFiles: assetFiles,
      );
    }
  } on _DownloadException catch (e) {
    stderr.writeln('Not updating $_hashesFile: $e');
    exitCode = 1;
    return;
  } on _AbortException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
    return;
  } finally {
    httpClient.close(force: true);
    await downloadDir?.delete(recursive: true);
  }

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
  for (final entry in fileHashes.entries) {
    buffer
      ..writeln("  '${entry.key}':")
      ..writeln("      '${entry.value}',");
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

/// Checks with `gh attestation verify` that each of [assetFiles] has a
/// provenance attestation from [_binariesWorkflow] of [repository], run on
/// main for [sourceCommit] on a GitHub-hosted runner, or throws an
/// [_AbortException].
Future<void> _verifyAttestations({
  required String repository,
  required String sourceCommit,
  required Map<String, File> assetFiles,
}) async {
  stdout.writeln(
    'Verifying the provenance attestations of the ${assetFiles.length} '
    'assets...',
  );
  for (final MapEntry(key: assetName, value: file) in assetFiles.entries) {
    final ProcessResult result;
    try {
      result = await Process.run('gh', [
        'attestation',
        'verify',
        file.path,
        '--repo',
        repository,
        '--signer-workflow',
        '$repository/$_binariesWorkflow',
        '--source-ref',
        'refs/heads/main',
        '--source-digest',
        sourceCommit,
        '--deny-self-hosted-runners',
      ]);
    } on ProcessException catch (e) {
      throw _AbortException(
        'Not updating $_hashesFile: failed to run the GitHub CLI to verify '
        'the provenance attestations: $e\n'
        'Install it (https://cli.github.com), or pass '
        '--no-verify-attestations.',
      );
    }
    if (result.exitCode != 0) {
      throw _AbortException(
        'Not updating $_hashesFile: failed to verify that $assetName was '
        'built from $sourceCommit by $_binariesWorkflow:\n'
        '${result.stdout}${result.stderr}',
      );
    }
    stdout.writeln('  $assetName: verified');
  }
}

Future<List<int>?> _readLocal(Directory directory, String assetName) async {
  final file = File.fromUri(directory.uri.resolve(assetName));
  if (!await file.exists()) {
    stdout.writeln('  Missing: ${file.path}');
    return null;
  }
  return file.readAsBytes();
}

/// Downloads [url], or returns `null` if there is no such asset.
///
/// Throws a [_DownloadException] for any other failure, which must not be
/// mistaken for a missing asset.
Future<List<int>?> _fetch(HttpClient client, Uri url) async {
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode == HttpStatus.notFound) {
      stdout.writeln('  Missing: $url');
      await response.drain<void>();
      return null;
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw _DownloadException('$url returned status ${response.statusCode}.');
    }
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add);
    return builder.takeBytes();
  } on IOException catch (e) {
    throw _DownloadException('Failed to download $url: $e');
  }
}

class _AbortException implements Exception {
  final String message;

  _AbortException(this.message);

  @override
  String toString() => message;
}

class _DownloadException implements Exception {
  final String message;

  _DownloadException(this.message);

  @override
  String toString() => message;
}
