// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:watcher/src/testing.dart';

import '../utils.dart';

/// Changes files randomly.
///
/// Writes are done in an isolate so as to not block the watcher code being
/// tested. Content is modified, files are moved, directories are moved.
/// Directories include nested directories.
///
/// Most file operations as as fast as they can be, consecutive `sync`
/// operations, but one of the possible operations is "wait" which waits for
/// one millisecond.
///
/// A fixed random seed is used so a new `FileChanged` will always perform
/// the same sequence of operations.
class FileChanger {
  final String path;

  Random _random = Random(0);
  final List<LogEntry> _messages = [];

  FileChanger(this.path);

  /// Changes files under [path], [times] times.
  ///
  /// Changes are randomized with [seed], pass the same value to get the same
  /// changes.
  ///
  /// Returns a log of the changes made.
  Future<List<LogEntry>> changeFiles({required int times, int? seed}) async {
    _random = Random(seed);
    final result = await Isolate.run(() => _changeFiles(times: times));
    return result;
  }

  /// Changes files under [path], replaying the log in [log].
  ///
  /// Returns a new log of the changes made.
  Future<List<LogEntry>> replayLog(String log) async {
    return await Isolate.run(() => _replayLog(log));
  }

  Future<List<LogEntry>> _changeFiles({required int times}) async {
    _messages.clear();
    for (var i = 0; i != times; ++i) {
      await _changeFilesOnce();
    }
    return _messages.toList();
  }

  Future<void> _changeFilesOnce() async {
    switch (_random.nextInt(9)) {
      // "Create" is three times more likely than "delete" so that the set of
      // files grows over time.
      case 0:
      case 1:
      case 2:
        final filePath = _randomFilePath();
        _ensureParent(filePath);
        final content = _randomContent();
        _log('create,$filePath,${content.length}');
        // `flush` seems to make flaky failures more likely on Windows,
        // presumably by ensuring that different states actually reach the
        // filesystem.
        File(filePath).writeAsStringSync(content, flush: true);

      case 3:
        final existingPath = _randomExistingFilePath();
        if (existingPath == null) return;
        final content = _randomContent();
        _log('modify,$existingPath,${content.length}');
        // `flush` seems to make flaky failures more likely on Windows,
        // presumably by ensuring that different states actually reach the
        // filesystem.
        File(existingPath).writeAsStringSync(content, flush: true);

      case 4:
        final existingPath = _randomExistingFilePath();
        if (existingPath == null) return;
        final filePath = _randomFilePath();
        _ensureParent(filePath);
        _log('move file to new,$existingPath,$filePath');
        File(existingPath).renameSync(filePath);

      case 5:
        final existingPath = _randomExistingFilePath();
        if (existingPath == null) return;
        final existingPath2 = _randomExistingFilePath()!;
        _log('move file over file,$existingPath,$existingPath2');
        // Fails sometimes on Windows, so guard+retry.
        retryForPathAccessException(
            () => File(existingPath).renameSync(existingPath2));

      case 6:
        final existingDirectory = _randomExistingDirectoryPath();
        if (existingDirectory == null) return;
        final newDirectory = _randomDirectoryPath();
        if (Directory(newDirectory).existsSync()) return;
        if (newDirectory.startsWith(existingDirectory)) return;
        _ensureParent(newDirectory);
        _log('move directory to new,$existingDirectory,$newDirectory');
        // Fails sometimes on Windows, so guard+retry.
        retryForPathAccessException(
            () => Directory(existingDirectory).renameSync(newDirectory));

      case 7:
        final existingPath = _randomExistingFilePath();
        if (existingPath == null) return;
        _log('delete,$existingPath');
        File(existingPath).deleteSync();

      case 8:
        _log('wait');
        await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  /// Returns 0-999 spaces.
  String _randomContent() => ' ' * _random.nextInt(1000);

  /// Returns a file in a random path from [_randomDirectoryPath].
  String _randomFilePath() {
    return p.join(_randomDirectoryPath(), _random.nextInt(100000).toString());
  }

  /// Returns a random directory with 0-2 levels of subdirectories.
  String _randomDirectoryPath() {
    var result = path;
    final subdirectoryDepth = _random.nextInt(3);
    for (var i = 0; i != subdirectoryDepth; ++i) {
      // Name path segments as single characters a-j so there is a good chance
      // of collisions that will cause multiple files to be created in one
      // directory.
      result = p.join(result, String.fromCharCode(97 + _random.nextInt(10)));
    }
    return result;
  }

  /// Returns the path to an already-created file, or `null` if none exists.
  String? _randomExistingFilePath() =>
      (Directory(path).listSync(recursive: true).whereType<File>().toList()
            ..sort((a, b) => a.path.compareTo(b.path))
            ..shuffle(_random))
          .firstOrNull
          ?.path;

  /// Returns the path to an already-created directory, or `null` if none
  /// exists.
  String? _randomExistingDirectoryPath() => (Directory(
        path,
      ).listSync(recursive: true).whereType<Directory>().toList()
            ..sort((a, b) => a.path.compareTo(b.path))
            ..shuffle(_random))
          .firstOrNull
          ?.path;

  void _ensureParent(String path) {
    final directory = Directory(p.dirname(path));
    if (!directory.existsSync()) {
      _log('create directory,${directory.path}');
      directory.createSync(recursive: true);
    }
  }

  void _log(String message) {
    // Remove the tmp folder from the message.
    message = message.replaceAll(',$path${Platform.pathSeparator}', ',');
    _messages.add(LogEntry('F $message'));
  }

  Future<List<LogEntry>> _replayLog(String log) async {
    _messages.clear();
    for (var line in log.split('\n')) {
      // Check for and strip off the log prefix for file changer lines.
      if (!line.startsWith('F ')) continue;
      line = line.substring(2);
      // There might be exceptions if the log has been edited so some operations
      // are no longer possible, for example if a file or directory does not
      // exist. Skip the operation and skip logging it so the new log is
      // correct.
      final messagesLength = _messages.length;
      try {
        await _replayLine(line);
      } catch (_) {
        while (_messages.length > messagesLength) {
          _messages.removeLast();
        }
      }
    }
    return _messages.toList();
  }

  Future<void> _replayLine(String line) async {
    final items = line.split(',');
    final action = items[0];
    final parameters = items.skip(1).toList();
    switch (action) {
      case 'create':
        final filePath = p.join(path, parameters[0]);
        final content = ' ' * int.parse(parameters[1]);
        _log('create,$filePath,${content.length}');
        File(filePath).writeAsStringSync(content, flush: true);

      case 'create directory':
        final newDirectory = p.join(path, parameters[0]);
        _log('create directory,$newDirectory');
        Directory(newDirectory).createSync(recursive: true);

      case 'modify':
        final filePath = p.join(path, parameters[0]);
        final content = ' ' * int.parse(parameters[1]);
        _log('modify,$filePath,${content.length}');
        File(filePath).writeAsStringSync(content, flush: true);

      case 'move file to new':
        final existingPath = p.join(path, parameters[0]);
        final filePath = p.join(path, parameters[1]);
        _log('move file to new,$existingPath,$filePath');
        File(existingPath).renameSync(filePath);

      case 'move file over file':
        final existingPath = p.join(path, parameters[0]);
        final existingPath2 = p.join(path, parameters[1]);
        _log('move file over file,$existingPath,$existingPath2');
        retryForPathAccessException(
            () => File(existingPath).renameSync(existingPath2));

      case 'move directory to new':
        final existingDirectory = p.join(path, parameters[0]);
        final newDirectory = p.join(path, parameters[1]);
        _log('move directory to new,$existingDirectory,$newDirectory');
        retryForPathAccessException(
            () => Directory(existingDirectory).renameSync(newDirectory));

      case 'delete':
        final existingPath = p.join(path, parameters[0]);
        _log('delete,$existingPath');
        File(existingPath).deleteSync();

      case 'wait':
        _log('wait');
        await Future<void>.delayed(const Duration(milliseconds: 1));

      default:
        throw ArgumentError('Failed to parse log line: $line');
    }
  }
}
