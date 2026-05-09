// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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
  final failures = <RuntimeFlavor, Object>{};

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
      failures[mode] = e;
    }
  }

  if (options.json && allResults.isNotEmpty) {
    final encodableResults = allResults.map(
      (key, value) => MapEntry(key.name, value),
    );
    print(const JsonEncoder.withIndent('  ').convert(encodableResults));
  }

  var foundUnstable = false;
  String? unstableMessage;

  for (final platform in allResults.keys) {
    final platformData = allResults[platform]!;
    for (final variant in platformData.keys) {
      final variantData = platformData[variant];
      if (variantData is Map) {
        final isStable = variantData['metrics'] is Map
            ? (variantData['metrics'] as Map)['isStable']
            : variantData['isStable'];
        if (isStable == false) {
          foundUnstable = true;
          unstableMessage =
              'Benchmark "$variant" on '
              '${platform.name.toUpperCase()} was unstable.';
          break;
        }
      }
    }
    if (foundUnstable) break;
  }

  if (options.failOnUnstable && foundUnstable) {
    throw BenchException('CI Stability Guard: $unstableMessage', 1);
  }

  if (failures.isNotEmpty) {
    throw BenchException(
      'Some benchmark runs failed: '
      '${failures.keys.map((f) => f.name.toUpperCase()).join(", ")}',
      1,
    );
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
  _Runner._({
    required String target,
    required this.flavor,
    required this.options,
  }) : target = File(target).absolute.path,
       assert(
         FileSystemEntity.isFileSync(File(target).absolute.path),
         '$target is not a file',
       );

  factory _Runner({
    required RuntimeFlavor flavor,
    required String target,
    required BenchOptions options,
  }) {
    if (flavor == RuntimeFlavor.jit && options.isolateMode && !options.json) {
      return _IsolateRunner(target: target, options: options);
    }
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
  late String _realTarget;

  /// Executes the compile and run cycle.
  ///
  /// Takes care of creating and deleting the corresponding temp directory.
  Future<Map<String, dynamic>?> run() async {
    _tempDirectory = Directory.systemTemp.createTempSync(
      'bench_${DateTime.now().millisecondsSinceEpoch}_',
    );
    try {
      if (_hasBenchmarksDeclaration(target)) {
        final wrapperFile = File(
          _tempDirectory.uri.resolve('wrapper.dart').toFilePath(),
        );
        wrapperFile.writeAsStringSync(_generateWrapperContent(target));
        _realTarget = wrapperFile.path;
      } else {
        _realTarget = target;
      }
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

  Map<String, dynamic>? _parseResult(String? output) {
    if (output == null) return null;

    // Try decoding the entire output first
    try {
      final decoded = jsonDecode(output);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}

    // Line-by-line JSON extraction fallback
    for (var line in output.split('\n')) {
      line = line.trim();
      if (line.isEmpty || (!line.startsWith('{') && !line.startsWith('['))) {
        continue;
      }
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    final parsed = _parseLegacyOutput(output);
    if (parsed != null && parsed.isNotEmpty) {
      return parsed;
    }

    throw FormatException(
      'Failed to decode ${flavor.name.toUpperCase()} JSON: "$output"',
    );
  }

  Map<String, dynamic>? _parseLegacyOutput(String output) {
    final regex = RegExp(r'^(.+?)\((.+?)\):\s+([\d.]+)\s*(.*)$');
    final results = <String, dynamic>{};
    var linesParsed = 0;
    for (var line in output.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;
      final match = regex.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!;
        final value = double.parse(match.group(3)!);
        results[name] = {
          'name': name,
          'variant': name,
          'platform': flavor.name,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'metrics': {'median_us': value},
        };
        linesParsed++;
      }
    }
    return linesParsed > 0 ? results : null;
  }
}

class _JITRunner extends _Runner {
  _JITRunner({required super.target, required super.options})
    : super._(flavor: RuntimeFlavor.jit);

  @override
  Future<Map<String, dynamic>?> _runImpl() async {
    final args = <String>[];
    final packageConfig = _resolvePackageConfig();
    if (packageConfig != null) {
      args.add('--packages=$packageConfig');
    }
    if (options.json) {
      args.add('-Djson=true');
      args.add('-Dos=${Platform.operatingSystem}');
      args.add('-Ddart_sdk_version=${Platform.version.split(' ').first}');
      args.add('-Dplatform=jit');
    }
    if (options.forceRun) {
      args.add('-Dbenchmark_harness.force_run=true');
    }
    if (options.validate) {
      args.add('-Dbenchmark_harness.validate=true');
    }
    args.addAll(options.compilerFlags);
    args.addAll(options.vmFlags);
    args.add(_realTarget);
    if (options.json && _hasBenchmarksDeclaration(target)) {
      args.add('--json');
    }
    if (options.forceRun) {
      args.add('--force-run');
    }
    final output = await _runProc(_Stage.run, Platform.executable, args);
    return _parseResult(output);
  }
}

class _AOTRunner extends _Runner {
  _AOTRunner({required super.target, required super.options})
    : super._(flavor: RuntimeFlavor.aot);

  @override
  Future<Map<String, dynamic>?> _runImpl() async {
    final outFile = _outputFile('exe');
    final compileArgs = ['compile', 'exe'];
    final packageConfig = _resolvePackageConfig();
    if (packageConfig != null) {
      compileArgs.add('--packages=$packageConfig');
    }
    compileArgs.addAll([_realTarget, '-o', outFile]);
    if (options.json) {
      compileArgs.add('-Djson=true');
      compileArgs.add('-Dos=${Platform.operatingSystem}');
      compileArgs.add(
        '-Ddart_sdk_version=${Platform.version.split(' ').first}',
      );
      compileArgs.add('-Dplatform=aot');
    }
    if (options.forceRun) compileArgs.add('-Dbenchmark_harness.force_run=true');
    if (options.validate) compileArgs.add('-Dbenchmark_harness.validate=true');
    compileArgs.addAll(options.compilerFlags);

    await _runProc(_Stage.compile, Platform.executable, compileArgs);

    final args = <String>[];
    args.addAll(options.vmFlags);
    if (options.json && _hasBenchmarksDeclaration(target)) args.add('--json');
    if (options.forceRun) args.add('--force-run');
    final output = await _runProc(_Stage.run, outFile, args);
    return _parseResult(output);
  }
}

class _JSRunner extends _Runner {
  _JSRunner({required super.target, required super.options})
    : super._(flavor: RuntimeFlavor.js);

  @override
  Future<Map<String, dynamic>?> _runImpl() async {
    final outFile = _outputFile('js');
    final compileArgs = ['compile', 'js'];
    final packageConfig = _resolvePackageConfig();
    if (packageConfig != null) {
      compileArgs.add('--packages=$packageConfig');
    }
    compileArgs.addAll([_realTarget, '-O4', '-o', outFile]);
    if (options.json) {
      compileArgs.add('-Djson=true');
      compileArgs.add('-Dos=${Platform.operatingSystem}');
      compileArgs.add(
        '-Ddart_sdk_version=${Platform.version.split(' ').first}',
      );
      compileArgs.add('-Dplatform=js');
    }
    if (options.forceRun) compileArgs.add('-Dbenchmark_harness.force_run=true');
    if (options.validate) compileArgs.add('-Dbenchmark_harness.validate=true');
    compileArgs.addAll(options.compilerFlags);

    await _runProc(_Stage.compile, Platform.executable, compileArgs);

    final wrapperFile = File(_outputFile('wrapper.js'));
    wrapperFile.writeAsStringSync(_jsWrapperScript);

    final args = [...options.vmFlags, '--enable-source-maps', wrapperFile.path];
    if (options.json && _hasBenchmarksDeclaration(target)) args.add('--json');
    if (options.forceRun) args.add('--force-run');
    final output = await _runProc(_Stage.run, 'node', args);
    return _parseResult(output);
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
    final compileArgs = ['compile', 'wasm'];
    final packageConfig = _resolvePackageConfig();
    if (packageConfig != null) {
      compileArgs.add('--packages=$packageConfig');
    }
    compileArgs.addAll([_realTarget, '-o', outFile]);
    if (options.json) {
      compileArgs.add('-Djson=true');
      compileArgs.add('-Dos=${Platform.operatingSystem}');
      compileArgs.add(
        '-Ddart_sdk_version=${Platform.version.split(' ').first}',
      );
      compileArgs.add('-Dplatform=wasm');
    }
    if (options.forceRun) compileArgs.add('-Dbenchmark_harness.force_run=true');
    if (options.validate) compileArgs.add('-Dbenchmark_harness.validate=true');
    compileArgs.addAll(options.compilerFlags);

    await _runProc(_Stage.compile, Platform.executable, compileArgs);

    // Use a custom invoker that works with the generated .mjs and Node.js
    final invokerFile = File(_outputFile('invoker.mjs'));
    invokerFile.writeAsStringSync(_wasmInvokeScript);

    final args = [
      ...options.vmFlags,
      '--experimental-wasm-stringref',
      '--experimental-wasm-imported-strings',
      '--enable-source-maps',
      invokerFile.path,
    ];
    if (options.json && _hasBenchmarksDeclaration(target)) args.add('--json');
    if (options.forceRun) args.add('--force-run');
    final output = await _runProc(_Stage.run, 'node', args);
    return _parseResult(output);
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

  await instantiatedApp.invokeMain([]);
} catch (e) {
  console.error('WASM Execution Error:', e);
  process.exit(1);
}
''';
}

class _IsolateRunner extends _Runner {
  _IsolateRunner({required super.target, required super.options})
    : super._(flavor: RuntimeFlavor.jit);

  @override
  Future<Map<String, dynamic>?> _runImpl() async {
    final args = <String>[];
    args.addAll(options.vmFlags);
    if (options.json && _hasBenchmarksDeclaration(target)) {
      args.add('-Djson=true');
      args.add('-Dos=${Platform.operatingSystem}');
      args.add('-Ddart_sdk_version=${Platform.version.split(' ').first}');
      args.add('-Dplatform=jit');
    }
    if (options.forceRun) args.add('-Dbenchmark_harness.force_run=true');
    if (options.validate) args.add('-Dbenchmark_harness.validate=true');

    if (!options.json) {
      print('''
\nJIT (ISOLATE) - RUN
$_realTarget ${args.join(' ')}
''');
    }

    final exitPort = ReceivePort();
    final errorPort = ReceivePort();
    var hasError = false;

    final packageConfig = _resolvePackageConfig();
    await Isolate.spawnUri(
      Uri.file(_realTarget),
      args,
      null,
      onExit: exitPort.sendPort,
      onError: errorPort.sendPort,
      packageConfig: packageConfig != null ? Uri.parse(packageConfig) : null,
    );

    errorPort.listen((error) {
      hasError = true;
      if (error is List && error.length >= 2) {
        stderr.writeln('Isolate Error: ${error[0]}');
        stderr.writeln('${error[1]}');
      } else {
        stderr.writeln('Isolate Error: $error');
      }
    });

    await exitPort.first;
    exitPort.close();
    errorPort.close();

    if (hasError) {
      throw const BenchException(
        'Isolate execution failed with an unhandled exception',
        1,
      );
    }
    return null;
  }
}

bool _hasBenchmarksDeclaration(String path) {
  final file = File(path);
  if (!file.existsSync()) return false;
  final content = file.readAsStringSync();
  final regex = RegExp(r'\bbenchmarks\b');
  return regex.hasMatch(content);
}

String _generateWrapperContent(String targetPath) {
  final absolutePath = File(targetPath).absolute.path;
  final fileUri = Uri.file(absolutePath).toString();
  return '''
import 'package:benchmark_harness/benchmark_harness.dart';
import '$fileUri' as user_target;

void main() async {
  const isJson = bool.fromEnvironment('json');
  if (isJson) {
    final emitter = JsonEmitter();
    for (final benchmark in user_target.benchmarks) {
      await benchmark.report(emitter: emitter);
    }
    print(emitter.toString());
  } else {
    for (final benchmark in user_target.benchmarks) {
      final results = await benchmark.run();
      print(BenchmarkReport.formatTable(results));
    }
  }
}
''';
}

String? _resolvePackageConfig() {
  if (Platform.packageConfig != null) {
    try {
      return Uri.parse(Platform.packageConfig!).toFilePath();
    } catch (_) {}
  }
  final local = File('.dart_tool/package_config.json').absolute;
  if (local.existsSync()) {
    return local.path;
  }
  return null;
}
