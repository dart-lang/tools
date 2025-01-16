// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

bool _doNothing(String from, String to) {
  if (p.canonicalize(from) == p.canonicalize(to)) {
    return true;
  }
  if (p.isWithin(from, to)) {
    throw ArgumentError('Cannot copy from $from to $to');
  }
  return false;
}

/// Copies all of the files in the [from] directory to [to].
///
/// This is similar to `cp -R <from> <to>`:
/// * Existing files are over-written, if any.
/// * If [to] is within [from], throws [ArgumentError] (an infinite operation).
/// * If [from] and [to] are canonically the same, no operation occurs.
/// * If [deepCopyLinks] is `true` (the default) then links are followed and
///   the content of linked directories and files are copied entirely. If
///   `false` then new [Link] file system entities are created linking to the
///   same target the links under [from].
///
/// Returns a future that completes when complete.
Future<void> copyPath(String from, String to,
    {bool deepCopyLinks = true}) async {
  if (_doNothing(from, to)) {
    return;
  }
  await Directory(to).create(recursive: true);
  await for (final file
      in Directory(from).list(recursive: true, followLinks: deepCopyLinks)) {
    final copyTo = p.join(to, p.relative(file.path, from: from));
    if (file is Directory) {
      await Directory(copyTo).create(recursive: true);
    } else if (file is File) {
      await File(file.path).copy(copyTo);
    } else if (file is Link) {
      await Link(copyTo).create(await file.target(), recursive: true);
    }
  }
}

/// Copies all of the files in the [from] directory to [to].
///
/// This is similar to `cp -R <from> <to>`:
/// * Existing files are over-written, if any.
/// * If [to] is within [from], throws [ArgumentError] (an infinite operation).
/// * If [from] and [to] are canonically the same, no operation occurs.
/// * If [deepCopyLinks] is `true` (the default) then links are followed and
///   the content of linked directories and files are copied entirely. If
///   `false` then new [Link] file system entities are created linking to the
///   same target the links under [from].
///
/// This action is performed synchronously (blocking I/O).
void copyPathSync(String from, String to, {bool deepCopyLinks = true}) {
  if (_doNothing(from, to)) {
    return;
  }
  Directory(to).createSync(recursive: true);
  for (final file in Directory(from)
      .listSync(recursive: true, followLinks: deepCopyLinks)) {
    final copyTo = p.join(to, p.relative(file.path, from: from));
    if (file is Directory) {
      Directory(copyTo).createSync(recursive: true);
    } else if (file is File) {
      File(file.path).copySync(copyTo);
    } else if (file is Link) {
      Link(copyTo).createSync(file.targetSync(), recursive: true);
    }
  }
}
