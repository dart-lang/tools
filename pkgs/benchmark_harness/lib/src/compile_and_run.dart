// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'bench.dart';

// TODO: allow flags
// TODO: default flags for JS and Wasm ?

enum RuntimeFlavor { aot, jit, js, wasm }

enum Stage { compile, run }

Future<void> compileAndRun(BenchOptions options) => _Runner.run(options);

class BenchException implements Exception {
  const BenchException(this.message, this.exitCode) : assert(exitCode > 0);
  final String message;
  final int exitCode;

  @override
  String toString() => 'BenchException: $message ($exitCode)';
}

class _Runner {
  _Runner(this._target) {
    if (!FileSystemEntity.isFileSync(_target)) {
      throw BenchException(
        'The target Dart program `$_target` does not exist',
        2, // standard bash code for file doesn't exist
      );
    }
  }

  final String _target;
  late RuntimeFlavor _currentFlavor;
  late Directory _tempDirectory;

  Future<void> _runFlavor(RuntimeFlavor flavor) async {
    _currentFlavor = flavor;
    _tempDirectory = Directory.systemTemp
        .createTempSync('bench_${DateTime.now().millisecondsSinceEpoch}_');

    try {
      await switch (flavor) {
        RuntimeFlavor.aot => _aot(),
        RuntimeFlavor.jit => _jit(),
        RuntimeFlavor.js => _js(),
        RuntimeFlavor.wasm => _wasm(),
      };
    } finally {
      _tempDirectory.deleteSync(recursive: true);
    }
  }

  static Future<void> run(BenchOptions options) async {
    final runner = _Runner(options.target);

    for (var mode in options.flavor) {
      await runner._runFlavor(mode);
    }
  }

  Future<void> _aot() async {
    final outFile = _outputFile('exe');
    await _runProc(Stage.compile, Platform.executable, [
      'compile',
      'exe',
      _target,
      '-o',
      outFile,
    ]);

    await _runProc(Stage.run, outFile, []);
  }

  Future<void> _js() async {
    final outFile = _outputFile('js');
    await _runProc(Stage.compile, Platform.executable, [
      'compile',
      'js',
      _target,
      '-o',
      outFile,
    ]);

    await _runProc(Stage.run, 'node', [outFile]);
  }

  Future<void> _wasm() async {
    final outFile = _outputFile('wasm');
    await _runProc(Stage.compile, Platform.executable, [
      'compile',
      'wasm',
      _target,
      '-o',
      outFile,
    ]);

    final jsFile =
        File.fromUri(_tempDirectory.uri.resolve('$_outputFileRoot.js'));
    jsFile.writeAsStringSync(_wasmInvokeScript);

    await _runProc(Stage.run, 'node', [jsFile.path]);
  }

  Future<void> _jit() async {
    await _runProc(Stage.run, Platform.executable, [_target]);
  }

  Future<void> _runProc(
      Stage headerMessage, String executable, List<String> args) async {
    print('''
\n${_currentFlavor.name.toUpperCase()} - ${headerMessage.name.toUpperCase()}
$executable ${args.join(' ')}
''');

    final proc = await Process.start(executable, args,
        mode: ProcessStartMode.inheritStdio);

    final exitCode = await proc.exitCode;

    if (exitCode != 0) {
      throw ProcessException(executable, args, 'Process errored', exitCode);
    }
  }

  String _outputFile(String ext) {
    return _tempDirectory.uri.resolve('$_outputFileRoot.$ext').toFilePath();
  }

  static const _outputFileRoot = 'out';

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
