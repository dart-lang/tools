import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:pool/pool.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('max-packages',
        help: 'Maximum number of packages to process', valueHelp: 'N');

  final parsedArgs = parser.parse(args);
  final maxPackagesStr = parsedArgs['max-packages'] as String?;
  final maxPackages = maxPackagesStr != null ? int.parse(maxPackagesStr) : null;

  // 1. Verify git is clean
  final gitStatus = await Process.run('git', ['status', '--porcelain']);
  if (gitStatus.stdout.toString().trim().isNotEmpty) {
    print('Please commit or stash your changes before running this script.');
    print(gitStatus.stdout);
    exit(1);
  }

  final currentBranchResult =
      await Process.run('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
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
  final tempParser = File('.dart_tool/yaml/_jsonl_bulk_parser.dart');
  File('tool/pub-validation/_jsonl_bulk_parser.dart').copySync(tempParser.path);

  try {
    print('Compiling parser for current branch ($currentBranch)...');
    final compileNew = await Process.run(Platform.executable,
        ['compile', 'exe', tempParser.path, '-o', binNew.path]);
    if (compileNew.exitCode != 0) {
      throw StateError(
          'Compilation failed:\n${compileNew.stdout}\n${compileNew.stderr}');
    }

    print('Checking out main...');
    final checkoutMain = await Process.run('git', ['checkout', 'main']);
    if (checkoutMain.exitCode != 0) {
      throw StateError(
          'Failed to checkout main branch:\n${checkoutMain.stderr}');
    }

    print('Compiling parser for main branch...');
    final compileOld = await Process.run(Platform.executable,
        ['compile', 'exe', tempParser.path, '-o', binOld.path]);
    if (compileOld.exitCode != 0) {
      throw StateError(
          'Compilation failed:\n${compileOld.stdout}\n${compileOld.stderr}');
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

  final filesToProcess =
      maxPackages != null ? files.take(maxPackages).toList() : files;

  int totalChecks = 0;
  int differences = 0;
  int newExceptions = 0;
  int resolvedExceptions = 0;
  int jsonDiffers = 0;

  int processedCount = 0;
  print(
      'Processing ${filesToProcess.length} packages with ${Platform.numberOfProcessors} concurrent workers...');

  // Process files concurrently using a Pool
  final pool = Pool(Platform.numberOfProcessors);

  var lastPrint = DateTime.now();

  await Future.wait(filesToProcess.map((file) {
    return pool.withResource(() async {
      final result = await _runIsolateFor(
        filePath: file.path,
        binOldPath: binOld.path,
        binNewPath: binNew.path,
        compareDirPath: compareDir.path,
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
            'Processed $processedCount / ${filesToProcess.length} (${(processedCount / filesToProcess.length * 100).toStringAsFixed(1)}%)');
        lastPrint = now;
      }
    });
  }));

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
  int jsonDiffs
});

Future<DiffResult> _runIsolateFor({
  required String filePath,
  required String binOldPath,
  required String binNewPath,
  required String compareDirPath,
}) {
  return Isolate.run(() => processFileInIsolate(
        filePath: filePath,
        binOldPath: binOldPath,
        binNewPath: binNewPath,
        compareDirPath: compareDirPath,
      ));
}

Future<DiffResult> processFileInIsolate({
  required String filePath,
  required String binOldPath,
  required String binNewPath,
  required String compareDirPath,
}) async {
  final results = await Future.wait([
    Process.run(binOldPath, [filePath]),
    Process.run(binNewPath, [filePath]),
  ]);
  final oldProc = results[0];
  final newProc = results[1];

  if (oldProc.stderr.toString().isNotEmpty) {
    stderr.write('[OLD $filePath] ${oldProc.stderr}');
  }
  if (newProc.stderr.toString().isNotEmpty) {
    stderr.write('[NEW $filePath] ${newProc.stderr}');
  }

  if (oldProc.exitCode != 0 || newProc.exitCode != 0) {
    stderr.writeln(
        'Process crashed on $filePath: old=${oldProc.exitCode} new=${newProc.exitCode}');
    final package =
        Uri.file(filePath).pathSegments.last.replaceAll('.jsonl.gz', '');
    final diffFile = File('$compareDirPath/$package.jsonl.gz');
    final sink = diffFile.openWrite();
    final gzipSink = gzip.encoder.startChunkedConversion(sink);
    gzipSink.add(utf8.encode(jsonEncode({
          'file': filePath,
          'error': 'Process crashed',
          'old_exit_code': oldProc.exitCode,
          'new_exit_code': newProc.exitCode,
          'old_stderr': oldProc.stderr.toString(),
          'new_stderr': newProc.stderr.toString(),
        }) +
        '\n'));
    gzipSink.close();
    await sink.done;

    return (
      checks: 0,
      diffs: 1,
      newEx: oldProc.exitCode == 0 && newProc.exitCode != 0 ? 1 : 0,
      resEx: oldProc.exitCode != 0 && newProc.exitCode == 0 ? 1 : 0,
      jsonDiffs: 0,
    );
  }

  final oldLines = oldProc.stdout
      .toString()
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final newLines = newProc.stdout
      .toString()
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  int checks = 0;
  int diffs = 0;
  int newExCount = 0;
  int resExCount = 0;
  int jsonDiffs = 0;

  List<String> diffOutput = [];

  if (oldLines.length != newLines.length) {
    stderr.writeln(
        'Line count mismatch on $filePath: old=${oldLines.length} new=${newLines.length}');
    diffs++;
    diffOutput.add(jsonEncode({
      'error': 'Line count mismatch',
      'old_count': oldLines.length,
      'new_count': newLines.length,
    }));
  }

  final minLength =
      oldLines.length < newLines.length ? oldLines.length : newLines.length;

  for (int i = 0; i < minLength; i++) {
    final oldLine = oldLines[i];
    final newLine = newLines[i];

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
      diffs++;

      String? jsonDiffStr;
      if (oldJson != newJson) {
        final encoder = const JsonEncoder.withIndent('  ');
        final oldPretty = encoder.convert(oldData['json']);
        final newPretty = encoder.convert(newData['json']);

        final tempDir = Directory.systemTemp.createTempSync('yaml_diff_');
        final oldFile = File('${tempDir.path}/old.json')
          ..writeAsStringSync(oldPretty);
        final newFile = File('${tempDir.path}/new.json')
          ..writeAsStringSync(newPretty);

        final diffProc = await Process.run('diff',
            ['-y', '--color=always', '-W', '180', oldFile.path, newFile.path]);
        jsonDiffStr =
            '${oldData['package']}-${oldData['version']}.tar.gz ${oldData['file']}\n'
            '${diffProc.stdout}\n'
            '---------';

        tempDir.deleteSync(recursive: true);
      }

      diffOutput.add(jsonEncode({
        'package': oldData['package'],
        'version': oldData['version'],
        'file': oldData['file'],
        'yaml': oldData['yaml'],
        'old_exception': oldEx,
        'new_exception': newEx,
        'old_json': oldData['json'],
        'new_json': newData['json'],
        if (jsonDiffStr != null) 'json_diff': jsonDiffStr,
      }));
    }
  }

  if (diffOutput.isNotEmpty) {
    final package =
        Uri.file(filePath).pathSegments.last.replaceAll('.jsonl.gz', '');
    final diffFile = File('$compareDirPath/$package.jsonl.gz');
    final sink = diffFile.openWrite();
    final gzipSink = gzip.encoder.startChunkedConversion(sink);
    for (final diffLine in diffOutput) {
      gzipSink.add(utf8.encode('$diffLine\n'));
    }
    gzipSink.close();
    await sink.done;
  }

  return (
    checks: checks,
    diffs: diffs,
    newEx: newExCount,
    resEx: resExCount,
    jsonDiffs: jsonDiffs,
  );
}
