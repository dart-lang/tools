// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:watcher/watcher.dart';

/// Edit this to run fast-running tests many times.
int runsPerTest = 1;

typedef WatcherFactory = Watcher Function(String directory);

/// Sets the function used to create the watcher.
set watcherFactory(WatcherFactory factory) {
  _watcherFactory = factory;
}

/// A directory where a test file will be updated to wait for a new modification
/// time.
Directory? _waitForModificationTimesDirectory;

late WatcherFactory _watcherFactory;

/// Creates a new [Watcher] that watches a temporary file or directory.
///
/// If [path] is provided, watches a subdirectory in the sandbox with that name.
Watcher createWatcher({String? path}) {
  if (path == null) {
    path = d.sandbox;
  } else {
    path = p.join(d.sandbox, path);
  }

  return _watcherFactory(path);
}

/// The stream of events from the watcher started with [startWatcher].
late StreamQueue<WatchEvent> _watcherEvents;

/// Whether the event stream has been closed.
///
/// If this is not done by a test (by calling [startClosingEventStream]) it will
/// be done automatically via [addTearDown] in [startWatcher].
var _hasClosedStream = true;

/// Enables [sleepUntilNewModificationTime].
///
/// Resets at the end of the test.
///
/// IMPORTANT NOTE about "polling" watchers and tests:
///
/// The polling watchers can notice changes if the "last modified" time of a
/// file changed or if its size changed.
///
/// Most tests that make changes also change the size of a file, so they do not
/// have to care about whether the timing works out for the modification time to
/// be different.
///
/// Tests that intentionally write to a file _without_ changing its contents
/// must also call [sleepUntilNewModificationTime] if testing a polling
/// watcher. That ensures that the write causes a new modification time.
///
/// At the time of writing in 2025, Windows "last modified" time is much coarser
/// than other platforms, at 1s.
void enableSleepUntilNewModificationTime() {
  if (_waitForModificationTimesDirectory != null) return;
  _waitForModificationTimesDirectory =
      Directory.systemTemp.createTempSync('dart_test_');
  addTearDown(() {
    _waitForModificationTimesDirectory!.deleteSync(recursive: true);
    _waitForModificationTimesDirectory = null;
  });
}

/// Sleeps the until a new modification time is available from the platform.
///
/// This ensures that the next write can be detected by polling watches based on
/// its "last modified" time, whatever the contents.
void sleepUntilNewModificationTime() {
  _waitForModificationTimesDirectory ??= Directory.systemTemp.createTempSync();
  var file = File(p.join(_waitForModificationTimesDirectory!.path, 'file'));
  if (file.existsSync()) file.deleteSync();
  file.createSync();
  final time = file.statSync().modified;
  while (true) {
    file.deleteSync();
    file.createSync();
    final updatedTime = file.statSync().modified;
    if (time != updatedTime) {
      return;
    }
    sleep(const Duration(milliseconds: 1));
  }
}

/// Creates a new [Watcher] that watches a temporary file or directory and
/// starts monitoring it for events.
///
/// If [path] is provided, watches a path in the sandbox with that name.
Future<void> startWatcher({String? path}) async {
  // We want to wait until we're ready *after* we subscribe to the watcher's
  // events.
  var watcher = createWatcher(path: path);
  _watcherEvents = StreamQueue(watcher.events);
  // Forces a subscription to the underlying stream.
  unawaited(_watcherEvents.hasNext);

  _hasClosedStream = false;
  addTearDown(startClosingEventStream);

  await watcher.ready;
}

/// Schedule closing the watcher stream after the event queue has been pumped.
///
/// This is necessary when events are allowed to occur, but don't have to occur,
/// at the end of a test. Otherwise, if they don't occur, the test will wait
/// indefinitely because they might in the future and because the watcher is
/// normally only closed after the test completes.
void startClosingEventStream() async {
  if (_hasClosedStream) return;
  _hasClosedStream = true;
  await pumpEventQueue();
  await _watcherEvents.cancel(immediate: true);
}

/// Add [streamMatcher] as an expectation to [_watcherEvents].
///
/// [streamMatcher] can be a [StreamMatcher], a [Matcher], or a value.
Future _expect(Matcher streamMatcher) {
  return expectLater(_watcherEvents, emits(streamMatcher));
}

/// Expects that [matchers] will match emitted events in any order.
///
/// [matchers] may be [Matcher]s or values, but not [StreamMatcher]s.
Future inAnyOrder(Iterable matchers) =>
    _expect(emitsInAnyOrder(matchers.toSet()));

/// Returns a StreamMatcher that matches a [WatchEvent] with the given [type]
/// and [path].
Matcher isWatchEvent(ChangeType type, String path) {
  return predicate((e) {
    return e is WatchEvent &&
        e.type == type &&
        e.path == p.join(d.sandbox, p.normalize(path));
  }, 'is $type $path');
}

/// Returns a [Matcher] that matches a [WatchEvent] for an add event for [path].
Matcher isAddEvent(String path) => isWatchEvent(ChangeType.ADD, path);

/// Returns a [Matcher] that matches a [WatchEvent] for a modification event for
/// [path].
Matcher isModifyEvent(String path) => isWatchEvent(ChangeType.MODIFY, path);

/// Returns a [Matcher] that matches a [WatchEvent] for a removal event for
/// [path].
Matcher isRemoveEvent(String path) => isWatchEvent(ChangeType.REMOVE, path);

/// Takes the first event emitted during [duration], or returns `null` if there
/// is none.
Future<WatchEvent?> waitForEvent({
  Duration duration = const Duration(seconds: 1),
}) async {
  final result = await _watcherEvents.peek
      .then<WatchEvent?>((e) => e)
      .timeout(duration, onTimeout: () => null);
  if (result != null) _watcherEvents.take(1).ignore();
  return result;
}

/// Expects that no events are emitted for [duration].
Future expectNoEvents({Duration duration = const Duration(seconds: 1)}) async {
  expect(await waitForEvent(duration: duration), isNull);
}

/// Takes all events emitted for [duration].
Future<List<WatchEvent>> takeEvents({required Duration duration}) async {
  final result = <WatchEvent>[];
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < duration) {
    final event = await waitForEvent(duration: duration - stopwatch.elapsed);
    if (event != null) {
      result.add(event);
    }
  }
  return result;
}

/// Expects that the next event emitted will be for an add event for [path].
Future expectAddEvent(String path) =>
    _expect(isWatchEvent(ChangeType.ADD, path));

/// Expects that the next event emitted will be for a modification event for
/// [path].
Future expectModifyEvent(String path) =>
    _expect(isWatchEvent(ChangeType.MODIFY, path));

/// Expects that the next event emitted will be for a removal event for [path].
Future expectRemoveEvent(String path) =>
    _expect(isWatchEvent(ChangeType.REMOVE, path));

/// Writes a file in the sandbox at [path] with [contents].
///
/// If [path] is currently a link it is deleted and a file is written in its
/// place.
///
/// If [contents] is omitted, creates an empty file.
void writeFile(String path, {String? contents}) {
  contents ??= '';

  var fullPath = p.join(d.sandbox, path);

  // Create any needed subdirectories.
  var dir = Directory(p.dirname(fullPath));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  var file = File(fullPath);
  // `File.writeAsStringSync` would write through the link, so if there is a
  // link then start by deleting it.
  if (FileSystemEntity.typeSync(fullPath, followLinks: false) ==
      FileSystemEntityType.link) {
    file.deleteSync();
  }
  file.writeAsStringSync(contents);
  // Check that `fullPath` now refers to a file, not a link.
  expect(FileSystemEntity.typeSync(fullPath), FileSystemEntityType.file);
}

/// Writes a file in the sandbox at [link] pointing to [target].
///
/// [target] is relative to the sandbox, not to [link].
void writeLink({
  required String link,
  required String target,
}) {
  var fullPath = p.join(d.sandbox, link);

  // Create any needed subdirectories.
  var dir = Directory(p.dirname(fullPath));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  Link(fullPath).createSync(p.join(d.sandbox, target));
}

/// Deletes a file in the sandbox at [path].
void deleteFile(String path) {
  final fullPath = p.join(d.sandbox, path);
  expect(FileSystemEntity.typeSync(fullPath, followLinks: false),
      FileSystemEntityType.file);
  File(fullPath).deleteSync();
}

/// Deletes a link in the sandbox at [path].
void deleteLink(String path) {
  final fullPath = p.join(d.sandbox, path);
  expect(FileSystemEntity.typeSync(fullPath, followLinks: false),
      FileSystemEntityType.link);
  Link(fullPath).deleteSync();
}

/// Renames a file in the sandbox from [from] to [to].
void renameFile(String from, String to) {
  var absoluteTo = p.join(d.sandbox, to);
  File(p.join(d.sandbox, from)).renameSync(absoluteTo);
  expect(FileSystemEntity.typeSync(absoluteTo, followLinks: false),
      FileSystemEntityType.file);
}

/// Renames a link in the sandbox from [from] to [to].
///
/// On MacOS and Linux links can also be named with `renameFile`. On Windows,
/// however, a link must be renamed with this method.
void renameLink(String from, String to) {
  var absoluteTo = p.join(d.sandbox, to);
  Link(p.join(d.sandbox, from)).renameSync(absoluteTo);
  expect(FileSystemEntity.typeSync(absoluteTo, followLinks: false),
      FileSystemEntityType.link);
}

/// Creates a directory in the sandbox at [path].
void createDir(String path) {
  Directory(p.join(d.sandbox, path)).createSync();
}

/// Renames a directory in the sandbox from [from] to [to].
void renameDir(String from, String to) {
  var absoluteTo = p.join(d.sandbox, to);
  Directory(p.join(d.sandbox, from)).renameSync(absoluteTo);
  expect(FileSystemEntity.typeSync(absoluteTo, followLinks: false),
      FileSystemEntityType.directory);
}

/// Deletes a directory in the sandbox at [path].
void deleteDir(String path) {
  final fullPath = p.join(d.sandbox, path);
  expect(FileSystemEntity.typeSync(fullPath, followLinks: false),
      FileSystemEntityType.directory);
  Directory(fullPath).deleteSync(recursive: true);
}

/// Runs [callback] with every permutation of non-negative numbers for each
/// argument less than [limit].
///
/// Returns a set of all values returns by [callback].
///
/// [limit] defaults to 3.
Set<S> withPermutations<S>(S Function(int, int, int) callback, {int? limit}) {
  limit ??= 3;
  var results = <S>{};
  for (var i = 0; i < limit; i++) {
    for (var j = 0; j < limit; j++) {
      for (var k = 0; k < limit; k++) {
        results.add(callback(i, j, k));
      }
    }
  }
  return results;
}
