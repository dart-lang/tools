// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:boring/src/hook_helpers/build_options.dart';
import 'package:boring/src/hook_helpers/prebuilt.dart';
import 'package:boring/src/hook_helpers/targets.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:test/test.dart';

void main() {
  group('prebuiltLibraryPath', () {
    test('uses the platform library names', () {
      expect(
        prebuiltLibraryPath(OS.linux, Architecture.x64, static: false),
        'linux-x64/libbssl_dart.so',
      );
      expect(
        prebuiltLibraryPath(OS.linux, Architecture.arm64, static: true),
        'linux-arm64/libbssl_dart_static.a',
      );
      expect(
        prebuiltLibraryPath(OS.macOS, Architecture.arm64, static: false),
        'macos-arm64/libbssl_dart.dylib',
      );
      expect(
        prebuiltLibraryPath(OS.windows, Architecture.x64, static: false),
        'windows-x64/bssl_dart.dll',
      );
      expect(
        prebuiltLibraryPath(OS.windows, Architecture.x64, static: true),
        'windows-x64/bssl_dart_static.lib',
      );
    });

    test('distinguishes the iOS SDKs', () {
      expect(
        prebuiltLibraryPath(
          OS.iOS,
          Architecture.arm64,
          iosSdk: IOSSdk.iPhoneSimulator,
          static: true,
        ),
        'ios-arm64-iphonesimulator/libbssl_dart_static.a',
      );
    });

    test('gives every prebuilt library its own path', () {
      final paths = [
        for (final (os, arch, iosSdk) in prebuiltTargets)
          for (final static in [false, true])
            prebuiltLibraryPath(os, arch, iosSdk: iosSdk, static: static),
      ];
      expect(paths.toSet(), hasLength(paths.length));
    });
  });

  group('BuildOptions.fromDefines', () {
    test('defaults to fetch', () {
      final options = BuildOptions.fromDefines(_userDefines({}));
      expect(options.buildMode, BuildModeEnum.fetch);
      expect(options.localPath, isNull);
    });

    test('parses every build mode', () {
      for (final mode in BuildModeEnum.values) {
        expect(
          BuildOptions.fromDefines(_userDefines({'buildMode': mode.name}))
              .buildMode,
          mode,
        );
      }
    });

    test('resolves localPath against the pubspec', () {
      final options = BuildOptions.fromDefines(
        _userDefines({'buildMode': 'local', 'localPath': 'lib/libfoo.so'}),
      );
      expect(options.buildMode, BuildModeEnum.local);
      expect(options.localPath, _basePath.resolve('lib/libfoo.so'));
    });

    test('rejects an unknown build mode instead of fetching', () {
      expect(
        () => BuildOptions.fromDefines(_userDefines({'buildMode': 'chekout'})),
        throwsA(
          isA<BuildError>().having(
            (e) => e.message,
            'message',
            allOf(contains("'chekout'"), contains('`checkout`')),
          ),
        ),
      );
    });

    test('rejects a build mode that is not a string', () {
      expect(
        () => BuildOptions.fromDefines(_userDefines({'buildMode': true})),
        throwsA(isA<BuildError>()),
      );
    });
  });

  group('prebuiltLibrary', () {
    late Directory packageRoot;

    setUp(() async {
      packageRoot = await Directory.systemTemp.createTemp('boring_package_');
      addTearDown(() => packageRoot.delete(recursive: true));
    });

    test('returns the library in the prebuilt directory', () async {
      final library = File.fromUri(
        packageRoot.uri.resolve('prebuilt/linux-x64/libbssl_dart_static.a'),
      );
      await library.create(recursive: true);
      expect(
        prebuiltLibrary(
          _buildInput(packageRoot.uri, OS.linux, Architecture.x64),
          static: true,
        ),
        library.uri,
      );
    });

    test('throws a BuildError if the package has no prebuilt libraries', () {
      final library = packageRoot.uri.resolve(
        'prebuilt/linux-x64/libbssl_dart.so',
      );
      expect(
        () => prebuiltLibrary(
          _buildInput(packageRoot.uri, OS.linux, Architecture.x64),
          static: false,
        ),
        throwsA(
          isA<BuildError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains(library.toFilePath()),
              contains('git or path dependency'),
              contains('buildMode: checkout'),
            ),
          ),
        ),
      );
    });

    test('throws a BuildError when no prebuilt binary exists for target', () {
      expect(
        () => prebuiltLibrary(
          _buildInput(packageRoot.uri, OS.linux, Architecture.riscv64),
          static: false,
        ),
        throwsA(
          isA<BuildError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('linux-riscv64'),
              contains('buildMode: checkout'),
            ),
          ),
        ),
      );
    });
  });
}

final _basePath = Directory.current.uri;

/// The input of hook/build.dart for [os] and [arch] in a package at
/// [packageRoot].
BuildInput _buildInput(Uri packageRoot, OS os, Architecture arch) {
  final builder = BuildInputBuilder()
    ..setupShared(
      packageRoot: packageRoot,
      packageName: 'boring',
      outputDirectoryShared: packageRoot.resolve('.dart_tool/shared/'),
      outputFile: packageRoot.resolve('.dart_tool/output.json'),
    )
    ..config.setupBuild(linkingEnabled: false)
    ..addExtension(
      CodeAssetExtension(
        targetOS: os,
        targetArchitecture: arch,
        linkModePreference: LinkModePreference.dynamic,
      ),
    );
  return builder.build();
}

/// The user-defines of a root package whose pubspec.yaml has [defines] under
/// `hooks.user_defines.boring`.
HookInputUserDefines _userDefines(Map<String, Object?> defines) {
  final builder = BuildInputBuilder()
    ..setupShared(
      packageRoot: _basePath,
      packageName: 'boring',
      outputDirectoryShared: _basePath.resolve('.dart_tool/shared/'),
      outputFile: _basePath.resolve('.dart_tool/output.json'),
      userDefines: PackageUserDefines(
        workspacePubspec: PackageUserDefinesSource(
          defines: defines,
          basePath: _basePath,
        ),
      ),
    )
    ..config.setupBuild(linkingEnabled: false);
  return builder.build().userDefines;
}
