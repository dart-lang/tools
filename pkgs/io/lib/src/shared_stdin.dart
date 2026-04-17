// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

/// A shared singleton instance of `dart:io`'s [stdin] stream.
///
/// _Unlike_ the normal [stdin] stream, [sharedStdIn] may switch subscribers
/// as long as the previous subscriber cancels before the new subscriber starts
/// listening.
///
/// [SharedStdIn.terminate] *must* be invoked in order to close the underlying
/// connection to [stdin], allowing your program to close automatically without
/// hanging.
final SharedStdIn sharedStdIn = SharedStdIn(stdin);

/// A singleton wrapper around `stdin` that allows new subscribers.
///
/// This class is visible in order to be used as a test harness for mock
/// implementations of `stdin`. In normal programs, [sharedStdIn] should be
/// used directly.
@visibleForTesting
class SharedStdIn extends Stream<List<int>> {
  StreamController<List<int>>? _current;
  StreamSubscription<List<int>>? _sub;

  SharedStdIn([Stream<List<int>>? stream]) {
    _sub = (stream ??= stdin).listen(_onInput);
  }

  /// Returns a future that completes with the next line.
  ///
  /// This is similar to the standard [Stdin.readLineSync], but asynchronous.
  Future<String> nextLine({Encoding encoding = systemEncoding}) =>
      lines(encoding: encoding).first;

  /// Returns the stream transformed as UTF8 strings separated by line breaks.
  ///
  /// This is similar to synchronous code using [Stdin.readLineSync]:
  /// ```dart
  /// while (true) {
  ///   var line = stdin.readLineSync();
  ///   // ...
  /// }
  /// ```
  ///
  /// ... but asynchronous.
  Stream<String> lines({Encoding encoding = systemEncoding}) =>
      transform(utf8.decoder).transform(const LineSplitter());

  void _onInput(List<int> event) => _getCurrent().add(event);

  StreamController<List<int>> _getCurrent() =>
      _current ??= StreamController<List<int>>(
          onCancel: () {
            _current = null;
          },
          sync: true);

  @override
  SharedStdinSubscription listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (_sub == null) {
      throw StateError('Stdin has already been terminated.');
    }
    // ignore: close_sinks
    final controller = _getCurrent();
    if (controller.hasListener) {
      throw StateError(''
          'Subscriber already listening. The existing subscriber must cancel '
          'before another may be added.');
    }
    return controller.stream._listen(
      onData,
      onDone,
      onError,
      cancelOnError,
    );
  }

  /// Terminates the connection to `stdin`, closing all subscription.
  Future<void> terminate() async {
    if (_sub == null) {
      throw StateError('Stdin has already been terminated.');
    }
    await _sub?.cancel();
    await _current?.close();
    _sub = null;
  }
}

/// A subscription to [sharedStdIn] that can be temporarily diverted.
class SharedStdinSubscription implements StreamSubscription<List<int>> {
  final StreamSubscription<List<int>> _subscription;
  void Function(List<int>)? _onData;
  void Function()? _onDone;
  Function? _onError;

  StreamController<List<int>>? _diverted;

  SharedStdinSubscription._(
      this._subscription, this._onData, this._onDone, this._onError);

  /// Temporarily diverts events from this stream into a new stream.
  ///
  /// Buffers events until the returned stream has a listener. After a listener
  /// on the returned stream cancels, subsequent events will be delivered to
  /// the original [onData] callback of this subscription.
  ///
  /// While the returned stream has a listener all events and errors are passed
  /// only to the substream listener's callbacks. If this stream ends while the
  /// returned stream has a listener both the substream and this stream's
  /// [onDone] callback is invoked.
  Stream<List<int>> divert() {
    final diverted = _diverted = StreamController<List<int>>(
      onCancel: () {
        _subscription.onData(_onData);
        _subscription.onError(_onError);
        _subscription.onDone(_onDone);
        _diverted = null;
      },
      onPause: _subscription.pause,
      onResume: _subscription.resume,
      sync: true,
    );

    _subscription.onData(diverted.add);
    _subscription.onError(diverted.addError);
    _subscription.onDone(() {
      diverted.close();
      _onDone?.call();
    });

    return diverted.stream;
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) =>
      _subscription.asFuture(futureValue);

  @override
  Future<void> cancel() async {
    await [_diverted?.close(), _subscription.cancel()].nonNulls.wait;
  }

  @override
  bool get isPaused => _subscription.isPaused;

  @override
  void onData(void Function(List<int> data)? handleData) {
    _onData = handleData;
    if (_diverted == null) _subscription.onData(handleData);
  }

  @override
  void onDone(void Function()? handleDone) {
    _onDone = handleDone;
    if (_diverted == null) _subscription.onDone(handleDone);
  }

  @override
  void onError(Function? handleError) {
    _onError = handleError;
    if (_diverted == null) _subscription.onError(handleError);
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    _subscription.pause(resumeSignal);
  }

  @override
  void resume() {
    _subscription.resume();
  }
}

extension on Stream<List<int>> {
  SharedStdinSubscription _listen(void Function(List<int>)? onData,
          void Function()? onDone, Function? onError, bool? cancelOnError) =>
      SharedStdinSubscription._(
          listen(onData,
              onError: onError, onDone: onDone, cancelOnError: cancelOnError),
          onData,
          onDone,
          onError);
}
