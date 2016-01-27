// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

/// The sink for [IsolateChannel].
///
/// [SendPort] doesn't natively implement any sink API, so this adds that API as
/// a wrapper. Closing this just closes the [ReceivePort].
class SendPortSink<T> implements StreamSink<T> {
  /// The port that produces incoming messages.
  ///
  /// This is wrapped in a [StreamView] to produce [stream].
  final ReceivePort _receivePort;

  /// The port that sends outgoing messages.
  final SendPort _sendPort;

  Future get done => _doneCompleter.future;
  final _doneCompleter = new Completer();

  /// Whether [done] has been completed.
  ///
  /// This is distinct from [_closed] because [done] can complete with an error
  /// without the user explicitly calling [close].
  bool get _isDone => _doneCompleter.isCompleted;

  /// Whether the user has called [close].
  bool _closed = false;

  /// Whether we're currently adding a stream with [addStream].
  bool _inAddStream = false;

  SendPortSink(this._receivePort, this._sendPort);

  void add(T data) {
    if (_closed) throw new StateError("Cannot add event after closing.");
    if (_inAddStream) {
      throw new StateError("Cannot add event while adding stream.");
    }
    if (_isDone) return;

    _add(data);
  }

  /// A helper for [add] that doesn't check for [StateError]s.
  ///
  /// This is called from [addStream], so it shouldn't check [_inAddStream].
  void _add(T data) {
    _sendPort.send(data);
  }

  void addError(error, [StackTrace stackTrace]) {
    if (_closed) throw new StateError("Cannot add event after closing.");
    if (_inAddStream) {
      throw new StateError("Cannot add event while adding stream.");
    }

    _close(error, stackTrace);
  }

  Future close() {
    if (_inAddStream) {
      throw new StateError("Cannot close sink while adding stream.");
    }

    _closed = true;
    return _close();
  }

  /// A helper for [close] that doesn't check for [StateError]s.
  ///
  /// This is called from [addStream], so it shouldn't check [_inAddStream]. It
  /// also forwards [error] and [stackTrace] to [done] if they're passed.
  Future _close([error, StackTrace stackTrace]) {
    if (_isDone) return done;

    _receivePort.close();

    if (error != null) {
      _doneCompleter.completeError(error, stackTrace);
    } else {
      _doneCompleter.complete();
    }

    return done;
  }

  Future addStream(Stream<T> stream) {
    if (_closed) throw new StateError("Cannot add stream after closing.");
    if (_inAddStream) {
      throw new StateError("Cannot add stream while adding stream.");
    }
    if (_isDone) return new Future.value();

    _inAddStream = true;
    var completer = new Completer.sync();
    stream.listen(_add,
        onError: (error, stackTrace) {
          _close(error, stackTrace);
          completer.complete();
        },
        onDone: completer.complete,
        cancelOnError: true);
    return completer.future.then((_) {
      _inAddStream = false;
    });
  }
}
