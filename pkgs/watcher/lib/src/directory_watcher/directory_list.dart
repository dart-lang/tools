// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../utils.dart';

extension DirectoryRobustRecursiveListing on Directory {
  /// List the given directory recursively but ignore not-found or access
  /// errors.
  ///
  /// Theses can arise from concurrent file-system modification.
  ///
  /// See note on [listRecursively] about MacOS and Linux.
  Stream<FileSystemEntity> listRecursivelyIgnoringErrors() {
    return listRecursively()
        .ignoring<PathNotFoundException>()
        .ignoring<PathAccessException>();
  }

  /// List the given directory recursively.
  ///
  /// On Windows, uses `Directory.list(recursive: true)`. On other platforms,
  /// emulates the Windows list behavior with non-recursive lists. The
  /// difference relates to how symlink cycles are handled, see
  /// https://github.com/dart-lang/sdk/issues/61407#issuecomment-3472718783.
  /// Using the Windows algorithm prevents severe performance regressions
  /// when there are more than a few symlink cycles.
  Stream<FileSystemEntity> listRecursively() {
    if (Platform.isWindows) return list(recursive: true);
    final result = StreamController<FileSystemEntity>();
    unawaited(_listAndRecurse(this, result).then((_) => result.close()));
    return result.stream;
  }
}

Future<void> _listAndRecurse(
    Directory directory, StreamController<FileSystemEntity> result,
    {Set<String>? destinations}) async {
  final subdirectories = <(Directory, String?)>[];

  try {
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is Directory) {
        subdirectories.add((entity, null));
        result.add(entity);
      } else if (entity is File) {
        result.add(entity);
      } else if (entity is Link) {
        final target = entity.targetSync();
        final targetType = FileSystemEntity.typeSync(target);
        if (targetType == FileSystemEntityType.directory) {
          destinations ??= {};
          if (destinations.contains(target)) {
            result.add(entity);
          } else {
            final directory = Directory(entity.path);
            result.add(directory);
            subdirectories.add((directory, target));
          }
        } else if (targetType == FileSystemEntityType.file) {
          final file = File(entity.path);
          result.add(file);
        }
      }
    }
    for (final (directory, target) in subdirectories) {
      if (target != null) {
        destinations ??= {};
        destinations.add(target);
      }
      await _listAndRecurse(directory, result, destinations: destinations);
      if (target != null) {
        destinations!.remove(target);
      }
    }
  } catch (e, s) {
    result.addError(e, s);
  }
}
