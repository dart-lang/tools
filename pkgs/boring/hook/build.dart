// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

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

    await _buildLocalCMake(input, output);
    output.dependencies.addAll([
      input.packageRoot.resolve('pubspec.yaml'),
      input.packageRoot.resolve('hook/build.dart'),
    ]);
  });
}

/// Adds [library] as the `package:boring/boring.dart` code asset.
void _addLibrary(BuildInput input, BuildOutputBuilder output, Uri library) {
  output.assets.code.add(
    CodeAsset(
      package: input.packageName,
      name: _assetName,
      linkMode: DynamicLoadingBundled(),
      file: library,
    ),
  );
}

Future<void> _buildLocalCMake(
  BuildInput input,
  BuildOutputBuilder output,
) async {
  final packageRoot = input.packageRoot;
  final installDir = input.outputDirectory.resolve('install/');
  final sourceDir = packageRoot.resolve('src/');
  final targetOS = input.config.code.targetOS;
  final targetArch = input.config.code.targetArchitecture;

  stdout.writeln(
    'boring: building native asset with CMake for $targetOS-$targetArch.',
  );

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

  final fileName = targetOS.dylibFileName('bssl_dart');
  final library = installDir.resolve(fileName);
  if (!File.fromUri(library).existsSync()) {
    throw BuildError(
      message:
          'Failed to locate the built $fileName in '
          '${installDir.toFilePath()}',
    );
  }
  _addLibrary(input, output, library);

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
