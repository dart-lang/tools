// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:watcher/watcher.dart';

/// Simulates a typical use case for `package:watcher`.
///
/// Tracks file lengths, updating based on watch events.
///
/// Call [verify] to verify whether the tracked lengths match the actual file
/// lengths on disk.
class ClientSimulator {
  final Watcher watcher;
  final void Function(String) printOnFailure;

  /// Events and actions, for logging on failure.
  final List<String> messages = [];

  final Map<String, int> _trackedFileLengths = {};

  StreamSubscription<WatchEvent>? _subscription;
  DateTime _lastEventAt = DateTime.now();

  ClientSimulator._({required this.watcher, required this.printOnFailure});

  /// Creates a `ClientSimulator` watching with [watcher].
  ///
  /// When returned, it has already read the filesystem state and started
  /// tracking file lengths using watcher events.
  static Future<ClientSimulator> watch(
      {required Watcher watcher,
      required void Function(String) printOnFailure}) async {
    final result =
        ClientSimulator._(watcher: watcher, printOnFailure: printOnFailure);
    result._initialRead();
    result._subscription = watcher.events.listen(result._handleEvent);
    await watcher.ready;
    return result;
  }

  /// Waits for at least [duration], and for a span of that duration in which no
  /// events are received.
  Future<void> waitForNoEvents(Duration duration) async {
    _lastEventAt = DateTime.now();
    while (true) {
      final timeLeft = duration - DateTime.now().difference(_lastEventAt);
      if (timeLeft <= Duration.zero) return;
      await Future<void>.delayed(timeLeft + const Duration(milliseconds: 1));
    }
  }

  /// Closes the watcher subscription.
  void close() {
    _subscription?.cancel();
  }

  Directory get _directory => Directory(watcher.path);

  /// Reads all files to get the start state.
  void _initialRead() {
    for (final file in _directory.listSync(recursive: true).whereType<File>()) {
      _readFile(file.path);
    }
  }

  /// Reads the file at [path] and updates tracked state with its current
  /// length.
  ///
  /// If the file cannot be read the size is set to -1, this can be corrected
  /// by a REMOVE event.
  void _readFile(String path) {
    try {
      _trackedFileLengths[path] = File(path).lengthSync();
    } catch (_) {
      _trackedFileLengths[path] = -1;
    }
  }

  /// Updates tracked state for [event].
  ///
  /// For add and modify events, reads the file to determine its length.
  ///
  /// For remove events, removes tracking for that file.
  void _handleEvent(WatchEvent event) {
    _log(event.toString());
    _lastEventAt = DateTime.now();
    switch (event.type) {
      case ChangeType.ADD:
        if (_trackedFileLengths.containsKey(event.path)) {
          // This happens sometimes, so investigation+fix would be needed
          // if we want to make it an error.
          printOnFailure('Warning: ADD for tracked path,${event.path}');
        }
        _readFile(event.path);
        break;

      case ChangeType.MODIFY:
        _readFile(event.path);
        break;

      case ChangeType.REMOVE:
        if (!_trackedFileLengths.containsKey(event.path)) {
          // This happens sometimes, so investigation+fix would be needed
          // if we want to make it an error.
          printOnFailure('Warning: REMOVE untracked path: ${event.path}');
        }
        _trackedFileLengths.remove(event.path);
        break;
    }
  }

  /// Reads current file lengths for verification.
  Map<String, int> _readFileLengths() {
    final result = <String, int>{};
    for (final file in _directory.listSync(recursive: true).whereType<File>()) {
      result[file.path] = file.lengthSync();
    }
    return result;
  }

  /// Returns whether tracked state matches actual state on disk.
  ///
  /// If not, and [printOnFailure] is passed, uses it to print a dscription of
  /// the failure.
  bool verify({void Function(String)? printOnFailure}) {
    final fileLengths = _readFileLengths();

    var result = true;

    final unexpectedFiles =
        fileLengths.keys.toSet().difference(_trackedFileLengths.keys.toSet());
    if (unexpectedFiles.isNotEmpty) {
      result = false;

      if (printOnFailure != null) {
        printOnFailure('Failed, on disk but not tracked:');
        printOnFailure(
            unexpectedFiles.map((path) => path.padLeft(4)).join('\n'));
      }
    }

    final missingExpectedFiles =
        _trackedFileLengths.keys.toSet().difference(fileLengths.keys.toSet());
    if (missingExpectedFiles.isNotEmpty) {
      result = false;
      if (printOnFailure != null) {
        printOnFailure('Failed, tracked but not on disk:');
        printOnFailure(
            missingExpectedFiles.map((path) => path.padLeft(4)).join('\n'));
      }
    }

    final differentFiles = <String>{};
    for (final path in fileLengths.keys) {
      if (_trackedFileLengths[path] == null) continue;
      if (fileLengths[path] != _trackedFileLengths[path]) {
        differentFiles.add(path);
      }
    }
    if (differentFiles.isNotEmpty) {
      result = false;
      if (printOnFailure != null) {
        printOnFailure('Failed, tracking is out of date:');
        final output = StringBuffer();
        for (final path in differentFiles) {
          final tracked = _trackedFileLengths[path]!;
          final actual = fileLengths[path]!;
          output.write('    $path tracked=$tracked actual=$actual\n');
        }
        printOnFailure(output.toString());
      }
    }

    return result;
  }

  void _log(String message) {
    // Remove the tmp folder from the message.
    message =
        message.replaceAll('${watcher.path}${Platform.pathSeparator}', '');
    messages.add(message);
  }
}
