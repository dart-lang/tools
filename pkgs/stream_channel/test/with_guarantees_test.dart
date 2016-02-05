// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  var streamController;
  var sinkController;
  var channel;
  setUp(() {
    streamController = new StreamController();
    sinkController = new StreamController();
    channel = new StreamChannel.withGuarantees(
        streamController.stream, sinkController.sink);
  });

  group("with a broadcast stream", () {
    setUp(() {
      streamController = new StreamController.broadcast();
      channel = new StreamChannel.withGuarantees(
          streamController.stream, sinkController.sink);
    });

    test("buffers events", () async {
      streamController.add(1);
      streamController.add(2);
      streamController.add(3);
      await pumpEventQueue();

      expect(channel.stream.toList(), completion(equals([1, 2, 3])));
      streamController.close();
    });

    test("only allows a single subscription", () {
      channel.stream.listen(null);
      expect(() => channel.stream.listen(null), throwsStateError);
    });
  });

  test("closing the event sink causes the stream to close before it emits any "
      "more events", () {
    streamController.add(1);
    streamController.add(2);
    streamController.add(3);

    expect(channel.stream.listen(expectAsync((event) {
      if (event == 2) channel.sink.close();
    }, count: 2)).asFuture(), completes);
  });

  test("after the stream closes, the sink ignores events", () async {
    streamController.close();

    // Wait for the done event to be delivered.
    await channel.stream.toList();
    channel.sink.add(1);
    channel.sink.add(2);
    channel.sink.add(3);
    channel.sink.close();

    // None of our channel.sink additions should make it to the other endpoint.
    sinkController.stream.listen(
        expectAsync((_) {}, count: 0),
        onDone: expectAsync(() {}, count: 0));
    await pumpEventQueue();
  });

  test("canceling the stream's subscription has no effect on the sink",
      () async {
    channel.stream.listen(null).cancel();
    await pumpEventQueue();

    channel.sink.add(1);
    channel.sink.add(2);
    channel.sink.add(3);
    channel.sink.close();
    expect(sinkController.stream.toList(), completion(equals([1, 2, 3])));
  });

  test("canceling the stream's subscription doesn't stop a done event",
      () async {
    channel.stream.listen(null).cancel();
    await pumpEventQueue();

    streamController.close();
    await pumpEventQueue();

    channel.sink.add(1);
    channel.sink.add(2);
    channel.sink.add(3);
    channel.sink.close();

    // The sink should be ignoring events because the stream closed.
    sinkController.stream.listen(
        expectAsync((_) {}, count: 0),
        onDone: expectAsync(() {}, count: 0));
    await pumpEventQueue();
  });

  test("forwards errors to the other endpoint", () {
    channel.sink.addError("error");
    expect(sinkController.stream.first, throwsA("error"));
  });

  test("Sink.done completes once the stream is done", () {
    channel.stream.listen(null);
    expect(channel.sink.done, completes);
    streamController.close();
  });

  group("with allowSinkErrors: false", () {
    setUp(() {
      streamController = new StreamController();
      sinkController = new StreamController();
      channel = new StreamChannel.withGuarantees(
          streamController.stream, sinkController.sink, allowSinkErrors: false);
    });

    test("forwards errors to Sink.done but not the stream", () {
      channel.sink.addError("oh no");
      expect(channel.sink.done, throwsA("oh no"));
      sinkController.stream.listen(null,
          onError: expectAsync((_) {}, count: 0));
    });

    test("adding an error causes the stream to emit a done event", () {
      expect(channel.sink.done, throwsA("oh no"));

      streamController.add(1);
      streamController.add(2);
      streamController.add(3);

      expect(channel.stream.listen(expectAsync((event) {
        if (event == 2) channel.sink.addError("oh no");
      }, count: 2)).asFuture(), completes);
    });

    test("adding an error closes the inner sink", () {
      channel.sink.addError("oh no");
      expect(channel.sink.done, throwsA("oh no"));
      expect(sinkController.stream.toList(), completion(isEmpty));
    });
  });
}
