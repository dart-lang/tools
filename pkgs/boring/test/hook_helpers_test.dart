// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:boring/src/hook_helpers/build_options.dart';
import 'package:boring/src/hook_helpers/hashes.dart';
import 'package:boring/src/hook_helpers/targets.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:test/test.dart';

void main() {
  group('hashes.dart', () {
    // If the asset naming and the hashes file drift apart, `fetch` finds no
    // hash and silently compiles from source for every user.
    test('pins exactly the assets of the prebuilt targets', () {
      final expected = {
        for (final (os, arch, iosSdk) in prebuiltTargets)
          for (final static in [false, true])
            releaseAssetName(os, arch, iosSdk: iosSdk, static: static),
      };
      if (sourceCommit.isEmpty) {
        // A release built elsewhere may predate some of the prebuilt targets,
        // which then compile from source.
        expect(fileHashes, isNotEmpty);
        expect(expected, containsAll(fileHashes.keys));
      } else {
        expect(fileHashes.keys, unorderedEquals(expected));
      }
    });

    test('has SHA-256 hashes', () {
      for (final MapEntry(key: asset, value: hash) in fileHashes.entries) {
        expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')), reason: asset);
      }
    });

    test('pins a release', () {
      expect(releaseRepository, matches(RegExp(r'^[\w.-]+/[\w.-]+$')));
      expect(releaseTag, isNotEmpty);
      expect(sourceCommit, anyOf(isEmpty, matches(RegExp(r'^[0-9a-f]{40}$'))));
      expect(
        releaseAssetUrl(
          repository: releaseRepository,
          tag: releaseTag,
          assetName: 'boring-linux-x64-libbssl_dart.so',
        ).toString(),
        'https://github.com/$releaseRepository/releases/download/$releaseTag/'
        'boring-linux-x64-libbssl_dart.so',
      );
    });
  });

  group('releaseAssetName', () {
    test('uses the platform library names', () {
      expect(
        releaseAssetName(OS.linux, Architecture.x64, static: false),
        'boring-linux-x64-libbssl_dart.so',
      );
      expect(
        releaseAssetName(OS.linux, Architecture.arm64, static: true),
        'boring-linux-arm64-libbssl_dart_static.a',
      );
      expect(
        releaseAssetName(OS.macOS, Architecture.arm64, static: false),
        'boring-macos-arm64-libbssl_dart.dylib',
      );
      expect(
        releaseAssetName(OS.windows, Architecture.x64, static: false),
        'boring-windows-x64-bssl_dart.dll',
      );
      expect(
        releaseAssetName(OS.windows, Architecture.x64, static: true),
        'boring-windows-x64-bssl_dart_static.lib',
      );
    });

    test('distinguishes the iOS SDKs', () {
      expect(
        releaseAssetName(
          OS.iOS,
          Architecture.arm64,
          iosSdk: IOSSdk.iPhoneSimulator,
          static: true,
        ),
        'boring-ios-arm64-iphonesimulator-libbssl_dart_static.a',
      );
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
}

final _basePath = Directory.current.uri;

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
