// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'dart:io';
import 'dart:typed_data';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:hooks/hooks.dart';
import 'package:sigstore/src/hook_helpers/builder.dart';
import 'package:sigstore/src/hook_helpers/hashes.dart' show fileHashes, version;

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      print('Building code assets is disabled in this run, skipping build.');
      return;
    }
    BuildOptions buildOptions;
    try {
      buildOptions = BuildOptions.fromDefines(input.userDefines);
    } catch (e) {
      throw ArgumentError('''
Error: $e

Set the build mode with either `fetch`, `local`, or `checkout` in your pubspec:

* fetch: Fetch the precompiled binary from releases/CDN.
hooks:
  user_defines:
    sigstore:
      buildMode: fetch

* local: Use a locally existing binary.
hooks:
  user_defines:
    sigstore:
      buildMode: local
      localPath: path/to/dylib.so

* checkout: Build a fresh library from local Rust source.
hooks:
  user_defines:
    sigstore:
      buildMode: checkout
      checkoutPath: rust/
''');
    }

    final buildMode = switch (buildOptions.buildMode) {
      BuildModeEnum.local => LocalMode(input, buildOptions.localPath),
      BuildModeEnum.checkout => CheckoutMode(input, buildOptions.checkoutPath),
      BuildModeEnum.fetch => FetchMode(input),
    };

    final builtLibrary = await buildMode.build();

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/bindings/lib.g.dart',
        linkMode: input.config.buildStatic
            ? StaticLinking()
            : DynamicLoadingBundled(),
        file: builtLibrary,
      ),
    );
    output.dependencies.addAll(buildMode.dependencies);
    output.dependencies.add(input.packageRoot.resolve('pubspec.yaml'));
  });
}

enum BuildModeEnum { local, checkout, fetch }

class BuildOptions {
  final BuildModeEnum buildMode;
  final Uri? localPath;
  final Uri? checkoutPath;

  BuildOptions({required this.buildMode, this.localPath, this.checkoutPath});

  factory BuildOptions.fromDefines(HookInputUserDefines defines) {
    // Only `hooks.user_defines` of the root package reach the hook; the hook
    // runner does not forward arbitrary environment variables.
    final modeName = defines['buildMode'];
    return BuildOptions(
      buildMode: BuildModeEnum.values.firstWhere(
        (element) => element.name == modeName,
        orElse: () => BuildModeEnum.fetch,
      ),
      localPath: defines.path('localPath'),
      checkoutPath: defines.path('checkoutPath'),
    );
  }

  @override
  String toString() {
    return 'BuildOptions(buildMode: $buildMode, '
        'localPath: $localPath, checkoutPath: $checkoutPath)';
  }
}

sealed class BuildMode {
  final BuildInput input;

  const BuildMode(this.input);

  List<Uri> get dependencies;

  Future<Uri> build();
}

final class FetchMode extends BuildMode {
  FetchMode(super.input);

  @override
  Future<Uri> build() async {
    final rustTarget = asRustTarget(input.config.code);
    final libraryType = input.config.buildStatic ? 'static' : 'dynamic';
    // Never run a binary whose hash is not pinned in hashes.dart: a release
    // asset that is missing from the table was not part of this package
    // version's release, and must not be downloaded unverified.
    final expectedFileHash = fileHashes[(rustTarget, libraryType)];
    if (expectedFileHash == null) {
      final supported = fileHashes.keys
          .where((key) => key.$2 == libraryType)
          .map((key) => key.$1)
          .join(', ');
      throw UnsupportedError(
        'package:sigstore has no precompiled $libraryType library for '
        '$rustTarget in release $version (available: $supported). Build it '
        'from source instead by setting the `checkout` build mode in the '
        'pubspec of your application:\n'
        'hooks:\n'
        '  user_defines:\n'
        '    sigstore:\n'
        '      buildMode: checkout',
      );
    }

    final httpClient = HttpClient();
    try {
      final dylibRemoteUri = Uri.parse(
        'https://github.com/mosuem/sigstore/releases/'
        'download/$version/libsigstore_ffi-$libraryType-$rustTarget',
      );
      final request = await httpClient.getUrl(dylibRemoteUri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw ArgumentError(
          'The request to $dylibRemoteUri failed with status '
          '${response.statusCode}',
        );
      }
      final builder = BytesBuilder(copy: false);
      await response.forEach(builder.add);
      final bytes = builder.takeBytes();
      final fileHash = sha256.convert(bytes).toString();
      if (fileHash != expectedFileHash) {
        throw Exception(
          'The pre-built binary for the target $rustTarget-$libraryType at '
          '$dylibRemoteUri has a hash of $fileHash, which does not match '
          '$expectedFileHash.',
        );
      }
      final library = File.fromUri(
        input.outputDirectory.resolve(input.config.filename('sigstore_ffi')),
      );
      await library.writeAsBytes(bytes);
      return library.uri;
    } finally {
      httpClient.close();
    }
  }

  @override
  List<Uri> get dependencies => [];
}

final class LocalMode extends BuildMode {
  final Uri? localPath;
  LocalMode(super.input, this.localPath);

  String get _localLibraryPath {
    if (localPath != null) {
      return localPath!.toFilePath(windows: Platform.isWindows);
    }
    throw ArgumentError('`localPath` is not set in build options.');
  }

  @override
  Future<Uri> build() async {
    final targetOS = input.config.code.targetOS;
    final dylibFileName = targetOS.dylibFileName('sigstore_ffi');
    final dylibFileUri = input.outputDirectory.resolve(dylibFileName);
    final file = File(_localLibraryPath);
    if (!(await file.exists())) {
      throw FileSystemException('Could not find binary.', _localLibraryPath);
    }
    await file.copy(dylibFileUri.toFilePath(windows: Platform.isWindows));
    return dylibFileUri;
  }

  @override
  List<Uri> get dependencies => [Uri.file(_localLibraryPath)];
}

final class CheckoutMode extends BuildMode {
  final Uri? checkoutPath;

  CheckoutMode(super.input, this.checkoutPath);

  @override
  Future<Uri> build() async {
    final effectiveCheckout = checkoutPath != null
        ? input.packageRoot.resolveUri(checkoutPath!)
        : input.packageRoot.resolve('rust/');

    final out = input.outputDirectory.resolve(
      input.config.filename('sigstore_ffi'),
    );
    final rustTarget = asRustTarget(input.config.code);
    final buildStatic = input.config.buildStatic;

    await buildRustLibrary(
      rustDir: Directory.fromUri(effectiveCheckout),
      target: rustTarget,
      isStatic: buildStatic,
      outputPath: out.toFilePath(windows: Platform.isWindows),
    );

    return out;
  }

  @override
  List<Uri> get dependencies {
    final root = checkoutPath != null
        ? input.packageRoot.resolveUri(checkoutPath!)
        : input.packageRoot.resolve('rust/');
    return [
      root.resolve('Cargo.lock'),
      root.resolve('src/lib.rs'),
      root.resolve('src/boring_provider.rs'),
    ];
  }
}

extension on BuildConfig {
  bool get buildStatic => code.linkModePreference == LinkModePreference.static;

  String Function(String) get filename => buildStatic
      ? code.targetOS.staticlibFileName
      : code.targetOS.dylibFileName;
}
