// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:boring/src/hook_helpers/build_options.dart'
    show BuildModeEnum, BuildOptions;
import 'package:boring/src/hook_helpers/fetch.dart' show fetchPrebuiltLibrary;
import 'package:boring/src/hook_helpers/targets.dart' show libraryFileName;
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_cmake/native_toolchain_cmake.dart';

const _assetName = 'boring.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      stdout.writeln(
        'boring: skipping native asset build (code assets not requested).',
      );
      return;
    }

    final buildOptions = BuildOptions.fromDefines(input.userDefines);
    stdout.writeln('boring: build options: $buildOptions');

    // When linking is enabled (`dart build`, and Flutter's profile and release
    // builds), hook/link.dart links a dynamic library with only the functions
    // the application uses from the static library.
    final static = input.config.linkingEnabled;

    switch (buildOptions.buildMode) {
      case BuildModeEnum.fetch:
        await _fetchPrebuiltBinary(input, output, static: static);
      case BuildModeEnum.build:
      case BuildModeEnum.checkout:
        await _buildLocalCMake(input, output, static: static);
      case BuildModeEnum.local:
        await _useLocalBinary(input, output, buildOptions.localPath);
    }
    output.dependencies.addAll([
      input.packageRoot.resolve('pubspec.yaml'),
      input.packageRoot.resolve('hook/build.dart'),
      input.packageRoot.resolve('lib/src/hook_helpers/hashes.dart'),
    ]);
  });
}

/// Adds [library] as the `package:boring/boring.dart` code asset.
///
/// A [static] library is sent to hook/link.dart, which links it into the
/// dynamic library that is bundled.
void _addLibrary(
  BuildInput input,
  BuildOutputBuilder output,
  Uri library, {
  required bool static,
}) {
  output.assets.code.add(
    CodeAsset(
      package: input.packageName,
      name: _assetName,
      linkMode: static ? StaticLinking() : DynamicLoadingBundled(),
      file: library,
    ),
    routing: static ? ToLinkHook(input.packageName) : const ToAppBundle(),
  );
}

Future<void> _fetchPrebuiltBinary(
  BuildInput input,
  BuildOutputBuilder output, {
  required bool static,
}) async {
  final cachedLibrary = await fetchPrebuiltLibrary(input, static: static);
  if (cachedLibrary == null) {
    stdout.writeln(
      'boring: falling back to building from local source via CMake.',
    );
    await _buildLocalCMake(input, output, static: static);
    return;
  }
  _addLibrary(input, output, cachedLibrary, static: static);
}

/// Bundles the dynamic library at [localPath] as is, even when linking is
/// enabled.
Future<void> _useLocalBinary(
  BuildInput input,
  BuildOutputBuilder output,
  Uri? localPath,
) async {
  if (localPath == null) {
    throw BuildError(
      message:
          'buildMode is set to `local`, but `localPath` was not specified '
          'under `hooks.user_defines.boring`.',
    );
  }
  final file = File.fromUri(localPath);
  if (!file.existsSync()) {
    throw BuildError(
      message:
          'Specified local binary does not exist at ${localPath.toFilePath()}',
    );
  }
  final dylibFileName = input.config.code.targetOS.dylibFileName('bssl_dart');
  final destFile = File.fromUri(input.outputDirectory.resolve(dylibFileName));
  await file.copy(destFile.path);

  _addLibrary(input, output, destFile.uri, static: false);
  output.dependencies.add(localPath);
}

Future<void> _buildLocalCMake(
  BuildInput input,
  BuildOutputBuilder output, {
  required bool static,
}) async {
  final packageRoot = input.packageRoot;
  final installDir = input.outputDirectory.resolve('install/');
  final sourceDir = packageRoot.resolve('src/');
  final targetOS = input.config.code.targetOS;
  final targetArch = input.config.code.targetArchitecture;

  stdout.writeln(
    'boring: building native asset with CMake for $targetOS-$targetArch.',
  );

  // Installs both the dynamic and the static library, see src/CMakeLists.txt.
  final builder = CMakeBuilder.create(
    name: 'bssl_dart',
    sourceDir: sourceDir,
    defines: {
      'CMAKE_BUILD_TYPE': 'Release',
      'CMAKE_INSTALL_PREFIX': installDir.toFilePath(),
    },
    targets: ['install'],
    parallelUseAllProcessors: true,
  );

  await builder.run(input: input, output: output);

  final fileName = libraryFileName(targetOS, static: static);
  final library = installDir.resolve(fileName);
  if (!File.fromUri(library).existsSync()) {
    throw BuildError(
      message:
          'Failed to locate the built $fileName in '
          '${installDir.toFilePath()}',
    );
  }
  _addLibrary(input, output, library, static: static);

  output.dependencies.addAll(_buildDependencies(packageRoot));
}

final _buildDependencyExtensions = {
  '.S',
  '.asm',
  '.c',
  '.cc',
  '.cmake',
  '.cpp',
  '.h',
  '.s',
  'CMakeLists.txt',
};

Iterable<Uri> _buildDependencies(Uri packageRoot) sync* {
  yield* _filesForBuild(Directory.fromUri(packageRoot.resolve('src/')));
  yield* _filesForBuild(
    Directory.fromUri(packageRoot.resolve('third_party/boringssl/')),
  );
}

Iterable<Uri> _filesForBuild(Directory root) sync* {
  if (!root.existsSync()) {
    return;
  }

  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    if (!_buildDependencyExtensions.any(entity.uri.path.endsWith)) {
      continue;
    }
    yield entity.uri;
  }
}
