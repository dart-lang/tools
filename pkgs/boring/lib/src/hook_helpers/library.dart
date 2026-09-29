// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_cmake/native_toolchain_cmake.dart';
import 'package:prebuilt_code_assets/prebuilt_code_assets.dart';
import 'package:record_use/record_use.dart' as record_use;

import '../bindings/record_use_mapping.g.dart';
import 'hashes.dart' show fileHashes, version;

const _bindings = record_use.Library(
  'package:boring/src/bindings/boringssl.g.dart',
);

/// Creates the [PrebuiltReleaseConfig] for a given `package:boring` release
/// [releaseVersion].
PrebuiltReleaseConfig boringReleaseConfig(
  String releaseVersion, {
  Map<String, String> hashes = fileHashes,
}) => PrebuiltReleaseConfig.github(
  owner: 'mosuem',
  repo: 'boring',
  version: releaseVersion,
  fileHashes: hashes,
  libraryName: 'bssl_dart',
  staticLibraryName: 'bssl_dart_static',
);

/// Shared build and link specification for `package:boring`.
final boringLibrary = PrebuiltLibrary(
  name: 'bssl_dart',
  packageName: 'boring',
  assetName: 'boring.dart',
  envVarPrefix: 'BORING',
  releaseConfig: boringReleaseConfig(version),
  buildFromSource: buildBoringFromCMake,
  usedSymbols: SymbolsResolvers.fromRecordUseMapping(
    _bindings,
    recordUseMapping,
  ),
  allKnownSymbols: recordUseMapping.values,
);

/// Compiles BoringSSL and the `bssl_dart` wrapper from `src/CMakeLists.txt`.
Future<Uri> buildBoringFromCMake(
  BuildInput input,
  BuildOutputBuilder output, {
  required bool static,
  Uri? checkoutPath,
}) async {
  final packageRoot = checkoutPath ?? input.packageRoot;
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

  final fileName = boringReleaseConfig(version).resolveLibraryFileName(
    targetOS,
    static: static,
  );
  final library = installDir.resolve(fileName);
  if (!File.fromUri(library).existsSync()) {
    throw BuildError(
      message:
          'Failed to locate the built $fileName in '
          '${installDir.toFilePath()}',
    );
  }

  output.dependencies.addAll(
    findSourceBuildDependencies(packageRoot, const [
      'src/',
      'third_party/boringssl/',
    ]),
  );

  return library;
}
