// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../event.dart';
import '../../watch_event.dart';

/// An absolute file path.
extension type AbsolutePath(String _string) {
  /// Whether this immediate parent directory of this path is [directory].
  bool isIn(AbsolutePath directory) => p.dirname(_string) == directory._string;

  /// This path relative to [root].
  ///
  /// Returns the empty string if this path is [root].
  ///
  /// Otherwise, throws if this path does not start with [root].
  RelativePath relativeTo(AbsolutePath root) {
    if (!_string.startsWith(root._string)) throw ArgumentError(root);
    if (_string == root._string) return RelativePath('');
    return RelativePath(_string.substring(root._string.length + 1));
  }

  /// The last path segment of this path.
  RelativePath get basename => RelativePath(p.basename(_string));

  /// Lists the directory at this path, ignoring symlinks.
  List<FileSystemEntity> listSync() =>
      Directory(_string).listSync(followLinks: false);

  /// Watches the directory at this path.
  Stream<FileSystemEvent> watch() => Directory(_string).watch();

  /// Gets the [FileStat] for this path.
  FileStat statSync() => FileStat.statSync(_string);

  /// Returns this path followed by [path].
  AbsolutePath append(RelativePath path) =>
      AbsolutePath('$_string/${path._string}');

  /// Add event for this path.
  WatchEvent get addEvent => WatchEvent(ChangeType.ADD, _string);

  /// Modify event for this path.
  WatchEvent get modifyEvent => WatchEvent(ChangeType.MODIFY, _string);

  /// Remove event for this path.
  WatchEvent get removeEvent => WatchEvent(ChangeType.REMOVE, _string);
}

extension FileSystemEntityExtensions on FileSystemEntity {
  /// The event path relative to [root].
  ///
  /// Throws if not under [root].
  RelativePath pathRelativeTo(AbsolutePath root) =>
      AbsolutePath(path).relativeTo(root);
}

extension EventExtensions on Event {
  /// The event [path] as an [AbsolutePath].
  AbsolutePath get absolutePath => AbsolutePath(path);

  /// The event [path] relative to [root].
  RelativePath pathRelativeTo(AbsolutePath root) =>
      AbsolutePath(path).relativeTo(root);

  /// Whether the event path parent directory is exactly [directory].
  bool isIn(AbsolutePath directory) => AbsolutePath(path).isIn(directory);
}

/// A relative file path.
extension type RelativePath(String _string) {}
