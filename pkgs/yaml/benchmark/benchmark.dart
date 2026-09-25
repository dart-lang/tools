// Copyright (c) 2015, the Dart project authors.
// Copyright (c) 2006, Kirill Simonov.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const numTrials = 50;
const runsPerTrial = 500;

final source = _loadFile('input.yaml');
final commentedSource = source
    .split('\n')
    .map((line) => line.contains(':') && !line.endsWith('"So does this')
        ? '$line # comment'
        : line)
    .join('\n');
final expected = _loadFile('output.json');

void main(List<String> args) {
  var bestLoadYaml = double.infinity;

  // Run the benchmark several times. This ensures the VM is warmed up and lets
  // us see how much variance there is.
  for (var i = 0; i <= numTrials; i++) {
    var start = DateTime.now();

    // For a single benchmark, convert the source multiple times.
    Object? result;
    for (var j = 0; j < runsPerTrial; j++) {
      result = loadYaml(source);
    }

    var elapsed =
        DateTime.now().difference(start).inMicroseconds / runsPerTrial / 1000;

    // Keep track of the best run so far.
    if (elapsed >= bestLoadYaml) continue;
    bestLoadYaml = elapsed;

    // Sanity check to make sure the output is what we expect and to make sure
    // the VM doesn't optimize "dead" code away.
    if (jsonEncode(result) != expected) {
      print('Incorrect output:\n${jsonEncode(result)}');
      exit(1);
    }

    // Don't print the first run. It's always terrible since the VM hasn't
    // warmed up yet.
    if (i == 0) continue;
    _printResult("Run ${'#$i'.padLeft(3, '')}", elapsed);
  }

  _printResult('Best (loadYaml)                       ', bestLoadYaml);

  final bestRetainFalse = _benchmarkDocument(
    commentedSource,
    retainTokens: false,
  );
  final bestRetainTrue = _benchmarkDocument(
    commentedSource,
    retainTokens: true,
  );

  _printResult('Best (loadYamlDocument, retain: false)', bestRetainFalse);
  _printResult('Best (loadYamlDocument, retain: true) ', bestRetainTrue);
}

double _benchmarkDocument(String input, {required bool retainTokens}) {
  var best = double.infinity;
  for (var i = 0; i <= numTrials; i++) {
    final stopwatch = Stopwatch()..start();
    YamlDocument? document;
    for (var j = 0; j < runsPerTrial; j++) {
      document = loadYamlDocument(input, retainTokens: retainTokens);
    }
    stopwatch.stop();
    if (document == null || (retainTokens && document.tokens == null)) {
      stderr.writeln('Unexpected document result.');
      exit(1);
    }
    if (i == 0) continue;
    final elapsed = stopwatch.elapsedMicroseconds / runsPerTrial / 1000;
    if (elapsed < best) best = elapsed;
  }
  return best;
}

String _loadFile(String name) {
  var path = p.join(p.dirname(p.fromUri(Platform.script)), name);
  return File(path).readAsStringSync();
}

void _printResult(String label, double time) {
  print('$label: ${time.toStringAsFixed(3).padLeft(4, '0')}ms '
      "${'=' * ((time * 100).toInt())}");
}
