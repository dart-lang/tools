// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';

import 'message_grouper.dart';
import 'message_grouper_state.dart';

/// Collects stream data into messages by interpreting it as
/// base-128 encoded lengths interleaved with raw data.
class AsyncMessageGrouper implements MessageGrouper {
  /// Current state for reading in messages;
  final _state = new MessageGrouperState();

  /// The input stream.
  final StreamQueue<List<int>> _inputQueue;

  // Whether or not the input queue has already been cancelled.
  bool _inputQueueCancelled = false;

  /// The current buffer.
  final Queue<int> _buffer = new Queue<int>();

  AsyncMessageGrouper(Stream<List<int>> inputStream)
      : _inputQueue = new StreamQueue(inputStream);

  /// Returns the next full message that is received, or null if none are left.
  Future<List<int>> get next async {
    try {
      List<int> message;
      while (message == null &&
          (_buffer.isNotEmpty || await _inputQueue.hasNext)) {
        if (_buffer.isEmpty) _buffer.addAll(await _inputQueue.next);
        var nextByte = _buffer.removeFirst();
        if (nextByte == -1) return null;
        message = _state.handleInput(nextByte);
      }

      // If there is nothing left in the queue then cancel the subscription.
      if (message == null) _cancel();

      return message;
    } catch (e) {
      // It appears we sometimes get an exception instead of -1 as expected when
      // stdin closes, this handles that in the same way (returning a null
      // message)
      return null;
    }
  }

  Future _cancel() {
    if (!_inputQueueCancelled) {
      _inputQueueCancelled = true;
      return _inputQueue.cancel();
    }
    return new Future.value(null);
  }

  /// Stop listening to the stream for further updates.
  Future cancel() => _cancel();
}
