// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../directory_watcher.dart';
import '../event.dart';
import '../path_set.dart';
import '../resubscribable.dart';
import '../utils.dart';
import '../watch_event.dart';
import 'directory_list.dart';

/// Uses the FSEvents subsystem to watch for filesystem events.
///
/// FSEvents has two main idiosyncrasies that this class works around. First, it
/// will occasionally report events that occurred before the filesystem watch
/// was initiated. Second, if multiple events happen to the same file in close
/// succession, it won't report them in the order they occurred. See issue
/// 14373.
///
/// This also works around issues 16003 and 14849 in the implementation of
/// [Directory.watch].
class MacOSDirectoryWatcher extends ResubscribableWatcher
    implements DirectoryWatcher {
  @override
  String get directory => path;

  MacOSDirectoryWatcher(String directory)
      : super(directory, () => _MacOSDirectoryWatcher(directory));
}

class _MacOSDirectoryWatcher
    implements DirectoryWatcher, ManuallyClosedWatcher {
  @override
  String get directory => path;
  @override
  final String path;

  @override
  Stream<WatchEvent> get events => _eventsController.stream;
  final _eventsController = StreamController<WatchEvent>.broadcast();

  @override
  bool get isReady => _readyCompleter.isCompleted;

  @override
  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  /// The set of files that are known to exist recursively within the watched
  /// directory.
  ///
  /// The state of files on the filesystem is compared against this to determine
  /// the real change that occurred when working around issue 14373. This is
  /// also used to emit REMOVE events when subdirectories are moved out of the
  /// watched directory.
  final PathSet _files;

  /// The subscription to the stream returned by [Directory.watch].
  ///
  /// This is separate from [_listSubscriptions] because this stream
  /// occasionally needs to be resubscribed in order to work around issue 14849.
  StreamSubscription<List<Event>>? _watchSubscription;

  /// The subscription to the [Directory.list] call for the initial listing of
  /// the directory to determine its initial state.
  StreamSubscription<FileSystemEntity>? _initialListSubscription;

  /// The subscriptions to [Directory.list] calls for listing the contents of a
  /// subdirectory that was moved into the watched directory.
  final _listSubscriptions = <StreamSubscription<FileSystemEntity>>{};

  /// The timer for tracking how long we wait for an initial batch of bogus
  /// events (see issue 14373).
  late Timer _bogusEventTimer;

  _MacOSDirectoryWatcher(this.path) : _files = PathSet(path) {
    _startWatch();

    // Before we're ready to emit events, wait for [_listDir] to complete and
    // for enough time to elapse that if bogus events (issue 14373) would be
    // emitted, they will be.
    //
    // If we do receive a batch of events, [_onBatch] will ensure that these
    // futures don't fire and that the directory is re-listed.
    Future.wait([_listDir(), _waitForBogusEvents()]).then((_) {
      if (!isReady) {
        _readyCompleter.complete();
      }
    });
  }

  @override
  void close() {
    _watchSubscription?.cancel();
    _initialListSubscription?.cancel();
    _watchSubscription = null;
    _initialListSubscription = null;

    for (var subscription in _listSubscriptions) {
      subscription.cancel();
    }
    _listSubscriptions.clear();

    _eventsController.close();
  }

  /// The callback that's run when [Directory.watch] emits a batch of events.
  void _onBatch(List<Event> batch) {
    logForTesting?.call('onBatch: $batch');

    // If we get a batch of events before we're ready to begin emitting events,
    // it's probable that it's a batch of pre-watcher events (see issue 14373).
    // Ignore those events and re-list the directory.
    if (!isReady) {
      // Cancel the timer because bogus events only occur in the first batch, so
      // we can fire [ready] as soon as we're done listing the directory.
      _bogusEventTimer.cancel();
      _listDir().then((_) {
        if (!isReady) {
          _readyCompleter.complete();
        }
      });
      return;
    }

    _sortEvents(batch).forEach((path, eventSet) {
      var canonicalEvent = _canonicalEvent(eventSet);
      var events = canonicalEvent == null
          ? _eventsBasedOnFileSystem(path)
          : [canonicalEvent];

      for (var event in events) {
        switch (event.type) {
          case EventType.createFile:
          case EventType.modifyFile:
            // The type can be incorrect due to a race with listing a new
            // directory or due to a file being copied over an existing one.
            // Choose the type to emit based on the previous emitted state.
            var type =
                _files.contains(path) ? ChangeType.MODIFY : ChangeType.ADD;

            _emitEvent(type, path);
            _files.add(path);

          case EventType.createDirectory:
            if (_files.containsDir(path)) continue;

            var stream = Directory(path)
                .listRecursivelyIgnoringErrors(followLinks: false);
            var subscription = stream.listen((entity) {
              if (entity is Directory) return;
              if (_files.contains(entity.path)) return;

              _emitEvent(ChangeType.ADD, entity.path);
              _files.add(entity.path);
            }, cancelOnError: true);
            subscription.onDone(() {
              _listSubscriptions.remove(subscription);
            });
            subscription.onError(_emitError);
            _listSubscriptions.add(subscription);

          case EventType.delete:
            for (var removedPath in _files.remove(path)) {
              _emitEvent(ChangeType.REMOVE, removedPath);
            }

          // Dropped by [Event.checkAndConvert].
          case EventType.moveFile:
          case EventType.moveDirectory:
          case EventType.modifyDirectory:
            assert(event.type.isNeverReceivedOnMacOS);
        }
      }
    });
  }

  /// Sort all the events in a batch into sets based on their path.
  ///
  /// Events for [path] are discarded.
  ///
  /// Events under directories that are created are discarded.
  Map<String, Set<Event>> _sortEvents(List<Event> batch) {
    var eventsForPaths = <String, Set<Event>>{};

    // FSEvents can report past events, including events on the root directory
    // such as it being created. We want to ignore these. If the directory is
    // really deleted, that's handled by [_onDone].
    batch = batch.where((event) => event.path != path).toList();

    // Events within directories that already have create events are not needed
    // as the directory's full content will be listed. And, events that are
    // under direcory deletes are not needed as all files are removed.
    var ignoredPaths = unionAll(batch.map((event) {
      return event.type == EventType.createDirectory ||
              // Events don't distinguish file deletes from directory deletes,
              // but that doesn't matter here as deleted files will not match
              // as the parent directory of any file.
              event.type == EventType.delete
          ? {event.path}
          : const <String>{};
    }));

    bool isUnderDeleteOrDirectoryCreate(String path) =>
        ignoredPaths.any((dir) => path != dir && p.isWithin(dir, path));

    void addEvent(String path, Event event) {
      if (isUnderDeleteOrDirectoryCreate(path)) return;
      eventsForPaths.putIfAbsent(path, () => <Event>{}).add(event);
    }

    for (var event in batch) {
      addEvent(event.path, event);
    }

    return eventsForPaths;
  }

  /// Returns the canonical event from a batch of events on the same path, or
  /// `null` to indicate that the filesystem should be checked.
  Event? _canonicalEvent(Set<Event> batch) {
    // If the batch is empty, return `null`.
    if (batch.isEmpty) return null;

    // Resolve the event type for the batch.
    var types = batch.map((e) => e.type).toSet();
    EventType type;
    if (types.length == 1) {
      // There's only one event.
      type = types.single;
    } else if (types.length == 2 &&
        types.contains(EventType.modifyFile) &&
        types.contains(EventType.createFile)) {
      // Combine events of type [EventType.modifyFile] and
      // [EventType.createFile] to one event.
      if (_files.contains(batch.first.path)) {
        // The file already existed: this can happen due to a create from
        // before the watcher started being reported.
        type = EventType.modifyFile;
      } else {
        type = EventType.createFile;
      }
    } else {
      // There are incompatible event types, check the filesystem.
      return null;
    }

    // Issue 16003 means that a CREATE event for a directory can indicate
    // that the directory was moved and then re-created.
    // [_eventsBasedOnFileSystem] will handle this correctly by producing a
    // DELETE event followed by a CREATE event if the directory exists.
    if (type == EventType.createDirectory) {
      return null;
    }

    return batch.firstWhere((e) => e.type == type);
  }

  /// Returns one or more events that describe the change between the last known
  /// state of [path] and its current state on the filesystem.
  ///
  /// This returns a list whose order should be reflected in the events emitted
  /// to the user, unlike the batched events from [Directory.watch]. The
  /// returned list may be empty, indicating that no changes occurred to [path]
  /// (probably indicating that it was created and then immediately deleted).
  List<Event> _eventsBasedOnFileSystem(String path) {
    var fileExisted = _files.contains(path);
    var dirExisted = _files.containsDir(path);
    var fileExists = File(path).existsSync();
    var dirExists = Directory(path).existsSync();

    var events = <Event>[];
    if (fileExisted) {
      if (fileExists) {
        events.add(Event.modifyFile(path));
      } else {
        events.add(Event.delete(path));
      }
    } else if (dirExisted) {
      if (dirExists) {
        // If we got contradictory events for a directory that used to exist and
        // still exists, we need to rescan the whole thing in case it was
        // replaced with a different directory.
        events.add(Event.delete(path));
        events.add(Event.createDirectory(path));
      } else {
        events.add(Event.delete(path));
      }
    }

    if (!fileExisted && fileExists) {
      events.add(Event.createFile(path));
    } else if (!dirExisted && dirExists) {
      events.add(Event.createDirectory(path));
    }

    return events;
  }

  /// The callback that's run when the [Directory.watch] stream is closed.
  void _onDone() {
    _watchSubscription = null;

    // If the directory still exists and we're still expecting bogus events,
    // this is probably issue 14849 rather than a real close event. We should
    // just restart the watcher.
    if (!isReady && Directory(path).existsSync()) {
      _startWatch();
      return;
    }

    // FSEvents can fail to report the contents of the directory being removed
    // when the directory itself is removed, so we need to manually mark the
    // files as removed.
    for (var file in _files.paths) {
      _emitEvent(ChangeType.REMOVE, file);
    }
    _files.clear();
    close();
  }

  /// Start or restart the underlying [Directory.watch] stream.
  void _startWatch() {
    // Batch the FSEvent changes together so that we can dedup events.
    var innerStream =
        Directory(path).watch(recursive: true).batchAndConvertEvents();
    _watchSubscription = innerStream.listen(_onBatch,
        onError: _eventsController.addError, onDone: _onDone);
  }

  /// Starts or restarts listing the watched directory to get an initial picture
  /// of its state.
  Future<void> _listDir() {
    assert(!isReady);
    _initialListSubscription?.cancel();

    _files.clear();
    var completer = Completer<void>();
    var stream =
        Directory(path).listRecursivelyIgnoringErrors(followLinks: false);
    _initialListSubscription = stream.listen((entity) {
      if (entity is! Directory) _files.add(entity.path);
    }, onError: _emitError, onDone: completer.complete, cancelOnError: true);
    return completer.future;
  }

  /// Wait 200ms for a batch of bogus events (issue 14373) to come in.
  ///
  /// 200ms is short in terms of human interaction, but longer than any Mac OS
  /// watcher tests take on the bots, so it should be safe to assume that any
  /// bogus events will be signaled in that time frame.
  Future<void> _waitForBogusEvents() {
    var completer = Completer<void>();
    _bogusEventTimer =
        Timer(const Duration(milliseconds: 200), completer.complete);
    return completer.future;
  }

  /// Emit an event with the given [type] and [path].
  void _emitEvent(ChangeType type, String path) {
    if (!isReady) return;
    _eventsController.add(WatchEvent(type, path));
  }

  /// Emit an error, then close the watcher.
  void _emitError(Object error, StackTrace stackTrace) {
    // Guarantee that ready always completes.
    if (!isReady) {
      _readyCompleter.complete();
    }
    _eventsController.addError(error, stackTrace);
    close();
  }
}
