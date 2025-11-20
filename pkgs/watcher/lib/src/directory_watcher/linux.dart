// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;

import '../directory_watcher.dart';
import '../event.dart';
import '../path_set.dart';
import '../resubscribable.dart';
import '../utils.dart';
import '../watch_event.dart';
import 'directory_list.dart';

/// Uses the inotify subsystem to watch for filesystem events.
///
/// Inotify doesn't suport recursively watching subdirectories, nor does
/// [Directory.watch] polyfill that functionality. This class polyfills it
/// instead.
///
/// This class also compensates for the non-inotify-specific issues of
/// [Directory.watch] producing multiple events for a single logical action
/// (issue 14372) and providing insufficient information about move events
/// (issue 14424).
class LinuxDirectoryWatcher extends ResubscribableWatcher
    implements DirectoryWatcher {
  @override
  String get directory => path;

  LinuxDirectoryWatcher(String directory)
      : super(directory, () => _LinuxDirectoryWatcher(directory));
}

class _LinuxDirectoryWatcher
    implements DirectoryWatcher, ManuallyClosedWatcher {
  @override
  String get directory => _files.root;
  @override
  String get path => _files.root;

  @override
  Stream<WatchEvent> get events => _eventsController.stream;
  final _eventsController = StreamController<WatchEvent>.broadcast();

  @override
  bool get isReady => _readyCompleter.isCompleted;

  @override
  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  /// A stream group for the [Directory.watch] events of [path] and all its
  /// subdirectories.
  final _nativeEvents = StreamGroup<FileSystemEvent>();

  /// All known files recursively within [path].
  final PathSet _files;

  /// Watches by directory.
  final Map<String, _Watch> _watches = {};

  /// Keys of [_watches] as a [PathSet] so they can be quickly retrieved by
  /// parent directory.
  final PathSet _directoriesWatched;

  final Set<_InterruptableDirectoryListing> _listings = Set.identity();

  /// A set of all subscriptions that this watcher subscribes to.
  ///
  /// These are gathered together so that they may all be canceled when the
  /// watcher is closed.
  final _subscriptions = <StreamSubscription>{};

  _LinuxDirectoryWatcher(String path)
      : _files = PathSet(path),
        _directoriesWatched = PathSet(path) {
    _nativeEvents.add(_watch(path, watchUntilCancelled: false)
        .events
        .transform(StreamTransformer.fromHandlers(handleDone: (sink) {
      // Handle the done event here rather than in the call to [_listen] because
      // [innerStream] won't close until we close the [StreamGroup]. However, if
      // we close the [StreamGroup] here, we run the risk of new-directory
      // events being fired after the group is closed, since batching delays
      // those events. See b/30768513.
      _onDone();
    })));

    // Batch the inotify changes together so that we can dedup events.
    var innerStream = _nativeEvents.stream.batchAndConvertEvents();
    _listen(innerStream, _onBatch,
        onError: (Object error, StackTrace stackTrace) {
      // Guarantee that ready always completes.
      if (!isReady) {
        _readyCompleter.complete();
      }
      _eventsController.addError(error, stackTrace);
    });

    final listing = _InterruptableDirectoryListing(
        Directory(path).listRecursivelyIgnoringErrors());
    _listings.add(listing);
    _listen(
      listing.stream,
      (FileSystemEntity entity) {
        if (entity is Directory) {
          _watchSubdir(entity.path);
        } else {
          _files.add(entity.path);
        }
      },
      onError: _emitError,
      onDone: () {
        _listings.remove(listing);
        if (!isReady) {
          _readyCompleter.complete();
        }
      },
      cancelOnError: true,
    );
  }

  @override
  void close() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }

    _subscriptions.clear();
    _files.clear();
    _nativeEvents.close();
    _eventsController.close();
  }

  /// Watch a subdirectory of [directory] for changes.
  void _watchSubdir(String path) {
    var stream = _watch(path, watchUntilCancelled: true)
        .events
        .ignoring<PathNotFoundException>();
    _nativeEvents.add(stream);
  }

  /// The callback that's run when a batch of changes comes in.
  void _onBatch(List<Event> batch) {
    logForTesting?.call('_onBatch,$batch');
    var files = <String>{};
    var dirs = <String>{};
    var changed = <String>{};

    // Inotify events are usually ordered by occurrence. But,
    // https://github.com/dart-lang/sdk/issues/62014 means that moves between
    // directories cause create/delete events to be placed out of order at the
    // end of the batch. Catch these cases in order to do a check on the actual
    // filesystem state.
    var deletes = <String>{};
    var creates = PathSet(path);

    for (var event in batch) {
      // If the watched directory is deleted or moved, we'll get a deletion
      // event for it. Ignore it; we handle closing [this] when the underlying
      // stream is closed.
      if (event.path == path) continue;

      changed.add(event.path);

      switch (event.type) {
        case EventType.moveFile:
          deletes.add(event.path);
          files.remove(event.path);
          dirs.remove(event.path);
          var destination = event.destination;
          if (destination != null) {
            creates.add(destination);
            changed.add(destination);
            files.add(destination);
            dirs.remove(destination);
          }

        case EventType.moveDirectory:
          deletes.add(event.path);
          files.remove(event.path);
          dirs.remove(event.path);
          var destination = event.destination;
          if (destination != null) {
            creates.add(destination);
            changed.add(destination);
            files.remove(destination);
            dirs.add(destination);
          }

        case EventType.delete:
          deletes.add(event.path);
          files.remove(event.path);
          dirs.remove(event.path);

        case EventType.createDirectory:
          creates.add(event.path);
          files.remove(event.path);
          dirs.add(event.path);

        case EventType.modifyDirectory:
          files.remove(event.path);
          if (dirs.add(event.path)) creates.add(event.path);

        case EventType.createFile:
          creates.add(event.path);
          files.add(event.path);
          dirs.remove(event.path);

        case EventType.modifyFile:
          if (files.add(event.path)) creates.add(event.path);
          dirs.remove(event.path);
      }
    }

    // Check paths that might have been affected by out-of-order events, set
    // the correct state in [files] and [dirs].
    //
    // If a delete is a directory, it makes all the creates in the directory
    // ambiguous. `creates` is a `PathSet` so it `remove` matches files under
    // removed directories.
    for (final delete in deletes) {
      for (final path in creates.remove(delete)) {
        logForTesting?.call('ambiguous, recheck $path');
        final type = FileSystemEntity.typeSync(path, followLinks: false);
        if (type == FileSystemEntityType.file ||
            type == FileSystemEntityType.link) {
          logForTesting?.call('ambiguous, recheck $path: file');
          files.add(path);
          dirs.remove(path);
        } else if (type == FileSystemEntityType.directory) {
          logForTesting?.call('ambiguous, recheck $path: directory');
          dirs.add(path);
          files.remove(path);
        } else {
          logForTesting?.call('ambiguous, recheck $path: missing');
          files.remove(path);
          dirs.remove(path);
        }
      }
    }

    _applyChanges(files, dirs, changed);
  }

  /// Applies the net changes computed for a batch.
  ///
  /// The [files] and [dirs] sets contain the files and directories that now
  /// exist, respectively. The [changed] set contains all files and directories
  /// that have changed (including being removed), and so is a superset of
  /// [files] and [dirs].
  void _applyChanges(Set<String> files, Set<String> dirs, Set<String> changed) {
    for (var path in changed) {
      // Unless [path] was a file and still is, emit REMOVE events for it or its
      // contents,
      if (files.contains(path) && _files.contains(path)) continue;

      final filesToRemove = _files.remove(path);
      if (filesToRemove.isEmpty) {
        for (final listing in _listings) {
          listing.ignore(path);
        }
      } else {
        for (var file in filesToRemove) {
          _emitEvent(ChangeType.REMOVE, file);
        }
      }
    }

    for (var file in files) {
      if (_files.contains(file)) {
        _emitEvent(ChangeType.MODIFY, file);
      } else {
        _emitEvent(ChangeType.ADD, file);
        _files.add(file);
      }
    }

    for (var dir in dirs) {
      _watchSubdir(dir);
    }
    for (var dir in dirs) {
      _addSubdir(dir);
    }
  }

  /// Emits [ChangeType.ADD] events for the recursive contents of [path].
  void _addSubdir(String path) {
    logForTesting?.call('_addSubdir,$path');
    final listing = _InterruptableDirectoryListing(
        Directory(path).listRecursivelyIgnoringErrors());
    _listings.add(listing);
    _listen(listing.stream, (FileSystemEntity entity) {
      if (entity is Directory) {
        _watchSubdir(entity.path);
      } else {
        // Only emit ADD if it hasn't already been emitted due to the file being
        // modified or added after the directory was added.
        if (!_files.contains(entity.path)) {
          logForTesting?.call('_addSubdir,$path,$entity');
          _files.add(entity.path);
          _emitEvent(ChangeType.ADD, entity.path);
        }
      }
    }, onDone: () {
      _listings.remove(listing);
    }, onError: (Object error, StackTrace stackTrace) {
      // Ignore an exception caused by the dir not existing. It's fine if it
      // was added and then quickly removed.
      if (error is FileSystemException) return;

      _emitError(error, stackTrace);
    }, cancelOnError: true);
  }

  /// Handles the underlying event stream closing, indicating that the directory
  /// being watched was removed.
  void _onDone() {
    // Most of the time when a directory is removed, its contents will get
    // individual REMOVE events before the watch stream is closed -- in that
    // case, [_files] will be empty here. However, if the directory's removal is
    // caused by a MOVE, we need to manually emit events.
    if (isReady) {
      for (var file in _files.paths) {
        _emitEvent(ChangeType.REMOVE, file);
      }
    }

    close();
  }

  /// Emits a [WatchEvent] with [type] and [path] if this watcher is in a state
  /// to emit events.
  void _emitEvent(ChangeType type, String path) {
    if (!isReady) return;
    if (_eventsController.isClosed) return;
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

  /// Like [Stream.listen], but automatically adds the subscription to
  /// [_subscriptions] so that it can be canceled when [close] is called.
  void _listen<T>(Stream<T> stream, void Function(T) onData,
      {Function? onError,
      void Function()? onDone,
      bool cancelOnError = false}) {
    late StreamSubscription<T> subscription;
    subscription = stream.listen(onData, onError: onError, onDone: () {
      _subscriptions.remove(subscription);
      onDone?.call();
    }, cancelOnError: cancelOnError);
    _subscriptions.add(subscription);
  }

  /// Watches [path].
  ///
  /// See [_Watch] class comment.
  _Watch _watch(String path, {required bool watchUntilCancelled}) {
    logForTesting?.call('_Watch._watch,$path');

    // There can be an existing watch due to race between directory list and
    // event. Add the replacement watch before closing the old one, so the
    // underlying VM watch will be reused if it's actually the same directory.
    final previousWatch = _watches[path];
    final result = _Watch(path, _cancelWatchesUnderPath,
        watchUntilCancelled: watchUntilCancelled);
    if (previousWatch != null) previousWatch.cancel();
    _watches[path] = result;

    // If [path] is the root watch directory do nothing, that's handled when the
    // stream closes and does not need tracking.
    if (path != this.path) {
      _directoriesWatched.add(path);
    }
    return result;
  }

  /// Cancels all watches under path [path].
  void _cancelWatchesUnderPath(String path) {
    logForTesting?.call('_Watch.cancelWatchesUnderPath,$path');

    // If [path] is the root watch directory do nothing, that's handled when the
    // stream closes.
    if (path == this.path) return;

    for (final dir in _directoriesWatched.remove(path)) {
      _watches.remove(dir)!.cancel();
    }
  }
}

class _InterruptableDirectoryListing {
  late final Stream<FileSystemEntity> stream;

  final Set<String> ignores = {};

  _InterruptableDirectoryListing(Stream<FileSystemEntity> stream) {
    this.stream = stream
        .transform(StreamTransformer.fromHandlers(handleData: _handleData));
  }

  void _handleData(FileSystemEntity entity, EventSink<FileSystemEntity> sink) {
    if (!ignores.contains(entity.path)) {
      sink.add(entity);
    }
  }

  void ignore(String path) {
    ignores.add(path);
  }
}

/// Watches [path].
///
/// Workaround for issue with watches on Linux following renames
/// https://github.com/dart-lang/sdk/issues/61861.
///
/// Tracks watches. When a delete or move event indicates that a watch has
/// been removed it is immediately cancelled. This prevents incorrect events
/// if the new location of the directory is also watched.
///
/// Note that the SDK reports "directory deleted" for a move to outside the
/// watched directory, so actually the most important moves are "deletes".
class _Watch {
  final String path;
  final void Function(String) _cancelWatchesUnderPath;
  final StreamController<FileSystemEvent> _controller =
      StreamController<FileSystemEvent>();
  late StreamSubscription<FileSystemEvent> _subscription;
  Stream<FileSystemEvent> get events => _controller.stream;
  final bool _watchUntilCancelled;
  bool closing = false;

  _Watch(this.path, this._cancelWatchesUnderPath,
      {required bool watchUntilCancelled})
      : _watchUntilCancelled = watchUntilCancelled {
    _startListening();
  }

  void _startListening() {
    _subscription = _listen(path, _controller);
  }

  StreamSubscription<FileSystemEvent> _listen(
      String path, StreamController<FileSystemEvent> controller) {
    return Directory(path).watch().listen(
      (event) {
        logForTesting?.call('_Watch._listen,$path,$event');

        if (event.path != path && !event.path.startsWith(path)) {
          event = event.fixDirectory(path);
        }

        if (event is FileSystemDeleteEvent ||
            (event.isDirectory && event is FileSystemMoveEvent)) {
          _cancelWatchesUnderPath(event.path);
        }

        controller.add(event);
      },
      onError: (Object e, StackTrace s) {
        logForTesting?.call('_Watch._listen,error,$path');

        controller.addError(e, s);
        closing = true;
      },
      onDone: () {
        logForTesting?.call('_Watch._listen,close,$path');
        // TODO(davidmorgan): link to SDK issue.
        if (_watchUntilCancelled) {
          _subscription.cancel();
          if (!closing) {
            _startListening();
          }
        } else {
          controller.close();
        }
      },
    );
  }

  void cancel() {
    logForTesting?.call('_Watch.cancel,$path');
    _subscription.cancel();
  }
}

extension _FileSystemEventExtensions on FileSystemEvent {
  FileSystemEvent fixDirectory(String directory) {
    final basename = p.basename(path);
    final newPath = p.join(directory, basename);

    switch (type) {
      case FileSystemEvent.create:
        return FileSystemCreateEvent(newPath, isDirectory);
      case FileSystemEvent.modify:
        return FileSystemModifyEvent(newPath, isDirectory,
            (this as FileSystemModifyEvent).contentChanged);
      case FileSystemEvent.delete:
        return FileSystemDeleteEvent(newPath, isDirectory);
      case FileSystemEvent.move:
        return FileSystemMoveEvent(
            newPath, isDirectory, (this as FileSystemMoveEvent).destination);
      default:
        throw StateError('Unexpected type $type');
    }
  }
}
