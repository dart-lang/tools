// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  late StreamController<List<int>> streamController;
  late StreamController<List<int>> sinkController;
  late StreamChannel<List<int>> channel;
  setUp(() {
    streamController = StreamController<List<int>>();
    sinkController = StreamController<List<int>>();
    channel =
        StreamChannel<List<int>>(streamController.stream, sinkController.sink);
  });

  group('stream', () {
    test('decodes a single line', () {
      var transformed = channel.transform(newlineDelimited);
      streamController.add(utf8.encode('hello\n'));
      expect(transformed.stream.first, completion(equals('hello')));
    });

    test('decodes multiple lines delivered in one chunk', () {
      var transformed = channel.transform(newlineDelimited);
      streamController.add(utf8.encode('one\ntwo\nthree\n'));
      expect(transformed.stream.take(3).toList(),
          completion(equals(['one', 'two', 'three'])));
    });

    test('decodes a line split across chunks', () async {
      var transformed = channel.transform(newlineDelimited);
      var first = transformed.stream.first;
      streamController.add(utf8.encode('hel'));
      await Future<void>.delayed(Duration.zero);
      streamController.add(utf8.encode('lo\n'));
      expect(await first, equals('hello'));
    });

    test('decodes a multi-byte UTF-8 character split across chunks', () async {
      var transformed = channel.transform(newlineDelimited);
      var first = transformed.stream.first;
      var encoded = utf8.encode('héllo\n');
      // Split in the middle of the 2-byte encoding of "é".
      var splitPoint = encoded.indexOf(0xA9); // second byte of é's encoding
      streamController.add(encoded.sublist(0, splitPoint));
      await Future<void>.delayed(Duration.zero);
      streamController.add(encoded.sublist(splitPoint));
      expect(await first, equals('héllo'));
    });

    test('treats \\r\\n as a line terminator', () {
      var transformed = channel.transform(newlineDelimited);
      streamController.add(utf8.encode('one\r\ntwo\r\n'));
      expect(transformed.stream.take(2).toList(),
          completion(equals(['one', 'two'])));
    });

    test('emits a trailing unterminated line when the stream closes', () async {
      var transformed = channel.transform(newlineDelimited);
      streamController.add(utf8.encode('no newline'));
      unawaited(streamController.close());
      expect(await transformed.stream.toList(), equals(['no newline']));
    });

    test('emits an empty string for a blank line', () {
      var transformed = channel.transform(newlineDelimited);
      streamController.add(utf8.encode('\n'));
      expect(transformed.stream.first, completion(equals('')));
    });

    test('emits a stream error for malformed UTF-8', () {
      var transformed = channel.transform(newlineDelimited);
      // An unpaired continuation byte is invalid UTF-8.
      streamController.add([0x80, 0x0A]);
      expect(transformed.stream.first, throwsFormatException);
    });
  });

  group('sink', () {
    test('appends a newline to each event', () {
      var transformed = channel.transform(newlineDelimited);
      transformed.sink.add('hello');
      expect(sinkController.stream.first,
          completion(equals(utf8.encode('hello\n'))));
    });

    test('UTF-8 encodes non-ASCII content', () {
      var transformed = channel.transform(newlineDelimited);
      transformed.sink.add('héllo');
      expect(sinkController.stream.first,
          completion(equals(utf8.encode('héllo\n'))));
    });

    test('synchronously throws if the data contains a newline', () {
      var transformed = channel.transform(newlineDelimited);
      expect(() => transformed.sink.add('one\ntwo'), throwsArgumentError);
    });

    test('synchronously throws if the data contains a carriage return', () {
      var transformed = channel.transform(newlineDelimited);
      expect(() => transformed.sink.add('one\rtwo'), throwsArgumentError);
    });

    test('closing the transformed sink closes the inner sink', () async {
      var transformed = channel.transform(newlineDelimited);
      unawaited(sinkController.stream.drain<void>());
      await transformed.sink.close();
      expect(sinkController.isClosed, isTrue);
    });
  });

  test('composes with jsonDocument to round-trip a JSON object', () async {
    var transformed =
        channel.transform(newlineDelimited).transform(jsonDocument);

    transformed.sink.add({'foo': 'bar'});
    expect(await sinkController.stream.first,
        equals(utf8.encode('${jsonEncode({'foo': 'bar'})}\n')));

    streamController.add(utf8.encode('${jsonEncode({'baz': 1})}\n'));
    expect(await transformed.stream.first, equals({'baz': 1}));
  });
}
