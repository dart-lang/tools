// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

/// Result of polling a path.
///
/// If it's a file, the result is combined from the file's "last modification"
/// time and size, so that a change to either can be noticed as a change.
///
/// If the path is not a file, [fileExists] return `false`.
extension type PollResult._(int _value) {
  /// A [PollResult] with [fileExists] `false`.
  factory PollResult.notAFile() => PollResult._(0);

  static Future<PollResult> poll(String path) async {
    final stat = await FileStat.stat(path);
    if (stat.type != FileSystemEntityType.file) return PollResult.notAFile();

    // Construct the poll result from the "last modified" time and size.
    // It should be very likely to change if either changes. Both are 64 bit
    // ints with the interesting bits in the low bits. Swap the 32 bit sections
    // of `microseconds` so the interesting bits don't clash, then XOR them.
    var microseconds = stat.modified.microsecondsSinceEpoch;
    microseconds = microseconds << 32 | microseconds >>> 32;
    return PollResult._(microseconds ^ stat.size);
  }

  /// Whether the path exists and is a file.
  bool get fileExists => _value != 0;
}
