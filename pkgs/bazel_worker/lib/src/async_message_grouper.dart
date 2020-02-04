// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';
import 'package:pedantic/pedantic.dart';

import 'message_grouper.dart';
import 'message_grouper_state.dart';

/// Collects stream data into messages by interpreting it as
/// base-128 encoded lengths interleaved with raw data.
class AsyncMessageGrouper implements MessageGrouper {
  /// Current state for reading in messages;
  final _state = MessageGrouperState();

  /// The input stream.
  final StreamQueue<List<int>> _inputQueue;

  /// The current buffer.
  final Queue<int> _buffer = Queue<int>();

  /// Completes after [cancel] is called or [inputStream] is closed.
  Future<void> get done => _done.future;
  final _done = Completer<void>();

  AsyncMessageGrouper(Stream<List<int>> inputStream)
      : _inputQueue = StreamQueue(inputStream);

  /// Returns the next full message that is received, or null if none are left.
  @override
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
      if (message == null) unawaited(cancel());

      return message;
    } catch (e) {
      // It appears we sometimes get an exception instead of -1 as expected when
      // stdin closes, this handles that in the same way (returning a null
      // message)
      return null;
    }
  }

  /// Stop listening to the stream for further updates.
  Future cancel() {
    if (!_done.isCompleted) {
      _done.complete(null);
      return _inputQueue.cancel();
    }
    return done;
  }
}
