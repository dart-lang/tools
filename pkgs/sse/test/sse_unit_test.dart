// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sse/server/sse_handler.dart';
import 'package:sse/src/server/sse_handler.dart' show closeSink;
import 'package:sse/src/util/id.dart';
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

const _ssePath = '/test';
const _evilOrigin = 'https://evil.example';
const _trustedOrigin = 'https://trusted.example';
const _nullOrigin = 'null';
const _originHeader = 'origin';
const _allowOriginHeader = 'access-control-allow-origin';
const _allowCredentialsHeader = 'access-control-allow-credentials';
const _varyHeader = 'vary';
const _expectedGeneratedIdLength = 32;
const _expectedGeneratedIdBytes = 24;

Future<(Socket, Stream<List<int>>)> _openRawSseGet(
  int port, {
  required String clientId,
  String? origin,
  String? hostHeader,
}) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  final host = hostHeader ?? '127.0.0.1:$port';
  final originLine = origin != null ? 'Origin: $origin\r\n' : '';
  socket.write(
    'GET $_ssePath?sseClientId=$clientId HTTP/1.1\r\n'
    'Host: $host\r\n'
    'Accept: text/event-stream\r\n'
    '$originLine'
    'Connection: keep-alive\r\n'
    '\r\n',
  );
  await socket.flush();
  return (socket, socket.asBroadcastStream());
}

Future<String> _readHttpHeaders(Stream<List<int>> bytes) async {
  final buffer = StringBuffer();
  await for (final chunk in bytes) {
    buffer.write(utf8.decode(chunk));
    if (buffer.toString().contains('\r\n\r\n')) break;
  }
  return buffer.toString();
}

void main() {
  late SseHandler handler;

  group('SSE with server keep-alive', () {
    setUp(() async {
      handler = SseHandler(
        Uri(path: _ssePath),
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

  group('Origin validation and CORS (default policy)', () {
    test('rejects disallowed cross-origin GET and POST requests', () async {
      final sseHandler = SseHandler(Uri.parse(_ssePath));
      final server = await io.serve(
        sseHandler.handler,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() async {
        sseHandler.shutdown();
        await server.close(force: true);
      });

      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final getReq = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}$_ssePath?sseClientId=c1'),
      );
      getReq.headers
        ..set(HttpHeaders.acceptHeader, 'text/event-stream')
        ..set(_originHeader, _evilOrigin);
      final getResp = await getReq.close();

      expect(getResp.statusCode, HttpStatus.forbidden);
      expect(getResp.headers.value(_allowOriginHeader), isNull);
      expect(getResp.headers.value(_allowCredentialsHeader), isNull);
      await getResp.drain<void>();
      expect(sseHandler.numberOfClients, 0);

      // Establish a legitimate connection and verify cross-origin POST cannot
      // inject messages or reflect CORS headers.
      final (legitSocket, legitBytes) = await _openRawSseGet(
        server.port,
        clientId: 'legit',
        origin: 'http://localhost:${server.port}',
      );
      addTearDown(legitSocket.destroy);
      final legitHeaders = await _readHttpHeaders(legitBytes);
      expect(legitHeaders, startsWith('HTTP/1.1 200 OK\r\n'));

      final connection = await sseHandler.connections.next;
      final receivedMessages = <String>[];
      final sub = connection.stream.listen(receivedMessages.add);
      addTearDown(sub.cancel);

      final postReq = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}$_ssePath?sseClientId=legit&messageId=0',
        ),
      );
      postReq.headers
        ..set(_originHeader, _evilOrigin)
        ..contentType = ContentType.text;
      postReq.write('"injected"');
      final postResp = await postReq.close();
      await postResp.drain<void>();

      expect(postResp.statusCode, HttpStatus.forbidden);
      expect(postResp.headers.value(_allowOriginHeader), isNull);
      expect(postResp.headers.value(_allowCredentialsHeader), isNull);
      await pumpEventQueue();
      expect(receivedMessages, isEmpty);
    });

    test('rejects null Origin header on GET and POST', () async {
      final sseHandler = SseHandler(Uri.parse(_ssePath));
      final server = await io.serve(
        sseHandler.handler,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() async {
        sseHandler.shutdown();
        await server.close(force: true);
      });

      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final getReq = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}$_ssePath?sseClientId=c1'),
      );
      getReq.headers
        ..set(HttpHeaders.acceptHeader, 'text/event-stream')
        ..set(_originHeader, _nullOrigin);
      final getResp = await getReq.close();
      expect(getResp.statusCode, HttpStatus.forbidden);
      expect(getResp.headers.value(_allowOriginHeader), isNull);
      await getResp.drain<void>();

      final postReq = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}$_ssePath?sseClientId=c1&messageId=0',
        ),
      );
      postReq.headers.set(_originHeader, _nullOrigin);
      postReq.write('"msg"');
      final postResp = await postReq.close();
      expect(postResp.statusCode, HttpStatus.forbidden);
      expect(postResp.headers.value(_allowOriginHeader), isNull);
      await postResp.drain<void>();
    });

    test(
      'blocks cross-origin reconnection hijack of an active session',
      () async {
        final sseHandler = SseHandler(
          Uri.parse(_ssePath),
          keepAlive: const Duration(seconds: 30),
          ignoreDisconnect: const Duration(seconds: 30),
        );
        final server = await io.serve(
          sseHandler.handler,
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(() async {
          sseHandler.shutdown();
          await server.close(force: true);
        });

        const victimId = 'victim-session-id';
        final (victimSocket, victimBytes) = await _openRawSseGet(
          server.port,
          clientId: victimId,
          origin: 'http://localhost:${server.port}',
        );
        addTearDown(victimSocket.destroy);
        await _readHttpHeaders(victimBytes);

        final connection = await sseHandler.connections.next;
        expect(sseHandler.numberOfClients, 1);

        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final evilReq = await client.getUrl(
          Uri.parse(
            'http://127.0.0.1:${server.port}$_ssePath?sseClientId=$victimId',
          ),
        );
        evilReq.headers
          ..set(HttpHeaders.acceptHeader, 'text/event-stream')
          ..set(_originHeader, _evilOrigin);
        final evilResp = await evilReq.close();
        expect(evilResp.statusCode, HttpStatus.forbidden);
        await evilResp.drain<void>();

        final victimReceived = Completer<String>();
        final sub = utf8.decoder.bind(victimBytes).listen((chunk) {
          if (chunk.contains('for-victim-only') &&
              !victimReceived.isCompleted) {
            victimReceived.complete(chunk);
          }
        });
        addTearDown(sub.cancel);

        connection.sink.add('for-victim-only');
        expect(
          await victimReceived.future.timeout(const Duration(seconds: 5)),
          contains('data: "for-victim-only"'),
        );
      },
    );

    test(
      'allows requests without Origin header and omits CORS headers',
      () async {
        final sseHandler = SseHandler(Uri.parse(_ssePath));
        final server = await io.serve(
          sseHandler.handler,
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(() async {
          sseHandler.shutdown();
          await server.close(force: true);
        });

        final (socket, bytes) = await _openRawSseGet(
          server.port,
          clientId: 'no-origin',
        );
        addTearDown(socket.destroy);
        final rawHeaders = await _readHttpHeaders(bytes);
        expect(rawHeaders, startsWith('HTTP/1.1 200 OK\r\n'));
        expect(rawHeaders.toLowerCase(), isNot(contains(_allowOriginHeader)));
        expect(
          rawHeaders.toLowerCase(),
          isNot(contains(_allowCredentialsHeader)),
        );

        final connection = await sseHandler.connections.next;
        final queue = StreamQueue(connection.stream);

        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final postReq = await client.postUrl(
          Uri.parse(
            'http://127.0.0.1:${server.port}$_ssePath?sseClientId=no-origin&messageId=0',
          ),
        );
        postReq.write('"hello"');
        final postResp = await postReq.close();
        expect(postResp.statusCode, HttpStatus.ok);
        expect(postResp.headers.value(_allowOriginHeader), isNull);
        expect(postResp.headers.value(_allowCredentialsHeader), isNull);
        await postResp.drain<void>();

        expect(await queue.next, 'hello');
      },
    );

    test('allows cross-port loopback origins on loopback hosts by default '
        'and rejects loopback origins on non-loopback hosts', () async {
      final sseHandler = SseHandler(Uri.parse(_ssePath));
      final server = await io.serve(
        sseHandler.handler,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() async {
        sseHandler.shutdown();
        await server.close(force: true);
      });

      for (final loopbackOrigin in [
        'http://localhost:9999',
        'http://127.0.0.1:9999',
        'http://[::1]:9999',
      ]) {
        final (socket, bytes) = await _openRawSseGet(
          server.port,
          clientId: 'peer-$loopbackOrigin',
          origin: loopbackOrigin,
        );
        addTearDown(socket.destroy);
        final rawHeaders = await _readHttpHeaders(bytes);
        expect(rawHeaders, startsWith('HTTP/1.1 200 OK\r\n'));
        expect(
          rawHeaders,
          contains('Access-Control-Allow-Origin: $loopbackOrigin\r\n'),
        );
        expect(
          rawHeaders,
          contains('Access-Control-Allow-Credentials: true\r\n'),
        );
        expect(rawHeaders, contains('Vary: Origin\r\n'));
        await sseHandler.connections.next;
      }

      // Synthetic request targeting a non-loopback Host must not trust a
      // loopback Origin by default.
      final remoteGet = shelf.Request(
        'GET',
        Uri.parse('https://app.example.com$_ssePath?sseClientId=remote'),
        headers: {
          'accept': 'text/event-stream',
          _originHeader: 'http://localhost:9999',
        },
      );
      final remoteResp = await sseHandler.handler(remoteGet);
      expect(remoteResp.statusCode, HttpStatus.forbidden);
    });

    test(
      'rejects cross-site Sec-Fetch-Site when Origin header is absent',
      () async {
        final sseHandler = SseHandler(Uri.parse(_ssePath));
        final server = await io.serve(
          sseHandler.handler,
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(() async {
          sseHandler.shutdown();
          await server.close(force: true);
        });

        final client = HttpClient();
        addTearDown(() => client.close(force: true));

        final getReq = await client.getUrl(
          Uri.parse('http://127.0.0.1:${server.port}$_ssePath?sseClientId=c1'),
        );
        getReq.headers
          ..set(HttpHeaders.acceptHeader, 'text/event-stream')
          ..set('sec-fetch-site', 'cross-site');
        final getResp = await getReq.close();
        expect(getResp.statusCode, HttpStatus.forbidden);
        await getResp.drain<void>();
        expect(sseHandler.numberOfClients, 0);

        final postReq = await client.postUrl(
          Uri.parse(
            'http://127.0.0.1:${server.port}$_ssePath?sseClientId=c1&messageId=0',
          ),
        );
        postReq.headers.set('sec-fetch-site', 'cross-site');
        postReq.write('"blocked"');
        final postResp = await postReq.close();
        expect(postResp.statusCode, HttpStatus.forbidden);
        await postResp.drain<void>();

        // Same-origin Sec-Fetch-Site without Origin (standard same-origin
        // EventSource GET) remains allowed.
        final sameOriginGet = shelf.Request(
          'GET',
          Uri.parse('http://127.0.0.1:${server.port}$_ssePath?sseClientId=c2'),
          headers: {
            'accept': 'text/event-stream',
            'sec-fetch-site': 'same-origin',
          },
          onHijack: (callback) {
            final controller = StreamController<List<int>>();
            callback(StreamChannel(controller.stream, controller));
          },
        );
        await expectLater(
          () => sseHandler.handler(sameOriginGet),
          throwsA(isA<shelf.HijackException>()),
        );
        expect(sseHandler.numberOfClients, 1);
      },
    );

    test('returns 404 for non-SSE GET requests even with bad Origin', () async {
      final sseHandler = SseHandler(Uri.parse(_ssePath));
      final req = shelf.Request(
        'GET',
        Uri.parse('http://127.0.0.1$_ssePath'),
        headers: {_originHeader: _evilOrigin},
      );
      final resp = await sseHandler.handler(req);
      expect(resp.statusCode, HttpStatus.notFound);
    });
  });

  group('Origin validation with allowedOrigins and originCheck', () {
    test('allows configured origins, same-origin, and loopback while rejecting '
        'unlisted external origins', () async {
      final sseHandler = SseHandler(
        Uri.parse(_ssePath),
        allowedOrigins: ['HTTPS://TRUSTED.EXAMPLE'],
      );
      final server = await io.serve(
        sseHandler.handler,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() async {
        sseHandler.shutdown();
        await server.close(force: true);
      });

      // Listed cross-origin succeeds on GET and POST.
      final (trustedSocket, trustedBytes) = await _openRawSseGet(
        server.port,
        clientId: 'trusted',
        origin: _trustedOrigin,
      );
      addTearDown(trustedSocket.destroy);
      final trustedHeaders = await _readHttpHeaders(trustedBytes);
      expect(trustedHeaders, startsWith('HTTP/1.1 200 OK\r\n'));
      expect(
        trustedHeaders,
        contains('Access-Control-Allow-Origin: $_trustedOrigin\r\n'),
      );
      expect(
        trustedHeaders,
        contains('Access-Control-Allow-Credentials: true\r\n'),
      );

      final connection = await sseHandler.connections.next;
      final queue = StreamQueue(connection.stream);

      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final trustedPost = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}$_ssePath?sseClientId=trusted&messageId=0',
        ),
      );
      trustedPost.headers.set(_originHeader, _trustedOrigin);
      trustedPost.write('"from-trusted"');
      final trustedPostResp = await trustedPost.close();
      expect(trustedPostResp.statusCode, HttpStatus.ok);
      expect(trustedPostResp.headers.value(_allowOriginHeader), _trustedOrigin);
      expect(trustedPostResp.headers.value(_allowCredentialsHeader), 'true');
      expect(trustedPostResp.headers.value(_varyHeader), 'Origin');
      await trustedPostResp.drain<void>();
      expect(await queue.next, 'from-trusted');

      // Cross-port loopback remains allowed on loopback hosts even when
      // allowedOrigins (including an empty list) is passed.
      final crossPortPost = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}$_ssePath?sseClientId=trusted&messageId=1',
        ),
      );
      crossPortPost.headers.set(_originHeader, 'http://localhost:9999');
      crossPortPost.write('"from-loopback"');
      final crossPortResp = await crossPortPost.close();
      expect(crossPortResp.statusCode, HttpStatus.ok);
      await crossPortResp.drain<void>();
      expect(await queue.next, 'from-loopback');

      // Unlisted external origin is still rejected.
      final evilPost = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}$_ssePath?sseClientId=trusted&messageId=2',
        ),
      );
      evilPost.headers.set(_originHeader, _evilOrigin);
      evilPost.write('"blocked"');
      final evilResp = await evilPost.close();
      expect(evilResp.statusCode, HttpStatus.forbidden);
      expect(evilResp.headers.value(_allowOriginHeader), isNull);
      await evilResp.drain<void>();

      // Passing empty allowedOrigins keeps loopback working on loopback hosts.
      final emptyAllowed = SseHandler(
        Uri.parse(_ssePath),
        allowedOrigins: const <String>[],
      );
      final loopbackPost = shelf.Request(
        'POST',
        Uri.parse('http://127.0.0.1:8080$_ssePath'),
        headers: {_originHeader: 'http://localhost:9090'},
        body: '"ok"',
      );
      expect(
        (await emptyAllowed.handler(loopbackPost)).statusCode,
        HttpStatus.ok,
      );
    });

    test('supports custom originCheck and rejects malformed origins before '
        'invoking originCheck', () async {
      final checkedOrigins = <String>[];
      final sseHandler = SseHandler(
        Uri.parse(_ssePath),
        originCheck: (origin) {
          checkedOrigins.add(origin);
          return origin.startsWith('chrome-extension://');
        },
      );
      final server = await io.serve(
        sseHandler.handler,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() async {
        sseHandler.shutdown();
        await server.close(force: true);
      });

      const extOrigin = 'chrome-extension://abcdefghijklmnop';
      final (extSocket, extBytes) = await _openRawSseGet(
        server.port,
        clientId: 'ext',
        origin: extOrigin,
      );
      addTearDown(extSocket.destroy);
      final extHeaders = await _readHttpHeaders(extBytes);
      expect(extHeaders, startsWith('HTTP/1.1 200 OK\r\n'));
      expect(
        extHeaders,
        contains('Access-Control-Allow-Origin: $extOrigin\r\n'),
      );
      await sseHandler.connections.next;
      expect(checkedOrigins, [extOrigin]);

      // Non-matching origin rejected when originCheck returns false.
      final deniedPost = shelf.Request(
        'POST',
        Uri.parse('http://127.0.0.1:${server.port}$_ssePath'),
        headers: {_originHeader: _evilOrigin},
        body: '"hi"',
      );
      expect(
        (await sseHandler.handler(deniedPost)).statusCode,
        HttpStatus.forbidden,
      );
      expect(checkedOrigins, [extOrigin, _evilOrigin]);

      // Malformed / null / path-bearing Origin headers are rejected before
      // invoking originCheck.
      for (final badOrigin in [
        _nullOrigin,
        'https://evil.example/with/path',
        'https://user@evil.example',
        'https://evil.example?q=1',
        'https://evil.example#frag',
        'not-a-uri',
      ]) {
        final req = shelf.Request(
          'POST',
          Uri.parse('http://127.0.0.1:${server.port}$_ssePath'),
          headers: {_originHeader: badOrigin},
          body: '"hi"',
        );
        final resp = await sseHandler.handler(req);
        expect(resp.statusCode, HttpStatus.forbidden);
      }
      expect(checkedOrigins, [extOrigin, _evilOrigin]);
    });
  });

  group('generateId', () {
    test(
      'produces 192-bit URL-safe unpadded base64 IDs without collisions',
      () {
        const sampleCount = 1000;
        final urlSafeBase64 = RegExp(r'^[A-Za-z0-9_-]{32}$');
        final seen = <String>{};
        for (var i = 0; i < sampleCount; i++) {
          final id = generateId();
          expect(id.length, _expectedGeneratedIdLength);
          expect(id, matches(urlSafeBase64));
          expect(base64Url.decode(id).length, _expectedGeneratedIdBytes);
          seen.add(id);
        }
        expect(seen.length, sampleCount);
      },
    );
  });
}
