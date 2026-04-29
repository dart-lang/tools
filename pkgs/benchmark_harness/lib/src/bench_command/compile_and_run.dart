// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
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

  final allResults = <RuntimeFlavor, Map<String, dynamic>>{};

  for (var mode in options.flavor) {
    try {
      final runner = _Runner(
        flavor: mode,
        target: options.target,
        options: options,
      );
      final result = await runner.run();
      if (result != null) {
        allResults[mode] = result;
      }
    } catch (e) {
      print(
        '\nWarning: Failed to run benchmark for ${mode.name.toUpperCase()}:',
      );
      print(e);
      if (options.verbose) {
        // Already printed in some cases, but ensures visibility
      }
    }
  }

  if (options.json && allResults.isNotEmpty) {
    _printComparisonTable(allResults);
  }
}

void _printComparisonTable(
  Map<RuntimeFlavor, Map<String, dynamic>> allResults,
) {
  // Find all variant names
  final variants = <String>{};
  for (final platformResults in allResults.values) {
    variants.addAll(platformResults.keys);
  }

  final sortedVariants = variants.toList()..sort();
  final platforms = allResults.keys.toList();

  print('\n### Cross-Platform Comparison (Median us/op)\n');

  // Header
  final header = ['Variant', ...platforms.map((p) => p.name.toUpperCase())];
  print('| ${header.join(' | ')} |');
  print('| ${header.map((_) => '---').join(' | ')} |');

  // Rows
  for (final variant in sortedVariants) {
    final row = [variant];
    for (final platform in platforms) {
      final platformData = allResults[platform];
      final variantData = platformData?[variant];
      final value = variantData is Map ? variantData['median'] : null;
      row.add(value is num ? value.toStringAsFixed(2) : '-');
    }
    print('| ${row.join(' | ')} |');
  }
  print('');
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
  _Runner._({required this.target, required this.flavor, required this.options})
    : assert(FileSystemEntity.isFileSync(target), '$target is not a file');

  factory _Runner({
    required RuntimeFlavor flavor,
    required String target,
    required BenchOptions options,
  }) {
    return (switch (flavor) {
      RuntimeFlavor.jit => _JITRunner.new,
      RuntimeFlavor.aot => _AOTRunner.new,
      RuntimeFlavor.js => _JSRunner.new,
      RuntimeFlavor.wasm => _WasmRunner.new,
    })(target: target, options: options);
  }

  final String target;
  final RuntimeFlavor flavor;
  final BenchOptions options;
  late Directory _tempDirectory;

  /// Executes the compile and run cycle.
  ///
  /// Takes care of creating and deleting the corresponding temp directory.
  Future<Map<String, dynamic>?> run() async {
    _tempDirectory = Directory.systemTemp.createTempSync(
      'bench_${DateTime.now().millisecondsSinceEpoch}_',
    );
    try {
      return await _runImpl();
    } finally {
      _tempDirectory.deleteSync(recursive: true);
    }
  }

  /// Overridden in implementations to handle the compile and run cycle.
  Future<Map<String, dynamic>?> _runImpl();

  /// Executes the specific [executable] with the provided [args].
  Future<String?> _runProc(
    _Stage stage,
    String executable,
    List<String> args,
  ) async {
    if (!options.json || stage == _Stage.compile) {
      print('''
\n${flavor.name.toUpperCase()} - ${stage.name.toUpperCase()}
$executable ${args.join(' ')}
''');
    }

    if (options.json && stage == _Stage.run) {
      final res = await Process.run(executable, args);
      if (res.exitCode != 0) {
        throw ProcessException(
          executable,
          args,
          res.stderr as String,
          res.exitCode,
        );
      }
      return res.stdout as String;
    } else {
      final proc = await Process.start(
        executable,
        args,
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await proc.exitCode;

      if (exitCode != 0) {
        throw ProcessException(executable, args, 'Process errored', exitCode);
      }
      return null;
    }
  }

  String _outputFile(String ext) =>
      _tempDirectory.uri.resolve('$_outputFileRoot.$ext').toFilePath();
}

class _JITRunner extends _Runner {
  _JITRunner({required super.target, required super.options})
    : super._(flavor: RuntimeFlavor.jit);

  @override
  Future<Map<String, dynamic>?> _runImpl() async {
    final args = [target];
    if (options.json) {
      args.add('--json');
      args.add('-Djson=true');
    }
    final output = await _runProc(_Stage.run, Platform.executable, args);
    if (output != null) {
      try {
        return jsonDecode(output) as Map<String, dynamic>;
      } catch (e) {
        throw FormatException('Failed to decode JIT JSON: "$output"');
      }
    }
    return null;
  }
}

class _AOTRunner extends _Runner {
  _AOTRunner({required super.target, required super.options})
    : super._(flavor: RuntimeFlavor.aot);

  @override
  Future<Map<String, dynamic>?> _runImpl() async {
    final outFile = _outputFile('exe');
    final compileArgs = ['compile', 'exe', target, '-o', outFile];
    if (options.json) compileArgs.add('-Djson=true');

    await _runProc(_Stage.compile, Platform.executable, compileArgs);

    final args = <String>[];
    if (options.json) args.add('--json');
    final output = await _runProc(_Stage.run, outFile, args);
    if (output != null) {
      try {
        return jsonDecode(output) as Map<String, dynamic>;
      } catch (e) {
        throw FormatException('Failed to decode AOT JSON: "$output"');
      }
    }
    return null;
  }
}

class _JSRunner extends _Runner {
  _JSRunner({required super.target, required super.options})
    : super._(flavor: RuntimeFlavor.js);

  @override
  Future<Map<String, dynamic>?> _runImpl() async {
    final outFile = _outputFile('js');
    final compileArgs = ['compile', 'js', target, '-O4', '-o', outFile];
    if (options.json) compileArgs.add('-Djson=true');

    await _runProc(_Stage.compile, Platform.executable, compileArgs);

    final wrapperFile = File(_outputFile('wrapper.js'));
    wrapperFile.writeAsStringSync(_jsWrapperScript);

    final args = [wrapperFile.path];
    if (options.json) args.add('--json');
    final output = await _runProc(_Stage.run, 'node', args);
    if (output != null) {
      try {
        return jsonDecode(output) as Map<String, dynamic>;
      } catch (e) {
        throw FormatException('Failed to decode JS JSON: "$output"');
      }
    }
    return null;
  }

  static const _jsWrapperScript =
      '''
if (typeof global !== 'undefined' && typeof self === 'undefined') {
  global.self = global;
}
require('./$_outputFileRoot.js');
''';
}

class _WasmRunner extends _Runner {
  _WasmRunner({required super.target, required super.options})
    : super._(flavor: RuntimeFlavor.wasm);

  @override
  Future<Map<String, dynamic>?> _runImpl() async {
    final outFile = _outputFile('wasm');
    final compileArgs = ['compile', 'wasm', target, '-o', outFile];
    if (options.json) compileArgs.add('-Djson=true');

    await _runProc(_Stage.compile, Platform.executable, compileArgs);

    final jsFile = File.fromUri(
      _tempDirectory.uri.resolve('$_outputFileRoot.mjs'),
    );
    // Use a custom invoker that works with the generated .mjs and Node.js
    final invokerFile = File(_outputFile('invoker.mjs'));
    invokerFile.writeAsStringSync(_wasmInvokeScript);

    final args = [
      '--experimental-wasm-stringref',
      '--experimental-wasm-imported-strings',
      invokerFile.path,
    ];
    if (options.json) args.add('--json');
    final output = await _runProc(_Stage.run, 'node', args);
    if (output != null) {
      try {
        return jsonDecode(output) as Map<String, dynamic>;
      } catch (e) {
        throw FormatException('Failed to decode WASM JSON: "$output"');
      }
    }
    return null;
  }

  static const _wasmInvokeScript =
      '''
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { performance } from 'node:perf_hooks';

// Ensure performance is global
if (typeof globalThis.performance === 'undefined') {
  globalThis.performance = performance;
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const wasmFilePath = join(__dirname, '$_outputFileRoot.wasm');
const wasmBytes = await readFile(wasmFilePath);

const mjsFilePath = join(__dirname, '$_outputFileRoot.mjs');
const dartModule = await import(mjsFilePath);

try {
  const compiledApp = await dartModule.compile(wasmBytes);
  const instantiatedApp = await compiledApp.instantiate({});
  
  // Pass arguments to the app
  const args = process.argv.slice(2);
  await instantiatedApp.invokeMain(args);
} catch (e) {
  console.error('WASM Execution Error:', e);
  process.exit(1);
}
''';
}
