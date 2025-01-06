// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  test("pipe() pipes data from each channel's stream into the other's sink",
      () {
    var otherStreamController = StreamController<int>();
    var otherSinkController = StreamController<int>();
    var otherChannel =
        StreamChannel(otherStreamController.stream, otherSinkController.sink);

    var streamController = StreamController<int>();
    var sinkController = StreamController<int>();
    var channel = StreamChannel(streamController.stream, sinkController.sink);

    channel.pipe(otherChannel);

    streamController.add(1);
    streamController.add(2);
    streamController.add(3);
    streamController.close();
    expect(otherSinkController.stream.toList(), completion(equals([1, 2, 3])));

    otherStreamController.add(4);
    otherStreamController.add(5);
    otherStreamController.add(6);
    otherStreamController.close();
    expect(sinkController.stream.toList(), completion(equals([4, 5, 6])));
  });

  test('transform() transforms the channel', () async {
    var streamController = StreamController<List<int>>();
    var sinkController = StreamController<List<int>>();
    var channel = StreamChannel(streamController.stream, sinkController.sink);

    var transformed = channel
        .cast<List<int>>()
        .transform(StreamChannelTransformer.fromCodec(utf8));

    streamController.add([102, 111, 111, 98, 97, 114]);
    unawaited(streamController.close());
    expect(await transformed.stream.toList(), equals(['foobar']));

    transformed.sink.add('fblthp');
    unawaited(transformed.sink.close());
    expect(
        sinkController.stream.toList(),
        completion(equals([
          [102, 98, 108, 116, 104, 112]
        ])));
  });

  test('transformStream() transforms only the stream', () async {
    var streamController = StreamController<String>();
    var sinkController = StreamController<String>();
    var channel = StreamChannel(streamController.stream, sinkController.sink);

    var transformed =
        channel.cast<String>().transformStream(const LineSplitter());

    streamController.add('hello world');
    streamController.add(' what\nis');
    streamController.add('\nup');
    unawaited(streamController.close());
    expect(await transformed.stream.toList(),
        equals(['hello world what', 'is', 'up']));

    transformed.sink.add('fbl\nthp');
    unawaited(transformed.sink.close());
    expect(sinkController.stream.toList(), completion(equals(['fbl\nthp'])));
  });

  test('transformSink() transforms only the sink', () async {
    var streamController = StreamController<String>();
    var sinkController = StreamController<String>();
    var channel = StreamChannel(streamController.stream, sinkController.sink);

    var transformed = channel.cast<String>().transformSink(
        const StreamSinkTransformer.fromStreamTransformer(LineSplitter()));

    streamController.add('fbl\nthp');
    unawaited(streamController.close());
    expect(await transformed.stream.toList(), equals(['fbl\nthp']));

    transformed.sink.add('hello world');
    transformed.sink.add(' what\nis');
    transformed.sink.add('\nup');
    unawaited(transformed.sink.close());
    expect(sinkController.stream.toList(),
        completion(equals(['hello world what', 'is', 'up'])));
  });

  test('changeStream() changes the stream', () {
    var streamController = StreamController<int>();
    var sinkController = StreamController<int>();
    var channel = StreamChannel(streamController.stream, sinkController.sink);

    var newController = StreamController<int>();
    var changed = channel.changeStream((stream) {
      expect(stream, equals(channel.stream));
      return newController.stream;
    });

    newController.add(10);
    newController.close();

    streamController.add(20);
    streamController.close();

    expect(changed.stream.toList(), completion(equals([10])));
  });

  test('changeSink() changes the sink', () {
    var streamController = StreamController<int>();
    var sinkController = StreamController<int>();
    var channel = StreamChannel(streamController.stream, sinkController.sink);

    var newController = StreamController<int>();
    var changed = channel.changeSink((sink) {
      expect(sink, equals(channel.sink));
      return newController.sink;
    });

    expect(newController.stream.toList(), completion(equals([10])));
    streamController.stream.listen(expectAsync1((_) {}, count: 0));

    changed.sink.add(10);
    changed.sink.close();
  });

  group('StreamChannelMixin', () {
    test('can be used as a mixin', () async {
      var channel = StreamChannelMixinAsMixin<int>();
      expect(channel.stream, emitsInOrder([1, 2, 3]));
      channel.sink
        ..add(1)
        ..add(2)
        ..add(3);
      await channel.controller.close();
    });

    test('can be extended', () async {
      var channel = StreamChannelMixinAsSuperclass<int>();
      expect(channel.stream, emitsInOrder([1, 2, 3]));
      channel.sink
        ..add(1)
        ..add(2)
        ..add(3);
      await channel.controller.close();
    });
  });
}

class StreamChannelMixinAsMixin<T> with StreamChannelMixin<T> {
  final controller = StreamController<T>();

  @override
  StreamSink<T> get sink => controller.sink;

  @override
  Stream<T> get stream => controller.stream;
}

class StreamChannelMixinAsSuperclass<T> extends StreamChannelMixin<T> {
  final controller = StreamController<T>();

  @override
  StreamSink<T> get sink => controller.sink;

  @override
  Stream<T> get stream => controller.stream;
}
