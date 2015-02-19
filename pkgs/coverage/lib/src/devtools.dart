// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.src.devtools;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final Logger _log = new Logger('coverage.src.devtools');

class VMService {
  final _Connection _connection;

  VMService._(this._connection);

  Future<VM> getVM() =>
      _connection.request('getVM').then((resp) => new VM.fromJson(resp));

  Future<Isolate> getIsolate(String isolateId) {
    return _connection
        .request('getIsolate', {'isolateId': isolateId})
        .then((resp) => new Isolate.fromJson(resp));
  }

  Future<AllocationProfile> getAllocationProfile(String isolateId, {bool reset, bool gc}) {
    var params = {'isolateId': isolateId};
    if (reset != null) {
      params['reset'] = reset;
    }
    if (gc != null) {
      params['gc'] = 'full';
    }
    return _connection
        .request('getAllocationProfile', params)
        .then((resp) => new AllocationProfile.fromJson(resp));
  }

  Future getCoverage(String isolateId, {String targetId}) {
    var params = {'isolateId': isolateId};
    if (targetId != null) {
      params['targetId'] = targetId;
    }
    return _connection
        .request('getCoverage', params)
        .then((resp) => new CodeCoverage.fromJson(resp));
  }

  Future resume(String isolateId) =>
      _connection.request('resume', {'isolateId': isolateId});

  static Future<VMService> connect(String host, String port) {
    _log.fine('Connecting to host $host on port $port');

    // For pre-1.9.0 VM versions attempt to detect if we're talking to a
    // Chromium remote debugging port or the VM observatory.
    var doDetect = new RegExp(r'^1\.[4-8]\.').hasMatch(Platform.version);
    if (doDetect) {
      return http.get('http://$host:$port/json').then((resp) {
        var json = JSON.decode(resp.body);
        if (json is List) {
          return connectToDevtools(host, port);
        }
        return connectToVM(host, port);
      });
    }

    // For VM versions >=1.9.0, always connect via websocket protocol.
    return connectToVMWebsocket(host, port);
  }

  static Future<VMService> connectToVM(String host, String port) {
    return _VMConnection.connect(host, port)
        .then((c) => new VMService._(c));
  }

  static Future<VMService> connectToVMWebsocket(String host, String port) {
    return _VMWebsocketConnection.connect(host, port)
        .then((c) => new VMService._(c));
  }

  static Future<VMService> connectToDevtools(String host, String port) {
    return _DevtoolsConnection.connect(host, port)
        .then((c) => new VMService._(c));
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

  VM(this.id, this.targetCPU, this.hostCPU, this.version, this.pid, this.isolates);

  factory VM.fromJson(json) => new VM(
      json['id'],
      json['targetCPU'],
      json['hostCPU'],
      json['version'],
      json['pid'],
      json['isolates'].map((i) => new IsolateRef.fromJson(i)).toList());
}

class IsolateRef {
  final String id;
  final String name;

  IsolateRef(this.id, this.name);

  factory IsolateRef.fromJson(json) => new IsolateRef(
      json['id'],
      json['name']);
}

class Isolate {
  final String id;
  final String name;
  final bool pauseOnExit;
  final pauseEvent;
  bool get paused => pauseOnExit || (pauseEvent != null);

  Isolate(this.id, this.name, this.pauseOnExit, this.pauseEvent);

  factory Isolate.fromJson(json) => new Isolate(
      json['id'],
      json['name'],
      json['pauseOnExit'],
      json['pauseEvent']);
}

class CodeCoverage {
  final String id;
  final List coverage;

  CodeCoverage(this.id, this.coverage);

  factory CodeCoverage.fromJson(json) => new CodeCoverage(
      json['id'],
      json['coverage']);
}

class AllocationProfile {
  final String id;

  AllocationProfile(this.id);

  factory AllocationProfile.fromJson(json) =>
      new AllocationProfile(json['id']);
}

String _getLegacyRequest(String request, Map params) {
  if (request == 'getVM') return 'vm';
  if (request == 'getCoverage') return '${params["isolateId"]}/coverage';
  if (request == 'getIsolate') return '${params["isolateId"]}';
  if (request == 'getAllocationProfile') {
    var opts = params['gc'] != null ? '?gc=${params["gc"]}' : '';
    return '${params["isolateId"]}/allocationprofile$opts';
  }
  if (request == 'resume') return '${params["isolateId"]}/debug/resume';
}

/// Observatory connection.
abstract class _Connection {
  Future<Map> request(String request, [Map params = const {}]);
  Future close();
}

/// Observatory connection via HTTP GET requests.
class _VMConnection implements _Connection {
  final String uri;

  _VMConnection(this.uri);

  static Future<_Connection> connect(String host, String port) {
    _log.fine('Connecting to VM via HTTP GET protocol');
    var uri = 'http://$host:$port';
    return new Future.value(new _VMConnection(uri));
  }

  Future<Map> request(String request, [Map params = const {}]) {
    request = _getLegacyRequest(request, params);
    _log.fine('Send> $uri/$request');
    return http
        .get('$uri/$request')
        .then((resp) => resp.body)
        .then((resp) {
          _log.fine('Recv< $resp');
          return resp.isEmpty ? {} : JSON.decode(resp);
        });
  }

  Future close() => new Future.value();
}

/// Observatory connection via websocket.
class _VMWebsocketConnection implements _Connection {
  final WebSocket _socket;
  final Map<int, Completer> _pendingRequests = {};
  int _requestId = 1;

  _VMWebsocketConnection(this._socket) {
    _socket.listen(_handleResponse);
  }

  static Future<_Connection> connect(String host, String port) {
    _log.fine('Connecting to VM via HTTP websocket protocol');
    var uri = 'ws://$host:$port/ws';
    return WebSocket.connect(uri)
        .then((socket) => new _VMWebsocketConnection(socket));
  }

  Future<Map> request(String method, [Map params = const {}]) {
    _pendingRequests[_requestId] = new Completer();
    var message = JSON.encode({
      'id': _requestId,
      'method': method,
      'params': params,
    });
    _log.fine('Send> $message');
    _socket.add(message);
    return _pendingRequests[_requestId++].future;
  }

  Future close() => _socket.close();

  void _handleResponse(String response) {
    _log.fine('Recv< $response');
    var json = JSON.decode(response);
    var id = json['id'];
    if (id == null || !_pendingRequests.keys.contains(id)) {
      // Suppress unloved messages.
      return;
    }
    var message = JSON.decode(json['response']);
    var completer = _pendingRequests.remove(id);
    if (completer == null) {
      _log.severe('Failed to pair response with request');
    }
    completer.complete(message);
  }
}

/// Dart VM Observatory connection via Chromium remote debug protocol.
class _DevtoolsConnection implements _Connection {
  final WebSocket _socket;
  final Map<int, Completer> _pendingRequests = {};
  int _requestId = 1;

  _DevtoolsConnection(this._socket) {
    _socket.listen(_handleResponse);
  }

  static Future<_Connection> connect(String host, port) {
    _log.fine('Connecting to VM via Chromium remote debugging protocol');
    var uri = 'http://$host:$port/json';

    _getWebsocketDebuggerUrl(response) {
      var json = JSON.decode(response.body).where((p) => p['type'] == 'page').toList();
      if (json.length < 1) {
        _log.warning('No open pages');
        throw new StateError('No open pages');
      }
      if (json.length > 1) {
        _log.warning('More than one open page. Defaulting to the first one.');
      }
      var pageData = json[0];
      var debuggerUrl = pageData['webSocketDebuggerUrl'];
      if (debuggerUrl == null) {
        throw new StateError('Unable to obtain debugger URL');
      }
      return debuggerUrl;
    }

    return http.get(uri).then((response) {
      var webSocketDebuggerUrl = _getWebsocketDebuggerUrl(response);
      return WebSocket
          .connect(webSocketDebuggerUrl)
          .then((socket) => new _DevtoolsConnection(socket));
    });
  }

  Future<Map> request(String request, [Map params = const {}]) {
    _pendingRequests[_requestId] = new Completer();
    var message = JSON.encode({
      'id': _requestId,
      'method': 'Dart.observatoryQuery',
      'params': {'id': '$_requestId', 'query': _getLegacyRequest(request, params),},
    });
    _log.fine('Send> $message');
    _socket.add(message);
    return _pendingRequests[_requestId++].future;
  }

  Future close() => _socket.close();

  void _handleResponse(String response) {
    _log.fine('Recv< $response');
    var json = JSON.decode(response);
    if (json['method'] == 'Dart.observatoryData') {
      var id = int.parse(json['params']['id']);
      var message = JSON.decode(json['params']['data']);
      _pendingRequests.remove(id).complete(message);
    }
  }
}
