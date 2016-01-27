// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import '../stream_channel.dart';

/// A [StreamChannel] that communicates over a [ReceivePort]/[SendPort] pair,
/// presumably with another isolate.
///
/// The remote endpoint doesn't necessarily need to be running an
/// [IsolateChannel]. This can be used with any two ports, although the
/// [StreamChannel] semantics mean that this class will treat them as being
/// paired (for example, closing the [sink] will cause the [stream] to stop
/// emitting events).
///
/// The underlying isolate ports have no notion of closing connections. This
/// means that [stream] won't close unless [sink] is closed, and that closing
/// [sink] won't cause the remote endpoint to close. Users should take care to
/// ensure that they always close the [sink] of every [IsolateChannel] they use
/// to avoid leaving dangling [ReceivePort]s.
class IsolateChannel<T> extends StreamChannelMixin<T> {
  /// The port that produces incoming messages.
  ///
  /// This is wrapped in a [StreamView] to produce [stream].
  final ReceivePort _receivePort;

  /// The port that sends outgoing messages.
  final SendPort _sendPort;

  Stream<T> get stream => _stream;
  final Stream<T> _stream;

  StreamSink<T> get sink => _sink;
  _SendPortSink<T> _sink;

  /// Creates a stream channel that receives messages from [receivePort] and
  /// sends them over [sendPort].
  IsolateChannel(ReceivePort receivePort, this._sendPort)
      : _receivePort = receivePort,
        _stream = new StreamView<T>(receivePort) {
    _sink = new _SendPortSink<T>(this);
  }
}

/// The sink for [IsolateChannel].
///
/// [SendPort] doesn't natively implement any sink API, so this adds that API as
/// a wrapper. Closing this just closes the [ReceivePort].
class _SendPortSink<T> implements StreamSink<T> {
  /// The channel that this sink is for.
  final IsolateChannel _channel;

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

  _SendPortSink(this._channel);

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
    _channel._sendPort.send(data);
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

    _channel._receivePort.close();

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
