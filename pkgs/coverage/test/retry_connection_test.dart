// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:test/test.dart';

typedef _RpcHandler =
    FutureOr<void> Function(
      _ClientConnection connection,
      Map<String, dynamic> rpc,
    );

class _ClientConnection {
  _ClientConnection(this.index, this.socket, _RpcHandler onRpc) {
    _subscription = socket.listen((message) {
      final rpc = jsonDecode(message as String) as Map<String, dynamic>;
      onRpc(this, rpc);
    });
  }

  final int index;
  final WebSocket socket;
  late final StreamSubscription<dynamic> _subscription;

  void pause() => _subscription.pause();

  void resume() => _subscription.resume();

  Future<void> close() async {
    await _subscription.cancel();
    await socket.close();
  }

  void reply(Object? id, Map<String, dynamic> result) {
    if (socket.readyState == WebSocket.open) {
      socket.add(jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}));
    }
  }

  void replyError(Object? id, String message) {
    if (socket.readyState == WebSocket.open) {
      socket.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': -32000, 'message': message},
        }),
      );
    }
  }

  void failUnexpectedRpc(Map<String, dynamic> rpc) {
    final message = 'Unexpected RPC on connection $index: ${rpc['method']}';
    replyError(rpc['id'], message);
    fail(message);
  }
}

class _FakeVmServiceServer {
  _FakeVmServiceServer._(this._server);

  final HttpServer _server;
  final List<_ClientConnection> connections = [];

  Uri get uri => Uri.parse('http://127.0.0.1:${_server.port}/');

  static Future<_FakeVmServiceServer> start(_RpcHandler onRpc) async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fakeServer = _FakeVmServiceServer._(httpServer);
    addTearDown(fakeServer.close);

    httpServer.listen((request) async {
      expect(request.uri.path, '/ws');
      final socket = await WebSocketTransformer.upgrade(request);
      fakeServer.connections.add(
        _ClientConnection(fakeServer.connections.length + 1, socket, onRpc),
      );
    });

    return fakeServer;
  }

  Future<void> close() async {
    await _server.close(force: true);
    for (final connection in connections) {
      await connection.close();
    }
  }
}

Map<String, dynamic> _vmResponse(List<String> isolateIds) => {
  'type': 'VM',
  'isolates': [
    for (var i = 0; i < isolateIds.length; i++)
      {
        'type': '@Isolate',
        'id': isolateIds[i],
        'isolateGroupId': 'isolateGroups/${i + 1}',
        'name': 'suite_${i + 1}',
        'number': '${i + 1}',
        'isSystemIsolate': false,
      },
  ],
};

const _emptySourceReport = <String, dynamic>{
  'type': 'SourceReport',
  'ranges': <Object?>[],
  'scripts': <Object?>[],
};

void main() {
  test('disposes failed connection on non-timeout getVM error', () async {
    var reports = 0;
    final server = await _FakeVmServiceServer.start((connection, rpc) {
      final method = rpc['method'];
      if (connection.index == 1) {
        if (method != 'getVM') {
          connection.failUnexpectedRpc(rpc);
        }
        // Return an RPC error while keeping connection 1 open on the server.
        // collect() must dispose and close this failed connection itself.
        connection.replyError(rpc['id'], 'Transient readiness failure');
        return;
      }

      if (method == 'getVM') {
        connection.reply(rpc['id'], _vmResponse(['isolates/1']));
      } else if (method == 'getSourceReport') {
        reports++;
        connection.reply(rpc['id'], _emptySourceReport);
      } else {
        connection.failUnexpectedRpc(rpc);
      }
    });

    final coverage = await collect(
      server.uri,
      false,
      false,
      false,
      {},
      timeout: const Duration(seconds: 5),
    );

    expect(coverage, {'type': 'CodeCoverage', 'coverage': <Object?>[]});
    expect(server.connections.length, 2);
    expect(reports, 1);
    await server.connections.first.socket.done.timeout(
      const Duration(seconds: 1),
      onTimeout: () =>
          fail('Expected collect() to close the failed connection'),
    );
  });

  test(
    'delayed close of a failed attempt does not dispose active retry',
    () async {
      var reports = 0;
      late final _FakeVmServiceServer server;
      server = await _FakeVmServiceServer.start((connection, rpc) async {
        final method = rpc['method'];
        if (connection.index == 1) {
          if (method != 'getVM') {
            connection.failUnexpectedRpc(rpc);
          }
          // Stall getVM past _retryInterval and pause reading so the server
          // withholds its close handshake response until connection 2 has an
          // in-flight getSourceReport RPC.
          connection.pause();
          return;
        }

        if (method == 'getVM') {
          connection.reply(
            rpc['id'],
            _vmResponse(['isolates/1', 'isolates/2']),
          );
        } else if (method == 'getSourceReport') {
          reports++;
          if (reports == 1) {
            // Complete connection 1's close handshake while connection 2's
            // getSourceReport is in flight, delivering connection 1's onDone
            // to the client before the second isolate's RPC completes.
            final first = server.connections.first;
            first.resume();
            await first.socket.close();
            await first.socket.done;
          }
          connection.reply(rpc['id'], _emptySourceReport);
        } else {
          connection.failUnexpectedRpc(rpc);
        }
      });

      final coverage = await collect(
        server.uri,
        false,
        false,
        false,
        {},
        timeout: const Duration(seconds: 5),
      );

      expect(coverage, {'type': 'CodeCoverage', 'coverage': <Object?>[]});
      expect(server.connections.length, 2);
      expect(reports, 2);
    },
  );

  test('retries when peer closes socket during getVM readiness', () async {
    var reports = 0;
    final server = await _FakeVmServiceServer.start((connection, rpc) async {
      final method = rpc['method'];
      if (connection.index == 1) {
        if (method != 'getVM') {
          connection.failUnexpectedRpc(rpc);
        }
        await connection.socket.close();
        return;
      }

      if (method == 'getVM') {
        connection.reply(rpc['id'], _vmResponse(['isolates/1']));
      } else if (method == 'getSourceReport') {
        reports++;
        connection.reply(rpc['id'], _emptySourceReport);
      } else {
        connection.failUnexpectedRpc(rpc);
      }
    });

    final coverage = await collect(
      server.uri,
      false,
      false,
      false,
      {},
      timeout: const Duration(seconds: 5),
    );

    expect(coverage, {'type': 'CodeCoverage', 'coverage': <Object?>[]});
    expect(server.connections.length, 2);
    expect(reports, 1);
  });
}
