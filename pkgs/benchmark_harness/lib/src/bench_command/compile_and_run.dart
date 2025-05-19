// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'bench_options.dart';

// TODO: allow flags

enum _Stage { compile, run }

Future<void> compileAndRun(BenchOptions options) async {
  for (var mode in options.flavor) {
    await _runner(mode)(target: options.target).run();
  }
}

class BenchException implements Exception {
  const BenchException(this.message, this.exitCode) : assert(exitCode > 0);
  final String message;
  final int exitCode;

  @override
  String toString() => 'BenchException: $message ($exitCode)';
}

_Runner Function({required String target}) _runner(RuntimeFlavor flavor) =>
    switch (flavor) {
      RuntimeFlavor.jit => _JITRunner.new,
      RuntimeFlavor.aot => _AOTRunner.new,
      RuntimeFlavor.js => _JSRunner.new,
      RuntimeFlavor.wasm => _WasmRunner.new,
    };

abstract class _Runner {
  _Runner({required this.target, required this.flavor}) {
    if (!FileSystemEntity.isFileSync(target)) {
      throw BenchException(
        'The target Dart program `$target` does not exist',
        2, // standard bash code for file doesn't exist
      );
    }
  }

  final String target;
  final RuntimeFlavor flavor;
  late Directory _tempDirectory;

  Future<void> run() async {
    _tempDirectory = Directory.systemTemp
        .createTempSync('bench_${DateTime.now().millisecondsSinceEpoch}_');
    try {
      await _runImpl();
    } finally {
      _tempDirectory.deleteSync(recursive: true);
    }
  }

  Future<void> _runImpl();

  Future<void> _runProc(
      _Stage headerMessage, String executable, List<String> args) async {
    print('''
\n${flavor.name.toUpperCase()} - ${headerMessage.name.toUpperCase()}
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
}

class _JITRunner extends _Runner {
  _JITRunner({required super.target}) : super(flavor: RuntimeFlavor.jit);

  @override
  Future<void> _runImpl() async {
    await _runProc(_Stage.run, Platform.executable, [target]);
  }
}

class _AOTRunner extends _Runner {
  _AOTRunner({required super.target}) : super(flavor: RuntimeFlavor.aot);

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
  _JSRunner({required super.target}) : super(flavor: RuntimeFlavor.js);

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
  _WasmRunner({required super.target}) : super(flavor: RuntimeFlavor.wasm);

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

    final jsFile = File.fromUri(
        _tempDirectory.uri.resolve('${_Runner._outputFileRoot}.js'));
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

const wasmFilePath = join(__dirname, '${_Runner._outputFileRoot}.wasm');
const wasmBytes = await readFile(wasmFilePath);

const mjsFilePath = join(__dirname, '${_Runner._outputFileRoot}.mjs');
const dartModule = await import(mjsFilePath);
const {compile} = dartModule;

const compiledApp = await compile(wasmBytes);
const instantiatedApp = await compiledApp.instantiate({});
await instantiatedApp.invokeMain();
''';
}
