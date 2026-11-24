// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show LineSplitter;

/// Removes the leading whitespace shared by every non-blank line of [source].
///
/// Blank and whitespace-only lines do not affect the shared prefix and become
/// empty. Leading whitespace is compared character-by-character so mixed tabs
/// and spaces only lose the prefix they actually share.
String stripIndentation(String source) {
  if (source.isEmpty) return '';
  final lines = LineSplitter.split(source).toList();

  String? common;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final indent = line.substring(0, line.length - line.trimLeft().length);
    if (common == null) {
      common = indent;
      continue;
    }
    var i = 0;
    while (i < common.length && i < indent.length && common[i] == indent[i]) {
      i++;
    }
    common = common.substring(0, i);
    if (common.isEmpty) break;
  }

  final prefixLength = common?.length ?? 0;
  final dedented = [
    for (final line in lines)
      line.trim().isEmpty ? '' : line.substring(prefixLength),
  ];
  return '${dedented.join('\n')}${source.endsWith('\n') ? '\n' : ''}';
}
