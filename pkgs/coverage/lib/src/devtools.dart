// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.src.devtools;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io';
import 'package:logging/logging.dart';

final Logger _log = new Logger('coverage.src.devtools');

class VMService {
  final _VMWebsocketConnection _connection;

  VMService._(this._connection);

  Future<VM> getVM() async {
    var response = await _connection.request('getVM');
    return new VM.fromJson(response);
  }

  Future<Isolate> getIsolate(String isolateId) async {
    var response =
        await _connection.request('getIsolate', {'isolateId': isolateId});
    return new Isolate.fromJson(response);
  }

  Future<AllocationProfile> getAllocationProfile(String isolateId,
      {bool reset, bool gc}) async {
    var params = {'isolateId': isolateId};
    if (reset != null) {
      params['reset'] = reset;
    }
    if (gc != null) {
      params['gc'] = 'full';
    }
    var response = await _connection.request('getAllocationProfile', params);
    return new AllocationProfile.fromJson(response);
  }

  Future getCoverage(String isolateId, {String targetId}) async {
    var params = {'isolateId': isolateId};
    if (targetId != null) {
      params['targetId'] = targetId;
    }
    var response = await _connection.request('getCoverage', params);
    return new CodeCoverage.fromJson(response);
  }

  Future resume(String isolateId) =>
      _connection.request('resume', {'isolateId': isolateId});

  static Future<VMService> connect(String host, int port) async {
    _log.fine('Connecting to host $host on port $port');

    return connectToVMWebsocket(host, port);
  }

  static Future<VMService> connectToVMWebsocket(String host, int port) async {
    var connection = await _VMWebsocketConnection.connect(host, port);
    return new VMService._(connection);
  }

  Future close() => _connection.close();
}

class VM {
  final String id;
  final String targetCPU;
  final String hostCPU;
  final String version;
  final String pid;
  final List<IsolateRef> isolates;

  VM(this.id, this.targetCPU, this.hostCPU, this.version, this.pid,
      this.isolates);

  factory VM.fromJson(json) => new VM(json['id'], json['targetCPU'],
      json['hostCPU'], json['version'], json['pid'],
      json['isolates'].map((i) => new IsolateRef.fromJson(i)).toList());
}

class IsolateRef {
  final String id;
  final String name;

  IsolateRef(this.id, this.name);

  factory IsolateRef.fromJson(json) => new IsolateRef(json['id'], json['name']);
}

class Isolate {
  final String id;
  final String name;
  final bool pauseOnExit;
  final ServiceEvent pauseEvent;
  bool get paused =>
      pauseOnExit && pauseEvent != null && pauseEvent.eventType == 'PauseExit';

  Isolate(this.id, this.name, this.pauseOnExit, this.pauseEvent);

  factory Isolate.fromJson(json) => new Isolate(json['id'], json['name'],
      json['pauseOnExit'], new ServiceEvent.fromJson(json['pauseEvent']));
}

class ServiceEvent {
  final String eventType;
  final IsolateRef isolate;

  ServiceEvent(this.eventType, this.isolate);

  factory ServiceEvent.fromJson(json) => new ServiceEvent(
      json['eventType'], new IsolateRef.fromJson(json['isolate']));
}

class CodeCoverage {
  final String id;
  final List coverage;

  CodeCoverage(this.id, this.coverage);

  factory CodeCoverage.fromJson(json) =>
      new CodeCoverage(json['id'], json['coverage']);
}

class AllocationProfile {
  final String id;

  AllocationProfile(this.id);

  factory AllocationProfile.fromJson(json) => new AllocationProfile(json['id']);
}

/// Observatory connection via websocket.
class _VMWebsocketConnection {
  final WebSocket _socket;
  final Map<int, Completer> _pendingRequests = {};
  int _requestId = 1;

  _VMWebsocketConnection(this._socket) {
    _socket.listen(_handleResponse);
  }

  static Future<_VMWebsocketConnection> connect(String host, int port) async {
    _log.fine('Connecting to VM via HTTP websocket protocol');
    var uri = 'ws://$host:$port/ws';
    var socket = await WebSocket.connect(uri);
    return new _VMWebsocketConnection(socket);
  }

  Future<Map> request(String method, [Map params = const {}]) {
    _pendingRequests[_requestId] = new Completer();
    var message =
        JSON.encode({'id': _requestId, 'method': method, 'params': params,});
    _log.fine('Send> $message');
    _socket.add(message);
    return _pendingRequests[_requestId++].future;
  }

  Future close() => _socket.close();

  void _handleResponse(String response) {
    _log.fine('Recv< $response');
    var json = JSON.decode(response);
    var id = json['id'];
    if (id is String) {
      // Support for vm version >= 1.11.0
      id = int.parse(id);
    }
    if (id == null || !_pendingRequests.keys.contains(id)) {
      // Suppress unloved messages.
      return;
    }

    var completer = _pendingRequests.remove(id);
    if (completer == null) {
      _log.severe('Failed to pair response with request');
    }

    // Behavior >= Dart 1.11-dev.3
    var error = json['error'];
    if (error != null) {
      var errorObj = new JsonRpcError.fromJson(error);
      completer.completeError(errorObj);
      return;
    }

    var innerResponse = json['result'];
    if (innerResponse == null) {
      // Support for 1.9.0 <= vm version < 1.10.0.
      innerResponse = json['response'];
    }
    if (innerResponse == null) {
      completer.completeError('Failed to get JSON response for message $id');
      return;
    }
    var message;
    if (innerResponse != null) {
      if (innerResponse is Map) {
        // Support for vm version >= 1.11.0
        message = innerResponse;
      } else {
        message = JSON.decode(innerResponse);
      }
    }

    // need to check this for errors in the Dart 1.10 version
    var type = message['type'];
    if (type == 'Error') {
      var errorObj = new Dart_1_10_RpcError.fromJson(message);
      completer.completeError(errorObj);
      return;
    }

    completer.complete(message);
  }
}

abstract class ServiceProtocolErrorBase extends Error {
  String get message;
  bool get isMethodNotFound;
}

// TODO(kevmoo) Remove this logic once 1.11 is stable
// https://github.com/dart-lang/coverage/issues/91
class Dart_1_10_RpcError extends ServiceProtocolErrorBase {
  final String message;
  final bool isMethodNotFound;

  Dart_1_10_RpcError(this.message, this.isMethodNotFound);

  factory Dart_1_10_RpcError.fromJson(Map<String, dynamic> json) {
    assert(json['type'] == 'Error');
    var message = json['message'];

    var isMethodNotFound = message.startsWith('unrecognized method:');

    return new Dart_1_10_RpcError(message, isMethodNotFound);
  }
}

class JsonRpcError extends ServiceProtocolErrorBase {
  final int code;
  final String message;
  final data;

  // http://www.jsonrpc.org/specification
  // -32601	Method not found	The method does not exist / is not available.
  bool get isMethodNotFound => code == -32601;

  JsonRpcError(this.code, this.message, this.data);

  factory JsonRpcError.fromJson(Map<String, dynamic> json) =>
      new JsonRpcError(json['code'], json['message'], json['data']);

  String toString() {
    var msg = 'JsonRpcError: $message';
    if (isMethodNotFound) {
      if (data is Map) {
        var request = data['request'];
        if (request is Map) {
          var method = request['method'];
          if (method != null) {
            msg = '$msg - "$method"';
          }
        }
      }
    }

    return '$msg ($code)';
  }
}
