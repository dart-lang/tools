// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils.dart';

extension DirectoryRobustRecursiveListing on Directory {
  /// Lists the given directory recursively ignoring not-found or access errors.
  ///
  /// These can arise from concurrent file-system modification.
  ///
  /// See [listRecursively] for how symlinks are handled.
  Stream<FileSystemEntity> listRecursivelyIgnoringErrors() {
    return listRecursively()
        .ignoring<PathNotFoundException>()
        .ignoring<PathAccessException>();
  }

  /// Lists the directory recursively.
  ///
  /// This is like `Directory.list(recursive: true)`, but handles symlinks like
  /// `find -L` to avoid a performance issue with symbolic link cycles.
  ///
  /// See: https://github.com/dart-lang/sdk/issues/61407.
  ///
  /// A link to a directory is only followed if the link target is not currently
  /// being traversed. For this check, directories are compared using their
  /// symlink-resolved paths.
  ///
  /// Skipped links to directories are not mentioned in the directory listing.
  Stream<FileSystemEntity> listRecursively() =>
      _DirectoryTraversal(this).listRecursively();
}

/// A recursive directory listing algorithm that follows symlinks carefully.
class _DirectoryTraversal {
  final Directory root;
  final StreamController<FileSystemEntity> _result = StreamController();

  /// The directories currently being traversed.
  ///
  /// These are canonical paths with symlinks resolved, for correct comparison.
  final Set<String> _traversing = {};

  _DirectoryTraversal(this.root);

  Stream<FileSystemEntity> listRecursively() {
    unawaited(_listAndRecurse());
    return _result.stream;
  }

  /// Lists [root] then closes [_result].
  Future<void> _listAndRecurse() async {
    try {
      final resolvedRoot = _ResolvedDirectory.resolve(root);
      _traversing.add(resolvedRoot.canonicalPath);
      await _listAndRecurseOrThrow(resolvedRoot);
    } catch (e, s) {
      _result.addError(e, s);
    } finally {
      await _result.close();
    }
  }

  /// Lists [directory] and its subdirectories.
  ///
  /// A subdirectory is only listed if its canonical path is not already in
  /// [_traversing].
  Future<void> _listAndRecurseOrThrow(_ResolvedDirectory directory) async {
    final subdirectories = <_ResolvedDirectory>[];

    await for (var entity
        in directory.directory.list(recursive: false, followLinks: false)) {
      // Handle links.
      if (entity is Link) {
        // Look up their target and target type.
        final target = entity.targetSync();
        final targetType = FileSystemEntity.typeSync(target);

        if (targetType == FileSystemEntityType.directory) {
          // Add links to directories with their target to [subdirectories].
          subdirectories.add(_ResolvedDirectory(
              directory: Directory(entity.path), canonicalPath: target));
        } else if (targetType == FileSystemEntityType.file) {
          // Output files.
          _result.add(File(entity.path));
        } else {
          // Anything else. Broken links get output with type `Link`.
          _result.add(entity);
        }
        continue;
      }

      // Handle directories.
      if (entity is Directory) {
        // If [directory] is canonical, a subdirectory within it is already
        // canonical.
        //
        // If [directory] is _not_ canonical, construct the canonical path of
        // the subdirectory by joining its basename to
        // [directory.resolvedDirectory].
        final resolvedDirectory = directory.isCanonical
            ? entity.path
            : p.join(directory.canonicalPath, p.basename(entity.path));
        subdirectories.add(_ResolvedDirectory(
            directory: entity, canonicalPath: resolvedDirectory));
        continue;
      }

      // Files and anything else.
      _result.add(entity);
    }

    // Recurse into subdirectories that are not already being traversed.
    for (final directory in subdirectories) {
      if (_traversing.add(directory.canonicalPath)) {
        _result.add(directory.directory);
        await _listAndRecurseOrThrow(directory);
        _traversing.remove(directory.canonicalPath);
      }
    }
  }
}

/// A directory plus its canonical path.
class _ResolvedDirectory {
  final Directory directory;
  final String canonicalPath;

  _ResolvedDirectory({required this.directory, required this.canonicalPath});

  static _ResolvedDirectory resolve(Directory directory) {
    try {
      return _ResolvedDirectory(
          directory: directory,
          canonicalPath: directory.resolveSymbolicLinksSync());
    } on FileSystemException catch (e, s) {
      // The first operation on a directory is to resolve symbolic links, which
      // fails with a general FileSystemException if the file is not found.
      // Convert that into a PathNotFoundException as that makes more sense
      // to the caller, who didn't ask for anything to do with symbolic links.
      if (e.message.contains('Cannot resolve symbolic links') &&
          e.osError?.errorCode == 2) {
        throw Error.throwWithStackTrace(
            PathNotFoundException(directory.path, e.osError!), s);
      }
      rethrow;
    }
  }

  bool get isCanonical => canonicalPath == directory.path;
}
