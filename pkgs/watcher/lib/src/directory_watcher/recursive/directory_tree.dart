// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../../paths.dart';
import '../../testing.dart';
import '../../watch_event.dart';
import 'event_tree.dart';

/// MacOS or Windows directory tree.
///
/// Tracks state for a single directory and maintains child [DirectoryTree]
/// instances for subdirectories.
class DirectoryTree {
  final AbsolutePath watchedDirectory;

  /// Known subdirectories and their directory trees.
  final Map<PathSegment, DirectoryTree> _directories = {};

  /// Known files.
  final Set<PathSegment> _files = {};

  /// Called to emit a user-visible watch event.
  final void Function(WatchEvent) _emitEvent;

  /// Watches [watchedDirectory] and its subdirectories.
  ///
  /// Pass the handler [emitEvent].
  DirectoryTree({
    required this.watchedDirectory,
    required void Function(WatchEvent) emitEvent,
  }) : _emitEvent = emitEvent {
    logForTesting?.call('DirectoryTree(),$watchedDirectory');
    poll(EventTree.singleEvent());
  }

  /// Polls [watchedDirectory].
  ///
  /// Directories and files mentioned in [eventTree] are polled. This includes
  /// calling [poll] on subdirectories with subtrees of [eventTree] and fully
  /// polling newly-discovered or recreated directories.
  void poll(EventTree eventTree) {
    logForTesting?.call('DirectoryTree,$watchedDirectory,poll,$eventTree');

    // If there's an event mentioning this directory then the whole directory
    // needs polling.
    if (eventTree.isSingleEvent) {
      _pollDirectory();
      return;
    }

    // Poll filesystem entities in this directory, call `poll` on subdirectories
    // with subtrees of [eventTree].
    for (final entry in eventTree.entries) {
      if (entry.value.isSingleEvent) {
        _pollPathSegment(entry.key);
      } else {
        final directory = _directories[entry.key];
        if (directory != null) {
          directory.poll(entry.value);
        } else {
          // Events for a directory but it's not a known directory.
          // Call `_pollPathSegment` which will do the right thing based on
          // whether it currently exists and whether it's a file or a directory.
          _pollPathSegment(entry.key);
        }
      }
    }
  }

  /// Polls the directory.
  ///
  /// Emits "add" events for newly-discovered files, "modify" events for known
  /// files that are still present, and "delete" events for known files that no
  /// longer exist.
  ///
  /// "modify" events are emitted for known files because a directory poll
  /// happens due to the directory being deleted and/or created; a known file
  /// might be different because the whole directory was recreated.
  ///
  /// Starts tracking newly-discovered directories. Polls known directories that
  /// are still present. For known directories that no longer exist, emits
  /// "delete" events and stops tracking them.
  void _pollDirectory() {
    logForTesting?.call('DirectoryTree,$watchedDirectory,_pollDirectory');

    final listedFiles = <PathSegment>{};
    final listedDirectories = <PathSegment>{};

    try {
      for (final entity in watchedDirectory.listSync()) {
        if (entity is File || entity is Link) {
          listedFiles.add(entity.pathSegmentRelativeTo(watchedDirectory));
        } else if (entity is Directory) {
          listedDirectories.add(entity.pathSegmentRelativeTo(watchedDirectory));
        }
      }
    } catch (_) {
      // Nothing found, use empty sets so everything is handled as deleted.
    }

    logForTesting?.call(
      'Watch,$watchedDirectory,list,'
      'files=$listedFiles,directories=$listedDirectories',
    );
    // Emit deletes for missing files.
    for (final file in _files.toList()) {
      if (!listedFiles.contains(file)) {
        _emitDeleteFile(file);
      }
    }
    // Emit for present files.
    for (final file in listedFiles) {
      if (_files.contains(file)) {
        _emitModifyFile(file);
      } else {
        _addFile(file);
      }
    }

    // Emit deletes for missing directories.
    for (final directory in _directories.keys.toList()) {
      if (!listedDirectories.contains(directory)) {
        _emitDeleteDirectory(directory);
      }
    }
    // Handle present directories.
    for (final directory in listedDirectories) {
      _trackOrPollDirectory(directory);
    }
  }

  /// Polls a file or directory directoly under [watchedDirectory].
  ///
  /// If it's now a directory, tracks it, or polls it if it's already a known
  /// directory. If it's not now a directory and it was before, emits deletes
  /// for the directory and stops tracking it.
  ///
  /// If it's now a file (or a link), emits "add" if it's new or "modify" if it
  /// was a known file. If it's not now a file and it was before, emits a
  /// delete.
  void _pollPathSegment(PathSegment segment) {
    logForTesting?.call(
      'DirectoryTree,$watchedDirectory,_pollPathSegment,$segment',
    );

    final type = watchedDirectory.append(segment).typeSync();

    if (type == FileSystemEntityType.directory) {
      _trackOrPollDirectory(segment);
    } else {
      if (_directories.containsKey(segment)) {
        _emitDeleteDirectory(segment);
      }
    }

    if (type == FileSystemEntityType.file ||
        type == FileSystemEntityType.link) {
      if (_files.contains(segment)) {
        _emitModifyFile(segment);
      } else {
        _addFile(segment);
      }
    } else {
      if (_files.remove(segment)) {
        _emitDeleteFile(segment);
      }
    }
  }

  /// Emits events for deleting the entire tree.
  void emitDeleteTree() {
    logForTesting?.call('DirectoryTree,$watchedDirectory,_emitDeleteTree');
    for (final file in _files.toList()) {
      _emitDeleteFile(file);
    }
    for (final directory in _directories.keys.toList()) {
      _emitDeleteDirectory(directory);
    }
  }

  /// Tracks or polls [directory].
  ///
  /// If [directory] is known, polls it. If not, starts tracking it, emitting
  /// "add" events for discovered files.
  void _trackOrPollDirectory(PathSegment directory) {
    logForTesting?.call(
      'Watch,$watchedDirectory,_trackOrPollDirectory,$directory',
    );
    if (_directories.containsKey(directory)) {
      // Poll known directories.
      _directories[directory]!.poll(EventTree.singleEvent());
    } else {
      /// Start tracking new directories.
      _directories[directory] = DirectoryTree(
        emitEvent: _emitEvent,
        watchedDirectory: watchedDirectory.append(directory),
      );
    }
  }

  /// Adds [file] to known [_files].
  void _addFile(PathSegment file) {
    logForTesting?.call('Watch,$watchedDirectory,_addFile,$file');
    _files.add(file);
    _emitEvent(watchedDirectory.append(file).addEvent);
  }

  /// Emits a "modify" event for [file].
  void _emitModifyFile(PathSegment file) {
    logForTesting?.call('Watch,$watchedDirectory,_emitModifyFile,$file');
    _emitEvent(watchedDirectory.append(file).modifyEvent);
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
    _directories.remove(directory)!.emitDeleteTree();
  }
}
