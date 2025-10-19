// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'bench_options.dart';

// TODO(kevmoo): allow the user to specify custom flags – for compile and/or run

Future<void> compileAndRun(BenchOptions options) async {
  if (!FileSystemEntity.isFileSync(options.target)) {
    throw BenchException(
      'The target Dart program `${options.target}` does not exist',
      2, // standard bash code for file doesn't exist
    );
  }

  for (var mode in options.flavor) {
    await _Runner(flavor: mode, target: options.target).run();
  }
}

class BenchException implements Exception {
  const BenchException(this.message, this.exitCode) : assert(exitCode > 0);
  final String message;
  final int exitCode;

  @override
  String toString() => 'BenchException: $message ($exitCode)';
}

/// Base name for output files.
const _outputFileRoot = 'out';

/// Denote the "stage" of the compile/run step for logging.
enum _Stage { compile, run }

/// Base class for runtime-specific runners.
abstract class _Runner {
  _Runner._({required this.target, required this.flavor})
      : assert(FileSystemEntity.isFileSync(target), '$target is not a file');

  factory _Runner({required RuntimeFlavor flavor, required String target}) {
    return (switch (flavor) {
      RuntimeFlavor.jit => _JITRunner.new,
      RuntimeFlavor.aot => _AOTRunner.new,
      RuntimeFlavor.js => _JSRunner.new,
      RuntimeFlavor.wasm => _WasmRunner.new,
    })(target: target);
  }

  final String target;
  final RuntimeFlavor flavor;
  late Directory _tempDirectory;

  /// Executes the compile and run cycle.
  ///
  /// Takes care of creating and deleting the corresponding temp directory.
  Future<void> run() async {
    _tempDirectory = Directory.systemTemp
        .createTempSync('bench_${DateTime.now().millisecondsSinceEpoch}_');
    try {
      await _runImpl();
    } finally {
      _tempDirectory.deleteSync(recursive: true);
    }
  }

  /// Overridden in implementations to handle the compile and run cycle.
  Future<void> _runImpl();

  /// Executes the specific [executable] with the provided [args].
  ///
  /// Also prints out a nice message before execution denoting the [flavor] and
  /// the [stage].
  Future<void> _runProc(
      _Stage stage, String executable, List<String> args) async {
    print('''
\n${flavor.name.toUpperCase()} - ${stage.name.toUpperCase()}
$executable ${args.join(' ')}
''');

    final proc = await Process.start(executable, args,
        mode: ProcessStartMode.inheritStdio);

    final exitCode = await proc.exitCode;

    if (exitCode != 0) {
      throw ProcessException(executable, args, 'Process errored', exitCode);
    }
  }

  String _outputFile(String ext) =>
      _tempDirectory.uri.resolve('$_outputFileRoot.$ext').toFilePath();
}

class _JITRunner extends _Runner {
  _JITRunner({required super.target}) : super._(flavor: RuntimeFlavor.jit);

  @override
  Future<void> _runImpl() async {
    await _runProc(_Stage.run, Platform.executable, [target]);
  }
}

class _AOTRunner extends _Runner {
  _AOTRunner({required super.target}) : super._(flavor: RuntimeFlavor.aot);

  @override
  Future<void> _runImpl() async {
    final outFile = _outputFile('exe');
    await _runProc(_Stage.compile, Platform.executable, [
      'compile',
      'exe',
      target,
      '-o',
      outFile,
    ]);

    await _runProc(_Stage.run, outFile, []);
  }
}

class _JSRunner extends _Runner {
  _JSRunner({required super.target}) : super._(flavor: RuntimeFlavor.js);

  @override
  Future<void> _runImpl() async {
    final outFile = _outputFile('js');
    await _runProc(_Stage.compile, Platform.executable, [
      'compile',
      'js',
      target,
      '-O4', // default for Flutter
      '-o',
      outFile,
    ]);

    await _runProc(_Stage.run, 'node', [outFile]);
  }
}

class _WasmRunner extends _Runner {
  _WasmRunner({required super.target}) : super._(flavor: RuntimeFlavor.wasm);

  @override
  Future<void> _runImpl() async {
    final outFile = _outputFile('wasm');
    await _runProc(_Stage.compile, Platform.executable, [
      'compile',
      'wasm',
      target,
      '-O2', // default for Flutter
      '-o',
      outFile,
    ]);

    final jsFile =
        File.fromUri(_tempDirectory.uri.resolve('$_outputFileRoot.js'));
    jsFile.writeAsStringSync(_wasmInvokeScript);

    await _runProc(_Stage.run, 'node', [jsFile.path]);
  }

  static const _wasmInvokeScript = '''
import { readFile } from 'node:fs/promises'; // For async file reading
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Get the current directory name
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const wasmFilePath = join(__dirname, '$_outputFileRoot.wasm');
const wasmBytes = await readFile(wasmFilePath);

const mjsFilePath = join(__dirname, '$_outputFileRoot.mjs');
const dartModule = await import(mjsFilePath);
const {compile} = dartModule;

const compiledApp = await compile(wasmBytes);
const instantiatedApp = await compiledApp.instantiate({});
await instantiatedApp.invokeMain();
''';
}
