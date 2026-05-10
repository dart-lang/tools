// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'bench_options.dart';

/// Returns true if [path] contains a `benchmarks` declaration.
bool hasBenchmarksDeclaration(String path) {
  final file = File(path);
  if (!file.existsSync()) return false;
  final content = file.readAsStringSync();
  return RegExp(r'\bbenchmarks\b').hasMatch(content);
}

/// Generates the wrapper Dart script content to execute modern benchmarks.
String generateWrapperContent(String targetPath) {
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

/// Parses the standard legacy plain-text benchmark output.
Map<String, dynamic>? parseLegacyOutput(String output, RuntimeFlavor flavor) {
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

/// Resolves the active package configuration path if available.
String? resolvePackageConfig() {
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
