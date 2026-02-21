// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:async';

import 'package:async/async.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:sse/server/sse_handler.dart';
import 'package:sse/src/server/sse_handler.dart' show closeSink;
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

Future<void> sendRequest(
  String method,
  SseHandler handler, {
  Map<String, /* String | List<String> */ Object>? headers,
  Object? body,
  int? messageId,
}) async {
  final streamController = StreamController<List<int>>();

  void onHijack(void Function(StreamChannel<List<int>>) callback) {
    callback(StreamChannel(streamController.stream, streamController));
  }

  final request = shelf.Request(
    method,
    Uri.http('localhost', 'test', {
      'sseClientId': '14560f0c-c207-4245-9c1b-abe9faf8a1b4',
      if (messageId != null) 'messageId': messageId.toString(),
    }),
    headers: headers,
    body: body,
    onHijack: onHijack,
  );
  try {
    await handler.handler(request);
  } on shelf.HijackException {
    // Swallow the expected HijackException.
  }
}

Future<void> createSseConnection(SseHandler handler) async {
  await sendRequest('GET', handler, headers: {'accept': 'text/event-stream'});
}

Future<void> sendMessage(
  SseHandler handler,
  String message,
  int messageId,
) async {
  await sendRequest(
    'POST',
    handler,
    headers: {'origin': 'http://localhost'},
    body: '"$message"',
    messageId: messageId,
  );
}

void main() {
  late SseHandler handler;

  group('SSE with server keep-alive', () {
    setUp(() async {
      handler = SseHandler(
        Uri(path: '/test'),
        keepAlive: const Duration(seconds: 5),
        ignoreDisconnect: const Duration(seconds: 5),
      );
    });

    tearDown(() async {});

    test('handles out of order disconnect and reconnect', () async {
      var lastMessageId = -1;
      expect(handler.numberOfClients, 0);

      await createSseConnection(handler);

      var connection = await handler.connections.next;
      expect(handler.numberOfClients, 1);

      var queue = StreamQueue(connection.stream);

      await sendMessage(handler, 'baz', ++lastMessageId);
      expect(await queue.next, 'baz');

      await sendMessage(handler, 'bar', ++lastMessageId);
      expect(await queue.next, 'bar');

      // Simulate an out of order disconnect and reconnect by sending the create
      // connection request before the close event
      await createSseConnection(handler);
      closeSink(connection);

      await sendMessage(handler, 'foo', ++lastMessageId);
      expect(await queue.next, 'foo');

      await sendMessage(handler, 'dart', ++lastMessageId);
      expect(await queue.next, 'dart');

      expect(handler.numberOfClients, 1);
    });
  }, timeout: const Timeout(Duration(seconds: 120)));
}
