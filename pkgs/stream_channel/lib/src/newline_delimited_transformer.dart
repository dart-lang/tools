// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:async/async.dart';

import '../stream_channel.dart';

/// A [StreamChannelTransformer] that frames UTF-8 text as newline-delimited
/// lines.
///
/// This decodes the transformed channel's stream as UTF-8 and splits it into
/// lines (on `\n`, `\r\n`, or `\r`, following [LineSplitter]), and encodes
/// each string added to the transformed channel's sink as UTF-8 followed by a
/// trailing `\n`.
///
/// This is commonly combined with [jsonDocument] to send and receive
/// newline-delimited JSON (JSONL) over a byte-oriented channel such as
/// standard I/O:
///
/// ```dart
/// var channel = StreamChannel(stdin, stdout)
///     .transform(newlineDelimited)
///     .transform(jsonDocument);
/// ```
///
/// If the channel's stream contains invalid UTF-8, this emits a
/// [FormatException]. If a string containing `\n` or `\r` is added to the
/// sink, this synchronously throws an [ArgumentError], since it couldn't be
/// faithfully represented as a single line.
final StreamChannelTransformer<String, List<int>> newlineDelimited =
    const _NewlineDelimited();

class _NewlineDelimited implements StreamChannelTransformer<String, List<int>> {
  const _NewlineDelimited();

  @override
  StreamChannel<String> bind(StreamChannel<List<int>> channel) {
    var stream =
        channel.stream.transform(utf8.decoder).transform(const LineSplitter());
    var sink = StreamSinkTransformer<String, List<int>>.fromHandlers(
        handleData: (data, sink) {
      if (data.contains('\n') || data.contains('\r')) {
        throw ArgumentError.value(
            data, 'data', 'must not contain a line terminator');
      }
      sink.add(utf8.encode('$data\n'));
    }).bind(channel.sink);
    return StreamChannel.withCloseGuarantee(stream, sink);
  }
}
