// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:watcher/watcher.dart';

import '../utils.dart';

void endToEndTests({required bool isNative}) {
  test('end to end test', timeout: const Timeout(Duration(minutes: 5)),
      () async {
    final temp = Directory.systemTemp.createTempSync();
    final watcher = createWatcher(path: temp.path);
    final random = Random(0);

    await Isolate.run(() =>
        randomFileOperations(path: temp.path, operations: 100, random: random));

    final client = await TestWatcherClient.watch(watcher);

    for (var i = 0; i != 50; ++i) {
      print('run $i');
      await Isolate.run(() => randomFileOperations(
          path: temp.path, operations: 100, random: random));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(client.trackedFileLengths, client.actualFileLengths());
    }
  });
}

Future<void> randomFileOperations(
    {required String path,
    required int operations,
    required Random random}) async {
  for (var i = 0; i != operations; ++i) {
    await randomFileOperation(path: path, random: random);
  }
}

Future<void> randomFileOperation(
    {required String path, required Random random}) async {
  String randomContent() => ' ' * random.nextInt(1000);

  String randomDirectoryPath() {
    var result = path;
    final subdirectoryDepth = random.nextInt(3);
    for (var i = 0; i != subdirectoryDepth; ++i) {
      result = p.join(result, String.fromCharCode(97 + random.nextInt(10)));
    }
    return result;
  }

  String randomFilePath() {
    return p.join(randomDirectoryPath(), random.nextInt(100000).toString());
  }

  String? randomExistingFilePath() =>
      (Directory(path).listSync(recursive: true).whereType<File>().toList()
            ..shuffle(random))
          .firstOrNull
          ?.path;

  String? randomExistingDirectoryPath() =>
      (Directory(path).listSync(recursive: true).whereType<Directory>().toList()
            ..shuffle(random))
          .firstOrNull
          ?.path;

  void ensureParent(String path) {
    final directory = Directory(p.dirname(path));
    if (!directory.existsSync()) directory.createSync(recursive: true);
  }

  switch (random.nextInt(9)) {
    // Create new.
    case 0:
    case 1:
    case 2:
      final filePath = randomFilePath();
      ensureParent(filePath);
      File(filePath).writeAsStringSync(randomContent());

    // Modify existing.
    case 3:
      final existingPath = randomExistingFilePath();
      if (existingPath == null) return;
      File(existingPath).writeAsStringSync(randomContent());

    // Move to new.
    case 4:
      final existingPath = randomExistingFilePath();
      if (existingPath == null) return;
      final filePath = randomFilePath();
      ensureParent(filePath);
      File(existingPath).renameSync(filePath);

    // Move to existing.
    case 5:
      final existingPath = randomExistingFilePath();
      if (existingPath == null) return;
      File(existingPath).renameSync(randomExistingFilePath()!);

    // Move directory.
    case 6:
      final existingDirectory = randomExistingDirectoryPath();
      if (existingDirectory == null) return;
      final newDirectory = randomDirectoryPath();
      if (Directory(newDirectory).existsSync()) return;
      if (newDirectory.startsWith(existingDirectory)) return;
      ensureParent(newDirectory);
      Directory(existingDirectory).renameSync(newDirectory);

    // Delete existing.
    case 7:
      final existingPath = randomExistingFilePath();
      if (existingPath == null) return;
      File(existingPath).deleteSync();

    // Wait.
    case 8:
      await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

class TestWatcherClient {
  final Watcher watcher;
  final Map<String, int> trackedFileLengths = {};

  TestWatcherClient._(this.watcher);

  static Future<TestWatcherClient> watch(Watcher watcher) async {
    final result = TestWatcherClient._(watcher);
    result._readFiles();
    watcher.events.listen(result._handleEvent);
    await watcher.ready;
    return result;
  }

  Directory get directory => Directory(watcher.path);

  void _readFiles() {
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      _readFile(file.path);
    }
  }

  void _readFile(String path) {
    try {
      trackedFileLengths[path] = File(path).lengthSync();
    } catch (_) {
      print('Read error on $path');
      trackedFileLengths[path] = -1;
    }
  }

  void _handleEvent(WatchEvent event) {
    switch (event.type) {
      case ChangeType.ADD:
        if (trackedFileLengths.containsKey(event.path)) {
          print('ADD for already present path: ${event.path}');
        }
        _readFile(event.path);
        break;

      case ChangeType.MODIFY:
        _readFile(event.path);
        break;

      case ChangeType.REMOVE:
        if (!trackedFileLengths.containsKey(event.path)) {
          print('REMOVE for missing path: ${event.path}');
        }
        trackedFileLengths.remove(event.path);
        break;
    }
  }

  Map<String, int> actualFileLengths() {
    final result = <String, int>{};
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      result[file.path] = file.lengthSync();
    }
    return result;
  }
}
