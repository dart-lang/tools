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
  var disconnector;
  var channel;
  setUp(() {
    streamController = new StreamController();
    sinkController = new StreamController();
    disconnector = new Disconnector();
    channel = new StreamChannel.withGuarantees(
            streamController.stream, sinkController.sink)
        .transform(disconnector);
  });

  group("before disconnection", () {
    test("forwards events from the sink as normal", () {
      channel.sink.add(1);
      channel.sink.add(2);
      channel.sink.add(3);
      channel.sink.close();

      expect(sinkController.stream.toList(), completion(equals([1, 2, 3])));
    });

    test("forwards events to the stream as normal", () {
      streamController.add(1);
      streamController.add(2);
      streamController.add(3);
      streamController.close();

      expect(channel.stream.toList(), completion(equals([1, 2, 3])));
    });

    test("events can't be added when the sink is explicitly closed", () {
      sinkController.stream.listen(null); // Work around sdk#19095.

      expect(channel.sink.close(), completes);
      expect(() => channel.sink.add(1), throwsStateError);
      expect(() => channel.sink.addError("oh no"), throwsStateError);
      expect(() => channel.sink.addStream(new Stream.fromIterable([])),
          throwsStateError);
    });

    test("events can't be added while a stream is being added", () {
      var controller = new StreamController();
      channel.sink.addStream(controller.stream);

      expect(() => channel.sink.add(1), throwsStateError);
      expect(() => channel.sink.addError("oh no"), throwsStateError);
      expect(() => channel.sink.addStream(new Stream.fromIterable([])),
          throwsStateError);
      expect(() => channel.sink.close(), throwsStateError);

      controller.close();
    });
  });

  test("cancels addStream when disconnected", () async {
    var canceled = false;
    var controller = new StreamController(onCancel: () {
      canceled = true;
    });
    expect(channel.sink.addStream(controller.stream), completes);
    disconnector.disconnect();

    await pumpEventQueue();
    expect(canceled, isTrue);
  });

  group("after disconnection", () {
    setUp(() => disconnector.disconnect());

    test("closes the inner sink and ignores events to the outer sink", () {
      channel.sink.add(1);
      channel.sink.add(2);
      channel.sink.add(3);
      channel.sink.close();
 
      expect(sinkController.stream.toList(), completion(isEmpty));
    });

    test("closes the stream", () {
      expect(channel.stream.toList(), completion(isEmpty));
    });

    test("completes done", () {
      sinkController.stream.listen(null); // Work around sdk#19095.
      expect(channel.sink.done, completes);
    });
 
    test("still emits state errors after explicit close", () {
      sinkController.stream.listen(null); // Work around sdk#19095.
      expect(channel.sink.close(), completes);

      expect(() => channel.sink.add(1), throwsStateError);
      expect(() => channel.sink.addError("oh no"), throwsStateError);
    });
  });
}
