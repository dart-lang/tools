// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'message_grouper_state.dart';

/// Groups stdin input into messages by interpreting it as
/// base-128 encoded lengths interleaved with raw data.
///
/// The base-128 encoding is in little-endian order, with the high bit set on
/// all bytes but the last.  This was chosen since it's the same as the
/// base-128 encoding used by protobufs, so it allows a modest amount of code
/// reuse at the other end of the protocol.
///
/// Possible future improvements to consider (should a debugging need arise):
/// - Put a magic number at the beginning of the stream.
/// - Use a guard byte between messages to sanity check that the encoder and
///   decoder agree on the encoding of lengths.
class SyncMessageGrouper {
  final _state = new MessageGrouperState();
  final Stdin _stdin;

  SyncMessageGrouper(this._stdin);

  /// Blocks until the next full message is received, and then returns it.
  ///
  /// Returns null at end of file.
  List<int> get next {
    List<int> message;
    while (message == null) {
      var nextByte = _stdin.readByteSync();
      if (nextByte == -1) return null;
      message = _state.handleInput(nextByte);
    }
    return message;
  }
}
