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
      // See https://github.com/dart-lang/sdk/issues/61946. Use a copy of the
      // SDK codepath that should convert it to a more specific type.
      if (e.message.contains('Cannot resolve symbolic links')) {
        if (e.osError != null && e.path != null) {
          Error.throwWithStackTrace(
              _fromOSError(e.osError!, e.message, e.path!), s);
        }
      }
      rethrow;
    }
  }

  bool get isCanonical => canonicalPath == directory.path;
}

// Copied from sdk/lib/io/file.dart.
FileSystemException _fromOSError(OSError err, String message, String path) {
  if (Platform.isWindows) {
    switch (err.errorCode) {
      case _errorAccessDenied:
      case _errorCurrentDirectory:
      case _errorWriteProtect:
      case _errorBadLength:
      case _errorSharingViolation:
      case _errorLockViolation:
      case _errorNetworkAccessDenied:
      case _errorDriveLocked:
        return PathAccessException(path, err, message);
      case _errorFileExists:
      case _errorAlreadyExists:
        return PathExistsException(path, err, message);
      case _errorFileNotFound:
      case _errorPathNotFound:
      case _errorInvalidDrive:
      case _errorInvalidName:
      case _errorNoMoreFiles:
      case _errorBadNetpath:
      case _errorBadNetName:
      case _errorBadPathName:
      case _errorFilenameExedRange:
        return PathNotFoundException(path, err, message);
      default:
        return FileSystemException(message, path, err);
    }
  } else {
    switch (err.errorCode) {
      case _ePerm:
      case _eAccess:
        return PathAccessException(path, err, message);
      case _eExist:
        return PathExistsException(path, err, message);
      case _eNoEnt:
        return PathNotFoundException(path, err, message);
      default:
        return FileSystemException(message, path, err);
    }
  }
}

// Copied from sdk/lib/io/common.dart. POSIX.
const _ePerm = 1;
const _eNoEnt = 2;
const _eAccess = 13;
const _eExist = 17;

// Copied from sdk/lib/io/common.dart. Windows.
const _errorFileNotFound = 2;
const _errorPathNotFound = 3;
const _errorAccessDenied = 5;
const _errorInvalidDrive = 15;
const _errorCurrentDirectory = 16;
const _errorNoMoreFiles = 18;
const _errorWriteProtect = 19;
const _errorBadLength = 24;
const _errorSharingViolation = 32;
const _errorLockViolation = 33;
const _errorBadNetpath = 53;
const _errorNetworkAccessDenied = 65;
const _errorBadNetName = 67;
const _errorFileExists = 80;
const _errorDriveLocked = 108;
const _errorInvalidName = 123;
const _errorBadPathName = 161;
const _errorAlreadyExists = 183;
const _errorFilenameExedRange = 206;
