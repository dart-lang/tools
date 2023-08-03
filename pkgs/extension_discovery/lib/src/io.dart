// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io'
    show
        File,
        FileStat,
        FileSystemEntityType,
        FileSystemException,
        IOException,
        Platform;

const _maxAttempts = 20;

/// When comparing modification timestamps of files to see if A is newer than B,
/// such that data cached in A about B does not need to be recomputed, we
/// required that A is at-least [modificationMaturityDelay] older than B.
///
/// This ensures that if `pub get` is racing with cache writing then we won't
/// rely on the result.
Duration modificationMaturityDelay = Duration(seconds: 5);

/// On windows some renaming files/folders recently created can be problematic
/// as they may be locked by security scanning systems.
///
/// This function will retry [fn] a few times with a short delay, if running on
/// Windows and the error appears to be related to permissions or file locking.
Future<T> _attempt<T>(FutureOr<T> Function() fn) async {
  if (!Platform.isWindows) {
    return await fn();
  }
  var attempts = 0;
  while (true) {
    try {
      await fn();
    } on FileSystemException catch (e) {
      attempts += 1;
      if (attempts >= _maxAttempts) rethrow;

      // Cargo culting error codes from:
      // https://github.com/dart-lang/pub/blob/98565c3e5defcd80c59910795ba3548552102f2c/lib/src/io.dart#L419-L427
      final code = e.osError?.errorCode;
      if (code != 5 && code != 32) rethrow;

      // Sleep a bit a try again.
      await Future.delayed(Duration(milliseconds: 5));
    }
  }
}

extension FileExt on File {
  /// Try to delete this file, ignore errors.
  Future<void> tryDelete() async {
    try {
      await delete();
    } on IOException {
      // pass
    }
  }

  Future<void> reliablyRename(String newPath) =>
      _attempt(() => rename(newPath));
}

extension FileStatExt on FileStat {
  /// Returns `false` if we're pretty certain that the current file was NOT
  /// modified after [other].
  ///
  /// We do this by subtracting 5 seconds from [other], thus, making it more
  /// likely that the current file was _possibly modified_ after [other].
  ///
  /// This, aims to ensure that file where modified within 5 seconds of
  /// eachother then we don't trust the file modification stamps. This mostly
  /// makes sense if someone is updating a file while we're writing the registry
  /// cache file.
  bool isPossiblyModifiedAfter(DateTime other) =>
      modified.isAfter(other.subtract(modificationMaturityDelay));

  /// True, if current [FileStat] is possibly a file (link or file)
  bool get isFileOrLink =>
      type == FileSystemEntityType.file || type == FileSystemEntityType.link;
}
