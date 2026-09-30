// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Utilities to append or prepend to a stream.
extension Concatenate<T> on Stream<T> {
  /// Emits all values and errors from [next] following all values and errors
  /// from this stream.
  ///
  /// If this stream never finishes, the [next] stream will never get a
  /// listener.
  ///
  /// If this stream is a broadcast stream, the result will be as well.
  /// If a single-subscription follows a broadcast stream it may be listened
  /// to and never canceled since there may be broadcast listeners added later.
  ///
  /// If a broadcast stream follows any other stream it will miss any events or
  /// errors which occur before this stream is done.
  /// If a broadcast stream follows a single-subscription stream, pausing the
  /// stream while it is listening to the second stream will cause events to be
  /// dropped rather than buffered.
  Stream<T> followedBy(Stream<T> next) {
    var controller = isBroadcast
        ? StreamController<T>.broadcast(sync: true)
        : StreamController<T>(sync: true);

    next = isBroadcast && !next.isBroadcast ? next.asBroadcastStream() : next;

    StreamSubscription<T>? subscription;
    var currentStream = this;
    var thisDone = false;
    var secondDone = false;

    late void Function() currentDoneHandler;

    void listen() {
      subscription = currentStream.listen(controller.add,
          onError: controller.addError, onDone: () => currentDoneHandler());
    }

    void onSecondDone() {
      secondDone = true;
      controller.close();
    }

    void onThisDone() {
      thisDone = true;
      currentStream = next;
      currentDoneHandler = onSecondDone;
      listen();
    }

    currentDoneHandler = onThisDone;

    controller.onListen = () {
      assert(subscription == null);
      listen();
      if (!isBroadcast) {
        controller
          ..onPause = () {
            if (!thisDone || !next.isBroadcast) return subscription!.pause();
            subscription!.cancel();
            subscription = null;
          }
          ..onResume = () {
            if (!thisDone || !next.isBroadcast) return subscription!.resume();
            listen();
          };
      }
      controller.onCancel = () {
        if (secondDone) return null;
        var toCancel = subscription!;
        subscription = null;
        return toCancel.cancel();
      };
    };
    return controller.stream;
  }

  /// Emits [initial] before any values or errors from the this stream.
  ///
  /// If this stream is a broadcast stream the result will be as well.
  /// If this stream is a broadcast stream, it is listened to as soon as the
  /// result is listened to. Events it emits before [initial] has been emitted
  /// are held back and emitted after [initial].
  /// [initial] is emitted once, to the listeners of the result at the time it
  /// is due. A listener added later, or one which listens again after
  /// canceling, does not receive it.
  Stream<T> startWith(T initial) => isBroadcast
      ? _startWithBroadcast([initial])
      : startWithStream(Future.value(initial).asStream());

  /// Emits all values in [initial] before any values or errors from this
  /// stream.
  ///
  /// If this stream is a broadcast stream the result will be as well.
  /// If this stream is a broadcast stream, it is listened to as soon as the
  /// result is listened to. Events it emits before all of [initial] has been
  /// emitted are held back and emitted after [initial].
  /// The values of [initial] are emitted once, to the listeners of the result
  /// at the time they are due. A listener added later, or one which listens
  /// again after canceling, does not receive them.
  Stream<T> startWithMany(Iterable<T> initial) => isBroadcast
      ? _startWithBroadcast(initial)
      : startWithStream(Stream.fromIterable(initial));

  Stream<T> _startWithBroadcast(Iterable<T> initial) {
    final controller = StreamController<T>.broadcast(sync: true);
    StreamSubscription<T>? subscription;
    var initialPending = true;
    var deliveryScheduled = false;
    // Whether `subscription` has been paused yet. The source is listened to
    // and paused back-to-back, but if the source's own `onListen` emits or
    // closes synchronously it does so before `pause` has had a chance to run
    // and take effect, so those events need to be held back separately.
    var sourcePaused = false;
    final beforePause = <void Function()>[];

    void deliverInitial() {
      deliveryScheduled = false;
      // Mark the initial values as delivered as soon as delivery is due,
      // even if there's no listener to receive them. Otherwise a listener
      // added later could incorrectly receive them.
      initialPending = false;
      if (!controller.hasListener) return;
      for (var value in initial) {
        if (!controller.hasListener) break;
        controller.add(value);
      }
      final held = beforePause.toList();
      beforePause.clear();
      for (var deliver in held) {
        if (!controller.hasListener) break;
        deliver();
      }
      if (sourcePaused) subscription?.resume();
    }

    void forward(void Function() deliver) {
      if (initialPending && !sourcePaused) {
        beforePause.add(deliver);
      } else {
        deliver();
      }
    }

    controller.onListen = () {
      sourcePaused = false;
      final sub = subscription = listen(
          (value) => forward(() => controller.add(value)),
          onError: (Object error, StackTrace stackTrace) =>
              forward(() => controller.addError(error, stackTrace)),
          onDone: () {
            subscription = null;
            forward(controller.close);
          });
      if (initialPending) {
        sub.pause();
        sourcePaused = true;
        if (!deliveryScheduled) {
          deliveryScheduled = true;
          scheduleMicrotask(deliverInitial);
        }
      }
    };
    controller.onCancel = () {
      final toCancel = subscription;
      subscription = null;
      return toCancel?.cancel();
    };
    return controller.stream;
  }

  /// Emits all values and errors in [initial] before any values or errors from
  /// this stream.
  ///
  /// If this stream is a broadcast stream the result will be as well.
  /// Unlike [startWith] and [startWithMany], this stream is not listened to
  /// until [initial] closes. If this stream is a broadcast stream it will miss
  /// any events which occur before then.
  Stream<T> startWithStream(Stream<T> initial) {
    if (isBroadcast && !initial.isBroadcast) {
      initial = initial.asBroadcastStream();
    }
    return initial.followedBy(this);
  }
}
