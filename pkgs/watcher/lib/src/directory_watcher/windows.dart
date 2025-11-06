// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// TODO(rnystrom): Merge with mac_os version.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../directory_watcher.dart';
import '../event.dart';
import '../path_set.dart';
import '../resubscribable.dart';
import '../utils.dart';
import '../watch_event.dart';
import 'directory_list.dart';

class WindowsDirectoryWatcher extends ResubscribableWatcher
    implements DirectoryWatcher {
  @override
  String get directory => path;

  WindowsDirectoryWatcher(String directory)
      : super(directory, () => _WindowsDirectoryWatcher(directory));
}

class _EventBatcher {
  static const Duration _batchDelay = Duration(milliseconds: 100);
  final List<Event> events = [];
  Timer? timer;

  void addEvent(Event event, void Function() callback) {
    events.add(event);
    timer?.cancel();
    timer = Timer(_batchDelay, callback);
  }

  void cancelTimer() {
    timer?.cancel();
  }
}

class _WindowsDirectoryWatcher
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

  final Map<String, _EventBatcher> _eventBatchers =
      HashMap<String, _EventBatcher>();

  /// The set of files that are known to exist recursively within the watched
  /// directory.
  ///
  /// The state of files on the filesystem is compared against this to determine
  /// the real change that occurred. This is also used to emit REMOVE events
  /// when subdirectories are moved out of the watched directory.
  final PathSet _files;

  /// The subscription to the stream returned by [Directory.watch].
  StreamSubscription<FileSystemEvent>? _watchSubscription;

  /// The subscription to the stream returned by [Directory.watch] of the
  /// parent directory to [directory]. This is needed to detect changes to
  /// [directory], as they are not included on Windows.
  StreamSubscription<FileSystemEvent>? _parentWatchSubscription;

  /// The subscription to the [Directory.list] call for the initial listing of
  /// the directory to determine its initial state.
  StreamSubscription<FileSystemEntity>? _initialListSubscription;

  /// The subscriptions to the [Directory.list] calls for listing the contents
  /// of subdirectories that were moved into the watched directory.
  final Set<StreamSubscription<FileSystemEntity>> _listSubscriptions =
      HashSet<StreamSubscription<FileSystemEntity>>();

  _WindowsDirectoryWatcher(this.path) : _files = PathSet(path) {
    // Before we're ready to emit events, wait for [_listDir] to complete.
    _listDir().then((_) {
      _startWatch();
      _startParentWatcher();
      if (!isReady) {
        _readyCompleter.complete();
      }
    });
  }

  @override
  void close() {
    _watchSubscription?.cancel();
    _parentWatchSubscription?.cancel();
    _initialListSubscription?.cancel();
    for (var sub in _listSubscriptions) {
      sub.cancel();
    }
    _listSubscriptions.clear();
    for (var batcher in _eventBatchers.values) {
      batcher.cancelTimer();
    }
    _eventBatchers.clear();
    _watchSubscription = null;
    _parentWatchSubscription = null;
    _initialListSubscription = null;
    _eventsController.close();
  }

  /// On Windows, if [directory] is deleted, we will not receive any event.
  ///
  /// Instead, we add a watcher on the parent folder (if any), that can notify
  /// us about [path]. This also includes events such as moves.
  void _startParentWatcher() {
    var absoluteDir = p.absolute(path);
    var parent = p.dirname(absoluteDir);
    try {
      // Check if [path] is already the root directory.
      if (FileSystemEntity.identicalSync(parent, path)) return;
    } on FileSystemException catch (_) {
      // Either parent or path or both might be gone due to concurrently
      // occurring changes. Just ignore and continue. If we fail to
      // watch path we will report an error from _startWatch.
      return;
    }
    var parentStream = Directory(parent).watch(recursive: false);
    _parentWatchSubscription = parentStream.listen(
      (event) {
        // Only look at events for 'directory'.
        if (p.basename(event.path) != p.basename(absoluteDir)) return;
        // Test if the directory is removed. FileSystemEntity.typeSync will
        // return NOT_FOUND if it's unable to decide upon the type, including
        // access denied issues, which may happen when the directory is deleted.
        // FileSystemMoveEvent and FileSystemDeleteEvent events will always mean
        // the directory is now gone.
        if (event is FileSystemMoveEvent ||
            event is FileSystemDeleteEvent ||
            (FileSystemEntity.typeSync(path) ==
                FileSystemEntityType.notFound)) {
          for (var path in _files.paths) {
            _emitEvent(ChangeType.REMOVE, path);
          }
          _files.clear();
          close();
        }
      },
      onError: (error) {
        // Ignore errors, simply close the stream. The user listens on
        // [directory], and while it can fail to listen on the parent, we may
        // still be able to listen on the path requested.
        _parentWatchSubscription?.cancel();
        _parentWatchSubscription = null;
      },
    );
  }

  void _onEvent(FileSystemEvent fileSystemEvent) {
    assert(isReady);
    final event = Event.checkAndConvert(fileSystemEvent);
    if (event == null) return;
    if (event.type == EventType.moveFile) {
      _batchEvent(Event.delete(event.path));
      final destination = event.destination;
      if (destination != null) {
        _batchEvent(Event.createFile(destination));
      }
    } else if (event.type == EventType.moveDirectory) {
      _batchEvent(Event.delete(event.path));
      final destination = event.destination;
      if (destination != null) {
        _batchEvent(Event.createDirectory(destination));
      }
    } else {
      _batchEvent(event);
    }
  }

  void _batchEvent(Event event) {
    final batcher = _eventBatchers.putIfAbsent(event.path, _EventBatcher.new);
    batcher.addEvent(event, () {
      _eventBatchers.remove(event.path);
      _onBatch(batcher.events);
    });
  }

  /// The callback that's run when [Directory.watch] emits a batch of events.
  void _onBatch(List<Event> batch) {
    _sortEvents(batch).forEach((path, eventSet) {
      var canonicalEvent = _canonicalEvent(eventSet);
      var events = canonicalEvent == null
          ? _eventsBasedOnFileSystem(path)
          : [canonicalEvent];

      for (var event in events) {
        switch (event.type) {
          case EventType.createFile:
            if (_files.contains(path)) continue;
            _emitEvent(ChangeType.ADD, path);
            _files.add(path);

          case EventType.createDirectory:
            if (_files.containsDir(path)) continue;

            // "Path not found" can be caused by creating then quickly removing
            // a directory: continue without reporting an error. Nested files
            // that get removed during the `list` are already ignored by `list`
            // itself, so there are no other types of "path not found" that
            // might need different handling here.
            var stream = Directory(path).listRecursivelyIgnoringErrors();
            var subscription = stream.listen((entity) {
              if (entity is Directory) return;
              if (_files.contains(entity.path)) return;

              _emitEvent(ChangeType.ADD, entity.path);
              _files.add(entity.path);
            }, cancelOnError: true);
            subscription.onDone(() {
              _listSubscriptions.remove(subscription);
            });
            subscription.onError((Object e, StackTrace stackTrace) {
              _listSubscriptions.remove(subscription);
              _emitError(e, stackTrace);
            });
            _listSubscriptions.add(subscription);

          case EventType.modifyFile:
            _emitEvent(ChangeType.MODIFY, path);

          case EventType.delete:
            for (var removedPath in _files.remove(path)) {
              _emitEvent(ChangeType.REMOVE, removedPath);
            }

          // Move events are removed by `_onEvent` and never returned by
          // `_eventsBasedOnFileSystem`.
          case EventType.moveFile:
          case EventType.moveDirectory:
            throw StateError(event.type.name);

          // Dropped by [Event.checkAndConvert].
          case EventType.modifyDirectory:
            assert(event.type.isIgnoredOnWindows);
        }
      }
    });
  }

  /// Sort all the events in a batch into sets based on their path.
  Map<String, Set<Event>> _sortEvents(List<Event> batch) {
    var eventsForPaths = <String, Set<Event>>{};

    // On Windows new links to directories are sometimes reported by
    // Directory.watch as directories. On all other platforms it reports them
    // consistently as files. See https://github.com/dart-lang/sdk/issues/61797.
    //
    // The wrong type is because Windows creates links to directories as actual
    // directories, then converts them to links. Directory.watch sometimes
    // checks the type too early and gets the wrong result.
    //
    // The batch delay is plenty for the link to be fully created, so verify the
    // file system entity type for all createDirectory` events, converting to
    // `createFile` when needed.
    for (var i = 0; i != batch.length; ++i) {
      final event = batch[i];
      if (event.type == EventType.createDirectory) {
        if (FileSystemEntity.typeSync(event.path, followLinks: false) ==
            FileSystemEntityType.link) {
          batch[i] = Event.createFile(event.path);
        }
      }
    }

    // Events within directories that already have create events are not needed
    // as the directory's full content will be listed.
    var createdDirectories = unionAll(batch.map((event) {
      return event.type == EventType.createDirectory
          ? {event.path}
          : const <String>{};
    }));

    bool isInCreatedDirectory(String path) =>
        createdDirectories.any((dir) => path != dir && p.isWithin(dir, path));

    void addEvent(String path, Event event) {
      if (isInCreatedDirectory(path)) return;
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

      // The file can be already in `_files` if it's in a recently-created
      // directory, the directory list finds it and adds it. In that case a pair
      // of "create"+"modify" should be reported as "modify".
      //
      // Otherwise, it's a new file, "create"+"modify" should be reported as
      // "create".
      type = _files.contains(batch.first.path)
          ? EventType.modifyFile
          : EventType.createFile;
    } else {
      // There are incompatible event types, check the filesystem.
      return null;
    }

    return batch.firstWhere((e) => e.type == type);
  }

  /// Returns zero or more events that describe the change between the last
  /// known state of [path] and its current state on the filesystem.
  ///
  /// This returns a list whose order should be reflected in the events emitted
  /// to the user, unlike the batched events from [Directory.watch]. The
  /// returned list may be empty, indicating that no changes occurred to [path]
  /// (probably indicating that it was created and then immediately deleted).
  List<Event> _eventsBasedOnFileSystem(String path) {
    var fileExisted = _files.contains(path);
    var dirExisted = _files.containsDir(path);

    bool fileExists;
    bool dirExists;
    try {
      fileExists = File(path).existsSync();
      dirExists = Directory(path).existsSync();
    } on FileSystemException {
      return const <Event>[];
    }

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
  /// Note that this is unlikely to happen on Windows, unless the system itself
  /// closes the handle.
  void _onDone() {
    _watchSubscription = null;

    // Emit remove events for any remaining files.
    for (var file in _files.paths) {
      _emitEvent(ChangeType.REMOVE, file);
    }
    _files.clear();
    close();
  }

  /// Start or restart the underlying [Directory.watch] stream.
  void _startWatch() {
    // Note: in older SDKs "watcher closed" exceptions might not get sent over
    // the stream returned by watch, and must be caught via a zone handler.
    runZonedGuarded(
      () {
        var innerStream = Directory(path).watch(recursive: true);
        _watchSubscription = innerStream.listen(
          _onEvent,
          onError: _restartWatchOnOverflowOr(_eventsController.addError),
          onDone: _onDone,
        );
      },
      _restartWatchOnOverflowOr((error, stackTrace) {
        // ignore: only_throw_errors
        throw error;
      }),
    );
  }

  void Function(Object, StackTrace) _restartWatchOnOverflowOr(
      void Function(Object, StackTrace) otherwise) {
    return (Object error, StackTrace stackTrace) async {
      if (error is FileSystemException &&
          error.message.startsWith('Directory watcher closed unexpectedly')) {
        // Wait to work around https://github.com/dart-lang/sdk/issues/61378.
        // Give the VM time to reset state after the error. See the issue for
        // more discussion of the workaround.
        await _watchSubscription?.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 1));
        _eventsController.addError(error, stackTrace);
        _startWatch();
      } else {
        otherwise(error, stackTrace);
      }
    };
  }

  /// Starts or restarts listing the watched directory to get an initial picture
  /// of its state.
  Future<void> _listDir() {
    assert(!isReady);
    _initialListSubscription?.cancel();

    _files.clear();
    var completer = Completer<void>();
    var stream = Directory(path).listRecursivelyIgnoringErrors();
    void handleEntity(FileSystemEntity entity) {
      if (entity is! Directory) _files.add(entity.path);
    }

    _initialListSubscription = stream.listen(
      handleEntity,
      onError: _emitError,
      onDone: completer.complete,
      cancelOnError: true,
    );
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
