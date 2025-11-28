// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../../event.dart';
import '../../utils.dart';
import '../../watch_event.dart';
import 'native_watch.dart';
import 'paths.dart';

/// Linux directory watcher.
///
/// Watches a single directory and maintains child [WatchTree] instances for
/// subdirectories.
class WatchTree {
  final AbsolutePath watchedDirectory;

  /// Native watch on [watchedDirectory].
  NativeWatch? _nativeWatch;

  /// Known subdirectories and their watch trees.
  final Map<RelativePath, WatchTree> _directories = {};

  /// Known files.
  final Set<RelativePath> _files = {};

  /// Called to emit a user-visible watch event.
  final void Function(WatchEvent) _emitEvent;

  /// Called to emit a user-visible error.
  final void Function(Object, StackTrace) _onError;

  /// Called when [watchedDirectory] is deleted.
  final void Function() _watchedDirectoryWasDeleted;

  /// Watches [watchedDirectory] and its subdirectories.
  ///
  /// If [starting] then initial setup is in progress and "add" events are not
  /// emitted for files already in the directory.
  ///
  /// Pass handlers [emitEvent], [onError] and [watchedDirectoryWasDeleted].
  WatchTree({
    required this.watchedDirectory,
    required bool starting,
    required void Function(WatchEvent) emitEvent,
    required void Function(Object, StackTrace) onError,
    required void Function() watchedDirectoryWasDeleted,
  })  : _emitEvent = emitEvent,
        _onError = onError,
        _watchedDirectoryWasDeleted = watchedDirectoryWasDeleted {
    logForTesting?.call('WatchTree(),$watchedDirectory');
    _watch(starting: starting, recovering: false);
  }

  /// Stops watching.
  void stopWatching() {
    logForTesting?.call('WatchTree,$watchedDirectory,stopWatching');
    _nativeWatch?.close();
    for (final directory in _directories.values) {
      directory.stopWatching();
    }
  }

  /// Watches [watchedDirectory].
  ///
  /// Creates a [NativeWatch] then lists the directory to get the current state.
  ///
  /// If [starting], don't emit "add" events for files that are discovered.
  ///
  /// Set [recovering] to recover from a failure of the native watcher. This
  /// compares to the last known state, and emits "add" for new files, "remove"
  /// for files that have disappeared, and "modify" for files that are still
  /// present.
  void _watch({required bool starting, required bool recovering}) {
    logForTesting
        ?.call('WatchTree,$watchedDirectory,_watch,$starting,$recovering');
    _nativeWatch?.close();
    _nativeWatch = NativeWatch(
        watchedDirectory: watchedDirectory,
        restartWatching: () {
          _watch(starting: false, recovering: true);
        },
        watchedDirectoryWasDeleted: () {
          _emitDeleteTree();
          _watchedDirectoryWasDeleted();
        },
        onError: _onError,
        onEvents: _onEvents);

    final listedFiles = <RelativePath>{};
    final listedDirectories = <RelativePath>{};
    try {
      for (final entity in watchedDirectory.listSync()) {
        if (entity is File || entity is Link) {
          listedFiles.add(entity.pathRelativeTo(watchedDirectory));
        } else if (entity is Directory) {
          listedDirectories.add(entity.pathRelativeTo(watchedDirectory));
        }
      }
    } catch (_) {
      // Nothing found, use empty sets so everything is handled as deleted.
    }

    logForTesting?.call('Watch,$watchedDirectory,list,'
        'files=$listedFiles,directories=$listedDirectories');
    if (recovering) {
      // Emit deletes for missing files.
      for (final file in _files.toList()) {
        if (!listedFiles.contains(file)) {
          _emitDeleteFile(file);
        }
      }
    }
    // Emit for present files. If `recovering`, emit modify events for files
    // that are still present. If not `starting`, emit add events for new files.
    for (final file in listedFiles) {
      if (_files.contains(file)) {
        if (recovering) {
          _emitModifyFile(file);
        }
      } else {
        _addFile(file, emit: !starting);
      }
    }
    if (recovering) {
      // Emit deletes for missing directories.
      for (final directory in _directories.keys.toList()) {
        if (!listedDirectories.contains(directory)) {
          _emitDeleteDirectory(directory);
        }
      }
    }
    // Handle present directories. Start watching if not already watched.
    for (final directory in listedDirectories) {
      if (!_directories.containsKey(directory)) {
        _watchDirectory(directory, starting: starting);
      }
    }
  }

  /// Polls [path] then updates state and emits events as needed.
  ///
  /// Polling is triggered when a sequence of delete and create events arrives
  /// for the path but the order can't be determined. So if a file existed and
  /// still exists then it's a "modify", not a no-op; and for a directory, it
  /// needs to be watched again.
  void _poll(RelativePath path) {
    logForTesting?.call('Watch,$watchedDirectory,_poll,$path');
    final stat = watchedDirectory.append(path).statSync();
    if (stat.type == FileSystemEntityType.file ||
        stat.type == FileSystemEntityType.link) {
      logForTesting?.call('Watch,$watchedDirectory,poll,$path,file');
      if (_directories.containsKey(path)) {
        _emitDeleteDirectory(path);
      }
      if (_files.contains(path)) {
        _emitModifyFile(path);
      } else {
        _addFile(path);
      }
    } else if (stat.type == FileSystemEntityType.directory) {
      logForTesting?.call('Watch,$watchedDirectory,poll,$path,directory');
      if (_files.contains(path)) {
        _emitDeleteFile(path);
      }
      if (_directories.containsKey(path)) {
        _emitDeleteDirectory(path);
        _watchDirectory(path);
      } else {
        _watchDirectory(path);
      }
    } else {
      logForTesting?.call('Watch,$watchedDirectory,poll,$path,missing');
      if (_files.contains(path)) {
        _emitDeleteFile(path);
      }
      if (_directories.keys.contains(path)) {
        _emitDeleteDirectory(path);
      }
    }
  }

  /// Handles events from [_nativeWatch].
  void _onEvents(List<Event> events) {
    logForTesting?.call('Watch,$watchedDirectory,_onEvents,$events');
    // Handle by path. Move events are already split into separate create and
    // delete events by `NativeWatch`.
    final eventsByPath = <RelativePath, List<EventType>>{};
    for (final event in events) {
      final eventPath = event.pathRelativeTo(watchedDirectory);
      eventsByPath.putIfAbsent(eventPath, () => []).add(event.type);
    }

    // As described in https://github.com/dart-lang/sdk/issues/62014 the VM
    // tries to combine the "create" and "delete" parts of a move operation into
    // one "move" event. But, if the move is to a different directory then only
    // half of the move is received. Currently this event is moved to the end of
    // the batch. This means that the ordering of create and delete events for
    // one path within the batch can't be relied on to decide whether the file
    // now exists or has been deleted.
    //
    // So, separate out ambigious paths as [pathsToPoll], and check the
    // filesystem state for them instead of reporting based on events received.
    final pathsToPoll = <RelativePath>{};
    for (final entry in eventsByPath.entries) {
      final eventPath = entry.key;
      final eventTypes = entry.value;
      final eventTypesSet = eventTypes.toSet();

      // Path needs polling if it had both a delete and a create.
      final needsPolling = eventTypesSet.contains(EventType.delete) &&
          (eventTypesSet.contains(EventType.createFile) ||
              eventTypesSet.contains(EventType.createDirectory));
      if (needsPolling) {
        logForTesting
            ?.call('Watch,$watchedDirectory,onEvents,$eventPath,ambiguous');
        pathsToPoll.add(eventPath);
        continue;
      }

      // Not ambiguous, so the events can be applied in order. Work out the
      // final state.
      var isCreatedDirectory = false;
      var isCreatedFile = false;
      var isModified = false;
      var isDeleted = false;

      for (final eventType in eventTypes) {
        switch (eventType) {
          case EventType.createDirectory:
            isCreatedDirectory = true;
            isCreatedFile = false;

          case EventType.createFile:
            isCreatedFile = true;
            isCreatedDirectory = false;

          case EventType.modifyFile:
            isModified = true;

          case EventType.delete:
            isCreatedFile = false;
            isCreatedDirectory = false;
            isModified = false;
            isDeleted = true;

          default:
            throw StateError(eventType.name);
        }
      }

      // Emit events based on the computed state.
      if (isCreatedDirectory) {
        _watchDirectory(eventPath);
      } else if (isModified || isCreatedFile) {
        if (_files.contains(eventPath)) {
          _emitModifyFile(eventPath);
        } else {
          _addFile(eventPath);
        }
      } else if (isDeleted) {
        _delete(eventPath);
      }
    }

    // Poll the paths that were ambiguous.
    for (final path in pathsToPoll) {
      _poll(path);
    }
  }

  /// Emits events for deleting the entire tree.
  void _emitDeleteTree() {
    logForTesting?.call('WatchTree,$watchedDirectory,_emitDeleteTree');
    _nativeWatch?.close();
    for (final file in _files.toList()) {
      _emitDeleteFile(file);
    }
    for (final directory in _directories.keys.toList()) {
      _emitDeleteDirectory(directory);
    }
  }

  /// Watches [directory].
  ///
  /// If [starting], "add" events are not emitted for files already in the
  /// directory.
  void _watchDirectory(RelativePath directory, {bool starting = false}) {
    logForTesting?.call('Watch,$watchedDirectory,createDirectory,$directory');
    _directories.remove(directory)?._emitDeleteTree();
    _directories[directory] = WatchTree(
        emitEvent: _emitEvent,
        onError: (Object e, StackTrace s) {
          // Ignore exceptions from subdirectories except "out of watchers"
          // which is an unrecoverable error.
          if (e is FileSystemException &&
              e.message.contains('Failed to watch path') &&
              e.osError?.errorCode == 28) {
            _onError(e, s);
          }
        },
        watchedDirectoryWasDeleted: () {
          _emitDeleteDirectory(directory);
        },
        watchedDirectory: watchedDirectory.append(directory),
        starting: starting);
  }

  /// Adds [file] to known [_files].
  ///
  /// If [emit], emits an "add" event.
  void _addFile(RelativePath file, {bool emit = true}) {
    logForTesting?.call('Watch,$watchedDirectory,_addFile,$emit,$file');
    _files.add(file);
    if (emit) {
      _emitEvent(watchedDirectory.append(file).addEvent);
    }
  }

  /// Emits a "modify" event for [file].
  void _emitModifyFile(RelativePath file) {
    logForTesting?.call('Watch,$watchedDirectory,_emitModifyFile,$file');
    _emitEvent(watchedDirectory.append(file).modifyEvent);
  }

  /// Removes [path] from [_files] or [_directories].
  ///
  /// If it was a known file, emits the "delete" event.
  ///
  /// If it was a known directory, emits "delete" events and stops watching it.
  ///
  /// If it was not known, just logs an "unmatched delete".
  void _delete(RelativePath path) {
    logForTesting?.call('Watch,$watchedDirectory,_delete,$path');
    if (_files.contains(path)) {
      _emitDeleteFile(path);
    } else if (_directories.containsKey(path)) {
      _emitDeleteDirectory(path);
    } else {
      logForTesting?.call('Watch,$watchedDirectory,delete,unmatched delete');
    }
  }

  /// Emits a "delete" event for [file] and removes it from [_files].
  void _emitDeleteFile(RelativePath file) {
    logForTesting?.call('Watch,$watchedDirectory,deleteFile,$file');
    _files.remove(file);
    _emitEvent(watchedDirectory.append(file).removeEvent);
  }

  /// Stops watching [directory] and removes it from [_directories].
  void _emitDeleteDirectory(RelativePath directory) {
    logForTesting?.call('Watch,$watchedDirectory,deleteDirectory,$directory');
    _directories.remove(directory)!._emitDeleteTree();
  }
}
