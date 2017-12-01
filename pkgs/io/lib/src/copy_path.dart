// Copyright 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

bool _doNothing(String from, String to) {
  if (p.canonicalize(from) == p.canonicalize(to)) {
    return true;
  }
  if (p.isWithin(from, to)) {
    throw new ArgumentError('Cannot copy from $from to $to');
  }
  return false;
}

/// Copies all of the files in the [from] directory to [to].
///
/// This is similar to `cp -R <from> <to>`:
/// * Symlinks are supported.
/// * Existing files are over-written, if any.
/// * If [to] is within [from], throws [ArgumentError] (an infinite operation).
/// * If [from] and [to] are canonically the same, no operation occurs.
///
/// Returns a future that completes when complete.
Future<Null> copyPath(String from, String to) async {
  if (_doNothing(from, to)) {
    return;
  }
  await new Directory(to).create(recursive: true);
  await for (final file in new Directory(from).list(recursive: true)) {
    final copyTo = p.join(to, p.relative(file.path, from: from));
    if (file is Directory) {
      await new Directory(copyTo).create(recursive: true);
    } else if (file is File) {
      await new File(file.path).copy(copyTo);
    } else if (file is Link) {
      await new Link(copyTo).create(await file.target(), recursive: true);
    }
  }
}

/// Copies all of the files in the [from] directory to [to].
///
/// This is similar to `cp -R <from> <to>`:
/// * Symlinks are supported.
/// * Existing files are over-written, if any.
/// * If [to] is within [from], throws [ArgumentError] (an infinite operation).
/// * If [from] and [to] are canonically the same, no operation occurs.
///
/// This action is performed synchronously (blocking I/O).
void copyPathSync(String from, String to) {
  if (_doNothing(from, to)) {
    return;
  }
  new Directory(to).createSync(recursive: true);
  for (final file in new Directory(from).listSync(recursive: true)) {
    final copyTo = p.join(to, p.relative(file.path, from: from));
    if (file is Directory) {
      new Directory(copyTo).createSync(recursive: true);
    } else if (file is File) {
      new File(file.path).copySync(copyTo);
    } else if (file is Link) {
      new Link(copyTo).createSync(file.targetSync(), recursive: true);
    }
  }
}
