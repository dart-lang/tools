// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show LineSplitter;
import 'dart:math' show max;

import 'fenced_code_block.dart';

/// Returns [source] with the content of [block] replaced by [content].
///
/// [content] is the logical content: no container prefix, no indentation,
/// `\n` line endings. This function adds [FencedCodeBlock.linePrefix] back,
/// lengthens the fences if [content] needs it, and uses the line ending of the
/// block's opening fence.
///
/// The [block] must have a closing fence.
String spliceContent(
  String source,
  FencedCodeBlock block,
  String content,
) {
  final close = block.closeFence!;

  final body = _body(block.linePrefix, content, block.newline);
  final contentStart = block.contentSpan.start.offset;
  final contentEnd = block.contentSpan.end.offset;

  final fence = _requiredFenceLength(block, content);
  if (fence == block.fenceLength) {
    return source.replaceRange(contentStart, contentEnd, body);
  }

  final extra = block.fenceChar * (fence - block.fenceLength);
  final open = block.openFence;
  return source
      .replaceRange(close.start.offset, close.start.offset, extra)
      .replaceRange(contentStart, contentEnd, body)
      .replaceRange(open.start.offset, open.start.offset, extra);
}

/// The fence length [block] needs in order to hold [content].
int _requiredFenceLength(FencedCodeBlock block, String content) {
  var longest = 0;
  for (final line in LineSplitter.split(content)) {
    final trimmed = line.trimLeft();
    var run = 0;
    while (run < trimmed.length && trimmed[run] == block.fenceChar) {
      run++;
    }
    longest = max(longest, run);
  }
  return max(block.fenceLength, longest + 1);
}

String _body(String prefix, String content, String newline) {
  if (content.isEmpty) return '';
  final blankPrefix = prefix.trimRight();

  final buffer = StringBuffer();
  for (final line in LineSplitter.split(content)) {
    buffer
      ..write(line.isEmpty ? blankPrefix : '$prefix$line')
      ..write(newline);
  }
  return buffer.toString();
}
