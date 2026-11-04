// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// A utility to end a stream based on an external trigger.
extension TakeUntil<T> on Stream<T> {
  /// Takes values from this stream which are emitted before [trigger]
  /// completes.
  ///
  /// Completing [trigger] differs from canceling a subscription in that values
  /// which are emitted before the trigger, but have further asynchronous delays
  /// in transformations following the `takeUntil`, will still go through.
  /// Cancelling a subscription immediately stops values.
  ///
  /// When [trigger] completes, the subscription on this stream is canceled,
  /// and the result stream closes after that cancel has completed.
  ///
  /// If [trigger] completes as an error, the error will be forwarded through
  /// the result stream before the result stream closes.
  ///
  /// If [trigger] completes as a value or as an error after this stream has
  /// already ended, the completion will be ignored.
  ///
  /// If [trigger] completes as a value or as an error before the returned
  /// stream has been listened to, this stream will not be listened to at all.
  /// If the returned stream is a broadcast stream, because this stream is,
  /// any error from [trigger] will become an uncaught error on the returned
  /// stream.
  /// If the returned stream is a single-subscription stream, an error from
  /// [trigger] will be buffered until the stream is listened to.
  Stream<T> takeUntil(Future<void> trigger) {
    const int stateUnlistened = 0;
    const int stateActive = 1;
    const int stateCancelling = 2;
    const int stateDone = 3;

    var controller = isBroadcast
        ? StreamController<T>.broadcast(sync: true)
        : StreamController<T>(sync: true);

    var state = stateUnlistened;

    StreamSubscription<T>? subscription;

    // Set if `cancel` is called during trigger cancellation.
    Completer<void>? cancelCompleter;

    /// Ends the result stream because [trigger] completed.
    ///
    /// Cancels the source subscription and waits for the cancel to complete
    /// before adding [error], if any, and closing the result stream.
    ///
    /// Called as both the [trigger]'s value and error callbacks.
    void finish([Object? error, StackTrace? stackTrace]) async {
      // If stream has run and ended, do nothing.
      if (state == stateDone) return;
      // If `trigger` completed with error, report it.
      if (stackTrace != null) controller.addError(error!, stackTrace);
      // Client may have called cancel, fx due to `cancelOnError`.
      if (state == stateDone) return;
      // If subscription is open, cancel it.
      if (subscription case var activeSubscription?) {
        state = stateCancelling;
        subscription = null;
        try {
          await activeSubscription.cancel();
          if (cancelCompleter case var cancelled?) {
            // If client has called `cancel` while waiting, complete it.
            assert(state == stateDone);
            cancelled.complete(null);
            return;
          }
        } catch (cancelError, cancelStackTrace) {
          if (cancelCompleter case var cancelled?) {
            assert(state == stateDone);
            cancelled.completeError(cancelError, cancelStackTrace);
            return;
          }
          controller.addError(cancelError, cancelStackTrace);
        }
      }
      state = stateDone;
      unawaited(controller.close());
    }

    trigger.then(finish, onError: finish);

    void onDone() {
      if (state == stateDone) return;
      subscription = null;
      state = stateDone;
      controller.close();
    }

    Future<void>? onCancel() {
      if (state == stateDone) return null;
      if (state == stateCancelling) {
        assert(subscription == null);
        state = stateDone;
        // If cancelled while `trigger`'s `subscription.cancel` is running,
        // forward the result to the future returned here,
        // so no error is lost.
        return (cancelCompleter = Completer<void>.sync()).future;
      }
      assert(state == stateActive); // Trigger hasn't triggered yet.
      var activeSubscription = subscription!;
      subscription = null;
      state = isBroadcast ? stateActive : stateDone;
      return activeSubscription.cancel();
    }

    controller.onListen = () {
      if (state >= stateCancelling) return;
      // If called more than once, the stream is broadcast.
      // If so, the state starts as `stateActive` on the second run.
      assert(subscription == null);
      var activeSubscription =
          listen(controller.add, onError: controller.addError, onDone: onDone);
      subscription = activeSubscription;
      if (!isBroadcast) {
        // The activeSubscription will be the only subscription.
        controller
          ..onPause = activeSubscription.pause
          ..onResume = activeSubscription.resume;
      }
      if (state == stateUnlistened) {
        state = stateActive;
        controller.onCancel = onCancel;
      }
    };
    return controller.stream;
  }
}
