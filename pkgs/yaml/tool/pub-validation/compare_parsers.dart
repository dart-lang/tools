// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:pool/pool.dart';

Future<void> main(List<String> args) async {
  int? maxPackages;
  for (final arg in args) {
    if (arg.startsWith('--max-packages=')) {
      maxPackages = int.parse(arg.split('=')[1]);
    }
  }

  // 1. Verify git is clean
  final gitStatus = await Process.run('git', ['status', '--porcelain']);
  // We allow untracked files in tool/ or .dart_tool/ but let's just allow uncommitted changes if they are only to tool/
  // Actually, to make it robust, we can just say "commit your changes before running".
  // But wait, the user said: "should we require clean git... what is a good default". Let's require it.
  if (gitStatus.stdout.toString().trim().isNotEmpty) {
    bool onlyTools = true;
    for (var line in gitStatus.stdout.toString().trim().split('\n')) {
      if (!line.contains('tool/')) {
        onlyTools = false;
        break;
      }
    }
    if (!onlyTools) {
      print('Please commit or stash your changes before running this script.');
      print(gitStatus.stdout);
      exit(1);
    }
  }

  final currentBranchResult = await Process.run('git', [
    'rev-parse',
    '--abbrev-ref',
    'HEAD',
  ]);
  final currentBranch = currentBranchResult.stdout.toString().trim();

  // 2. Setup paths
  final dataDir = Directory('.dart_tool/yaml/pub-dev-yaml-files');
  if (!dataDir.existsSync()) {
    print('Data directory not found. Run fetch_yamls_from_pub_dev.dart first.');
    exit(1);
  }

  final outDir = Directory('.dart_tool/yaml');
  final binNew = File('${outDir.path}/_jsonl_bulk_parser_new');
  final binOld = File('${outDir.path}/_jsonl_bulk_parser_old');
  final compareDir = Directory('${outDir.path}/comparison');

  if (compareDir.existsSync()) {
    compareDir.deleteSync(recursive: true);
  }
  compareDir.createSync(recursive: true);

  // Copy the parser script so it survives git checkout
  final tempParser = File('tool/pub-validation/_temp_parser.dart');
  File('tool/pub-validation/_jsonl_bulk_parser.dart').copySync(tempParser.path);

  try {
    print('Compiling parser for current branch ($currentBranch)...');
    final compileNew = await Process.run(Platform.executable, [
      'compile',
      'exe',
      tempParser.path,
      '-o',
      binNew.path,
    ]);
    if (compileNew.exitCode != 0) {
      print('Compilation failed:\n${compileNew.stdout}\n${compileNew.stderr}');
      exit(1);
    }

    print('Checking out main...');
    await Process.run('git', ['checkout', 'main']);

    print('Compiling parser for main branch...');
    final compileOld = await Process.run(Platform.executable, [
      'compile',
      'exe',
      tempParser.path,
      '-o',
      binOld.path,
    ]);
    if (compileOld.exitCode != 0) {
      print('Compilation failed:\n${compileOld.stdout}\n${compileOld.stderr}');
      // Restore branch before exiting
      await Process.run('git', ['checkout', currentBranch]);
      exit(1);
    }
  } finally {
    print('Restoring original branch ($currentBranch)...');
    await Process.run('git', ['checkout', currentBranch]);
    if (tempParser.existsSync()) {
      tempParser.deleteSync();
    }
  }

  print('Compilation successful. Beginning comparison.');

  final files = dataDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.jsonl.gz'))
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));

  final filesToProcess = maxPackages != null
      ? files.take(maxPackages).toList()
      : files;

  int totalChecks = 0;
  int differences = 0;
  int newExceptions = 0;
  int resolvedExceptions = 0;
  int jsonDiffers = 0;

  int processedCount = 0;
  final numProcessors = Platform.numberOfProcessors;

  print(
    'Processing ${filesToProcess.length} packages with $numProcessors concurrent workers...',
  );

  // Process files concurrently using a Pool
  final pool = Pool(numProcessors);

  var lastPrint = DateTime.now();

  await Future.wait(
    filesToProcess.map((file) {
      final filePath = file.path;
      final binOldPath = binOld.path;
      final binNewPath = binNew.path;
      final compareDirPath = compareDir.path;

      return pool.withResource(() async {
        final result = await _runIsolateFor(
          filePath,
          binOldPath,
          binNewPath,
          compareDirPath,
        );

        totalChecks += result.checks;
        differences += result.diffs;
        newExceptions += result.newEx;
        resolvedExceptions += result.resEx;
        jsonDiffers += result.jsonDiffs;

        processedCount++;
        final now = DateTime.now();
        if (now.difference(lastPrint).inMinutes >= 1 ||
            processedCount == filesToProcess.length) {
          print(
            'Processed $processedCount / ${filesToProcess.length} (${(processedCount / filesToProcess.length * 100).toStringAsFixed(1)}%)',
          );
          lastPrint = now;
        }
      });
    }),
  );

  print('\n--- Comparison Report ---');
  print('Total YAML files checked: $totalChecks');
  print('Total differences found: $differences');
  print('New exceptions (did not fail before, fails now): $newExceptions');
  print('Resolved exceptions (failed before, passes now): $resolvedExceptions');
  print('Cases where parsed JSON differs: $jsonDiffers');
  print('-------------------------');
}

typedef DiffResult = ({
  int checks,
  int diffs,
  int newEx,
  int resEx,
  int jsonDiffs,
});

Future<DiffResult> _runIsolateFor(
  String filePath,
  String binOldPath,
  String binNewPath,
  String compareDirPath,
) {
  return Isolate.run(
    () => processFileInIsolate([
      filePath,
      binOldPath,
      binNewPath,
      compareDirPath,
    ]),
  );
}

Future<DiffResult> processFileInIsolate(List<String> args) async {
  final filePath = args[0];
  final binOldPath = args[1];
  final binNewPath = args[2];
  final compareDirPath = args[3];

  final oldProc = await Process.run(binOldPath, [filePath]);
  final newProc = await Process.run(binNewPath, [filePath]);

  if (oldProc.stderr.toString().isNotEmpty) {
    stderr.write('[OLD $filePath] ${oldProc.stderr}');
  }
  if (newProc.stderr.toString().isNotEmpty) {
    stderr.write('[NEW $filePath] ${newProc.stderr}');
  }

  final oldLines = oldProc.stdout.toString().split('\n');
  final newLines = newProc.stdout.toString().split('\n');

  int checks = 0;
  int diffs = 0;
  int newExCount = 0;
  int resExCount = 0;
  int jsonDiffs = 0;

  bool hasDiff = false;
  List<String> diffOutput = [];

  final minLength = oldLines.length < newLines.length
      ? oldLines.length
      : newLines.length;

  for (int i = 0; i < minLength; i++) {
    final oldLine = oldLines[i].trim();
    final newLine = newLines[i].trim();

    if (oldLine.isEmpty || newLine.isEmpty) continue;

    checks++;

    // Fast path: if the JSON lines are identical, they are the same!
    if (oldLine == newLine) {
      continue;
    }

    final oldData = jsonDecode(oldLine);
    final newData = jsonDecode(newLine);

    final oldEx = oldData['exception'];
    final newEx = newData['exception'];
    final oldJson = jsonEncode(oldData['json']);
    final newJson = jsonEncode(newData['json']);

    bool lineDiffers = false;

    if (oldEx != newEx) {
      lineDiffers = true;
      if (oldEx == null && newEx != null) {
        newExCount++;
      } else if (oldEx != null && newEx == null) {
        resExCount++;
      }
    }

    if (oldJson != newJson) {
      lineDiffers = true;
      jsonDiffs++;
    }

    if (lineDiffers) {
      hasDiff = true;
      diffs++;
      diffOutput.add(
        jsonEncode({
          'file': oldData['file'],
          'yaml': oldData['yaml'],
          'old_exception': oldEx,
          'new_exception': newEx,
          'old_json': oldData['json'],
          'new_json': newData['json'],
        }),
      );
    }
  }

  if (hasDiff) {
    final package = Uri.file(
      filePath,
    ).pathSegments.last.replaceAll('.jsonl.gz', '');
    final diffFile = File('$compareDirPath/$package.jsonl.gz');
    final sink = diffFile.openWrite();
    final gzipSink = gzip.encoder.startChunkedConversion(sink);
    for (final diffLine in diffOutput) {
      gzipSink.add(utf8.encode('$diffLine\n'));
    }
    gzipSink.close();
  }

  return (
    checks: checks,
    diffs: diffs,
    newEx: newExCount,
    resEx: resExCount,
    jsonDiffs: jsonDiffs,
  );
}
