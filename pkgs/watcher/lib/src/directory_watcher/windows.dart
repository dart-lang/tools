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
import '../watch_event.dart';
import 'directory_list.dart';

class WindowsDirectoryWatcher extends ResubscribableWatcher
    implements DirectoryWatcher {
  @override
  String get directory => path;

  WindowsDirectoryWatcher(String directory)
      : super(
            directory, () => WindowsManuallyClosedDirectoryWatcher(directory));
}

/// Windows directory watcher.
///
/// On Windows the OS file change notifications do not include whether the
/// file system entity is a directory. So, the Dart VM checks the filesystem
/// after the event is received to get the type. This leads to the `isDirectory`
/// value being unreliable in two important ways.
///
/// 1. If the event is about a filesystem entity that gets deleted immediately
/// after the event then the Dart VM finds nothing and just reports
/// `false` for `isDirectory`.
///
/// 2. If the event is about a newly-created link to a directory then the file
/// system entity type changes during creation from directory to link. The Dart
/// VM entity type check races with this, and the VM reports a random value for
/// `isDirectory`. See: https://github.com/dart-lang/sdk/issues/61797
///
/// To deal with both, `isDirectory` is discarded and the filesystem is checked
/// again after a sufficient delay to allow directory symlink creation to
/// finish.
///
/// On my machine, the test failure rate due to the type drops from 150/1000
/// at 900us to 0/10000 at 1000us. So, 1000us = 1ms is sufficient. Use 5ms to
/// give a margin for error for different machine performance and load.
class WindowsManuallyClosedDirectoryWatcher
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

  final Map<String, _PendingPoll> _pendingPolls =
      HashMap<String, _PendingPoll>();

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
  StreamSubscription<DirectoryList>? _initialListSubscription;

  /// The subscriptions to the [Directory.list] calls for listing the contents
  /// of subdirectories that were moved into the watched directory.
  final Set<StreamSubscription<DirectoryList>> _listSubscriptions =
      HashSet<StreamSubscription<DirectoryList>>();

  WindowsManuallyClosedDirectoryWatcher(this.path) : _files = PathSet(path) {
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
    for (var pendingPoll in _pendingPolls.values) {
      pendingPoll.cancelTimer();
    }
    _pendingPolls.clear();
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
    var event = Event.checkAndConvert(fileSystemEvent);
    if (event == null) return;

    _schedulePoll(event.path,
        created: event.type == EventType.createFile ||
            event.type == EventType.createDirectory,
        modified: event.type == EventType.modifyFile ||
            event.type == EventType.modifyDirectory,
        deleted: event.type == EventType.delete ||
            event.type == EventType.moveFile ||
            event.type == EventType.moveDirectory,
        movedOnto: false);
    final destination = event.destination;
    if (destination != null) {
      _schedulePoll(destination,
          created: false, modified: false, deleted: false, movedOnto: true);
    }
  }

  void _schedulePoll(String path,
      {required bool created,
      required bool modified,
      required bool deleted,
      required bool movedOnto}) {
    final pendingPoll =
        _pendingPolls.putIfAbsent(path, () => _PendingPoll(path));
    pendingPoll.startOrReset(() => _poll(pendingPoll),
        created: created,
        modified: modified,
        deleted: deleted,
        movedOnto: movedOnto);
  }

  /// Polls for the path specified by [poll] and emits events for any changes.
  void _poll(_PendingPoll poll) {
    final path = poll.path;
    final events = _eventsBasedOnFileSystem(path,
        reportCreate: poll.created || poll.movedOnto,
        reportDelete: poll.deleted,
        // A modification can be reported due to a modification event, a
        // create+delete together, or if the path is a move destination.
        // The important case where the file is present, an event arrives
        // for the file and a modification is _not_ reported is when the file
        // was already discovered by listing a new directory, then the "add"
        // event for it is processed afterwards.
        reportModification:
            poll.modified || (poll.created && poll.deleted) || poll.movedOnto);

    for (final event in events) {
      switch (event.type) {
        case EventType.createFile:
          _emitEvent(ChangeType.ADD, path);
          _files.add(path);

        case EventType.createDirectory:
          final stream = Directory(path).listRecursivelyIgnoringErrors();
          final subscription = stream.listen((directoryList) {
            for (final entity in directoryList.entities) {
              if (entity is Directory) return;
              if (_files.contains(entity.path)) return;

              _emitEvent(ChangeType.ADD, entity.path);
              _files.add(entity.path);
            }
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
          for (final removedPath in _files.remove(path)) {
            _emitEvent(ChangeType.REMOVE, removedPath);
          }

        // Never returned by `_eventsBasedOnFileSystem`.
        case EventType.moveFile:
        case EventType.moveDirectory:
        case EventType.modifyDirectory:
          throw StateError(event.type.name);
      }
    }
  }

  /// Returns zero or more events that describe the change between the last
  /// known state of [path] and its current state on the filesystem.
  ///
  /// This returns a list whose order should be reflected in the events emitted
  /// to the user, unlike the batched events from [Directory.watch].
  ///
  ///
  /// [reportCreate], [reportModification] and [reportDelete] restrict the types
  /// of events that can be emitted.
  List<Event> _eventsBasedOnFileSystem(String path,
      {required bool reportCreate,
      required bool reportModification,
      required bool reportDelete}) {
    var fileExisted = _files.contains(path);
    var dirExisted = _files.containsDir(path);

    bool fileExists;
    bool dirExists;
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      fileExists = type == FileSystemEntityType.file ||
          type == FileSystemEntityType.link;
      dirExists = type == FileSystemEntityType.directory;
    } on FileSystemException {
      return const <Event>[];
    }

    var events = <Event>[];
    if (fileExisted) {
      if (fileExists) {
        if (reportModification) events.add(Event.modifyFile(path));
      } else {
        if (reportDelete) events.add(Event.delete(path));
      }
    } else if (dirExisted) {
      if (dirExists) {
        // If we got contradictory events for a directory that used to exist and
        // still exists, we need to rescan the whole thing in case it was
        // replaced with a different directory.
        if (reportDelete) events.add(Event.delete(path));
        if (reportCreate) events.add(Event.createDirectory(path));
      } else {
        if (reportDelete) events.add(Event.delete(path));
      }
    }

    if (!fileExisted && fileExists) {
      if (reportCreate) events.add(Event.createFile(path));
    } else if (!dirExisted && dirExists) {
      if (reportCreate) events.add(Event.createDirectory(path));
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
      _restartWatchOnOverflowOr(Error.throwWithStackTrace),
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
    void handleEntity(DirectoryList directoryList) {
      for (final entity in directoryList.entities) {
        if (entity is! Directory) _files.add(entity.path);
      }
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

/// A pending poll of a path.
///
/// Holds the union of the types of events that were received for the path while
/// waiting to do the poll.
class _PendingPoll {
  // See _WindowsDirectoryWatcher class comment for why 5ms.
  static const Duration _batchDelay = Duration(milliseconds: 5);

  final String path;
  bool created = false;
  bool modified = false;
  bool deleted = false;
  bool movedOnto = false;

  Timer? timer;

  _PendingPoll(this.path);

  /// Starts or resets the poll timer.
  ///
  /// [function] will be called if the timer completes.
  ///
  /// ORs [created], [modified], [deleted] and [movedOnto] into the poll
  /// state.
  void startOrReset(void Function() function,
      {required bool created,
      required bool modified,
      required bool deleted,
      required bool movedOnto}) {
    this.created |= created;
    this.modified |= modified;
    this.deleted |= deleted;
    this.movedOnto |= movedOnto;
    timer?.cancel();
    timer = Timer(_batchDelay, function);
  }

  void cancelTimer() {
    timer?.cancel();
  }
}
