// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

// TODO: cleanup temp directories
// TODO: allow flags
// TODO: default flags for JS and Wasm ?

Future<void> main(List<String> args) async {
  final modeVal = args[0];
  final target = args[1];

  final modes = modeVal.split(',').toSet();

  for (var mode in modes) {
    final func = _benches[mode];

    if (func == null) {
      throw UnimplementedError(
        'Unsupported mode: "$mode". Allowed: ${_benches.keys.join(', ')}',
      );
    }

    await func(target);
  }
}

const _benches = {
  'aot': _aot,
  'jit': _jit,
  'js': _js,
  'wasm': _wasm,
};

Future<void> _aot(String target) async {
  final outFile = _outputFile('exe');
  await _runProc(Platform.executable, [
    'compile',
    'exe',
    target,
    '-o',
    outFile,
  ]);

  await _runProc(outFile, []);
}

Future<void> _js(String target) async {
  final outFile = _outputFile('js');
  await _runProc(Platform.executable, [
    'compile',
    'js',
    target,
    '-o',
    outFile,
  ]);

  await _runProc('node', [outFile]);
}

Future<void> _wasm(String target) async {
  final tempDirectory = _tempDirectory();
  final outFile = _outputFile('wasm', dir: tempDirectory);
  await _runProc(Platform.executable, [
    'compile',
    'wasm',
    target,
    '-o',
    outFile,
  ]);

  final jsFile = File.fromUri(tempDirectory.uri.resolve('$_outputFileRoot.js'));
  jsFile.writeAsStringSync(_wasmInvokeScript);

  await _runProc('node', [jsFile.path]);
}

Future<void> _jit(String target) async {
  await _runProc(Platform.executable, [target]);
}

Directory _tempDirectory() => Directory.systemTemp
    .createTempSync('bench_${DateTime.now().millisecondsSinceEpoch}_');

String _outputFile(String ext, {Directory? dir}) {
  dir ??= _tempDirectory();
  return dir.uri.resolve('$_outputFileRoot.$ext').toFilePath();
}

Future<void> _runProc(String executable, List<String> args) async {
  final proc = await Process.start(executable, args,
      mode: ProcessStartMode.inheritStdio);

  final exitCode = await proc.exitCode;

  if (exitCode != 0) {
    throw ProcessException(executable, args, 'Process errored', exitCode);
  }
}

const _outputFileRoot = 'out';

const _wasmInvokeScript = '''
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
