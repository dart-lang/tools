// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Builds the example with `dart build cli` (both native and cross-compiled),
// which runs hook/link.dart with the recorded uses of the bindings, and checks
// that the bundled library only has the functions the example uses.
@TestOn('linux || mac-os || windows')
@Timeout(Duration(minutes: 15))
library;

import 'dart:ffi';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:prebuilt_code_assets/testing.dart';
import 'package:test/test.dart';

const _usedFunctions = ['EVP_sha256', 'EVP_DigestFinal', 'OPENSSL_free'];
const _unusedFunctions = ['EVP_sha512', 'EVP_AEAD_CTX_seal', 'X509_verify'];

void main() {
  group('native compilation', () {
    late Uri bundle;
    late File library;

    setUpAll(() async {
      final output = await Directory.systemTemp.createTemp('boring_example_');
      addTearDown(() => output.delete(recursive: true));

      final build = await Process.run(Platform.resolvedExecutable, [
        'build',
        'cli',
        '--target',
        'example/boring_example.dart',
        '--output',
        output.path,
      ]);
      expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');

      bundle = output.uri.resolve('bundle/');
      library = File.fromUri(
        bundle.resolve('lib/${OS.current.dylibFileName('bssl_dart')}'),
      );
    });

    test('the example runs', () async {
      final executable = bundle.resolve(
        'bin/boring_example${Platform.isWindows ? '.exe' : ''}',
      );
      final result = await Process.run(executable.toFilePath(), []);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(
        result.stdout,
        contains(
          'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
        ),
      );
    });

    test('the library only exports the functions the example uses', () {
      final dylib = DynamicLibrary.open(library.path);
      addTearDown(dylib.close);
      for (final used in _usedFunctions) {
        expect(dylib.providesSymbol('bssl_dart_$used'), isTrue, reason: used);
      }
      for (final unused in _unusedFunctions) {
        expect(
          dylib.providesSymbol('bssl_dart_$unused'),
          isFalse,
          reason: unused,
        );
      }
    });

    test('the library is tree-shaken', () {
      // With all functions, the library is about 3 MB.
      expect(library.lengthSync(), lessThan(1024 * 1024));
    });
  });

  group(
    'cross-compilation with toolchain (linux-arm64)',
    () {
      late Uri bundle;
      late File executable;
      late File library;

      setUpAll(() async {
        final appDir = await _createConsumerExamplePackage();
        final output = await Directory.systemTemp.createTemp(
          'boring_example_linux_arm64_',
        );
        addTearDown(() => output.delete(recursive: true));

        final build = await Process.run(
          Platform.resolvedExecutable,
          [
            'build',
            'cli',
            '--target',
            'bin/boring_example.dart',
            '--target-os=linux',
            '--target-arch=arm64',
            '--output',
            output.path,
          ],
          workingDirectory: appDir.path,
        );
        expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');

        bundle = output.uri.resolve('bundle/');
        executable = File.fromUri(bundle.resolve('bin/boring_example'));
        library = File.fromUri(
          bundle.resolve('lib/${OS.linux.dylibFileName('bssl_dart')}'),
        );
      });

      test('builds a linux-arm64 executable and dynamic library', () {
        expect(elfMachine(executable.readAsBytesSync()), elfMachineAarch64);
        expect(elfMachine(library.readAsBytesSync()), elfMachineAarch64);
      });

      test('the library only exports the functions the example uses', () {
        final symbols = elfDefinedDynamicSymbols(library.readAsBytesSync());
        for (final used in _usedFunctions) {
          expect(symbols, contains('bssl_dart_$used'), reason: used);
        }
        for (final unused in _unusedFunctions) {
          expect(symbols, isNot(contains('bssl_dart_$unused')), reason: unused);
        }
      });

      test('the library is tree-shaken', () {
        // With all functions, the library is about 3 MB.
        expect(library.lengthSync(), lessThan(1024 * 1024));
      });
    },
    skip: Platform.environment['CI'] != 'true' && !hasAarch64LinuxToolchain()
        ? 'aarch64-linux-gnu-gcc is not installed'
        : null,
  );

  group('cross-compilation without toolchain', () {
    // On macOS and Windows, `x86_64-linux-gnu-gcc` is not installed, so
    // targeting `linux-x64` exercises the linker-less fallback naturally.
    // On Linux (`x64`), we target `linux-arm64` with a stub on PATH that masks
    // `aarch64-linux-gnu-gcc` if installed.
    final targetArch = Platform.isLinux ? 'arm64' : 'x64';
    final expectedElfMachine = Platform.isLinux
        ? elfMachineAarch64
        : elfMachineX86_64;

    late Uri bundle;
    late File executable;
    late File library;

    setUpAll(() async {
      final appDir = await _createConsumerExamplePackage();
      final output = await Directory.systemTemp.createTemp(
        'boring_example_no_linker_',
      );
      addTearDown(() => output.delete(recursive: true));

      Map<String, String>? environment;
      if (Platform.isLinux) {
        final maskDir = await Directory.systemTemp.createTemp(
          'boring_no_aarch64_gcc_',
        );
        addTearDown(() => maskDir.delete(recursive: true));
        final fakeGcc = File.fromUri(
          maskDir.uri.resolve('aarch64-linux-gnu-gcc'),
        );
        await fakeGcc.writeAsString('#!/bin/sh\nexit 1\n');
        await Process.run('chmod', ['+x', fakeGcc.path]);
        final currentPath = Platform.environment['PATH'] ?? '';
        environment = {'PATH': '${maskDir.path}:$currentPath'};
      }

      final build = await Process.run(
        Platform.resolvedExecutable,
        [
          'build',
          'cli',
          '--target',
          'bin/boring_example.dart',
          '--target-os=linux',
          '--target-arch=$targetArch',
          '--output',
          output.path,
        ],
        workingDirectory: appDir.path,
        environment: environment,
      );
      expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');

      bundle = output.uri.resolve('bundle/');
      executable = File.fromUri(bundle.resolve('bin/boring_example'));
      library = File.fromUri(
        bundle.resolve('lib/${OS.linux.dylibFileName('bssl_dart')}'),
      );
    });

    test('builds a linux-$targetArch executable and dynamic library', () {
      expect(elfMachine(executable.readAsBytesSync()), expectedElfMachine);
      expect(elfMachine(library.readAsBytesSync()), expectedElfMachine);
    });

    test(
      'falls back to bundling the pre-built dynamic library without '
      'tree-shaking',
      () {
        final symbols = elfDefinedDynamicSymbols(library.readAsBytesSync());
        for (final used in _usedFunctions) {
          expect(symbols, contains('bssl_dart_$used'), reason: used);
        }
        for (final unused in _unusedFunctions) {
          expect(symbols, contains('bssl_dart_$unused'), reason: unused);
        }
        expect(library.lengthSync(), greaterThan(1024 * 1024));
      },
    );
  });
}

/// Creates a temporary consumer package (using the default `fetch` build mode)
/// so cross-compilation uses the pre-built release binaries rather than
/// compiling BoringSSL from source with CMake.
Future<Directory> _createConsumerExamplePackage() async {
  final appDir = await Directory.systemTemp.createTemp(
    'boring_example_cross_app_',
  );
  addTearDown(() => appDir.delete(recursive: true));

  final repoRoot = Directory.current.uri;
  await File.fromUri(appDir.uri.resolve('pubspec.yaml')).writeAsString('''
name: boring_cross_example
publish_to: none
environment:
  sdk: ^3.10.0
dependencies:
  boring:
    path: ${repoRoot.toFilePath()}
''');

  final binDir = Directory.fromUri(appDir.uri.resolve('bin/'));
  await binDir.create(recursive: true);
  await File(
    'example/boring_example.dart',
  ).copy(binDir.uri.resolve('boring_example.dart').toFilePath());

  final pubGet = await Process.run(
    Platform.resolvedExecutable,
    ['pub', 'get'],
    workingDirectory: appDir.path,
  );
  expect(
    pubGet.exitCode,
    0,
    reason: '${pubGet.stdout}\n${pubGet.stderr}',
  );
  return appDir;
}
