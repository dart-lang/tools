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

    // For pre-1.9.0 VM versions attempt to detect if we're talking to a
    // Chromium remote debugging port or the VM observatory.
    var doDetect = new RegExp(r'^1\.[4-8]\.').hasMatch(Platform.version);
    if (doDetect) {
      var response = await http.get('http://$host:$port/json');
      var json = JSON.decode(response.body);
      if (json is List) {
        return connectToDevtools(host, port);
      }
      return connectToVM(host, port);
    }

    // For VM versions >=1.9.0, always connect via websocket protocol.
    return connectToVMWebsocket(host, port);
  }

  static Future<VMService> connectToVM(String host, int port) async {
    var connection = await _VMConnection.connect(host, port);
    return new VMService._(connection);
  }

  static Future<VMService> connectToVMWebsocket(String host, int port) async {
    var connection = await _VMWebsocketConnection.connect(host, port);
    return new VMService._(connection);
  }

  static Future<VMService> connectToDevtools(String host, int port) async {
    var connection = await _DevtoolsConnection.connect(host, port);
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

String _getLegacyRequest(String request, Map params) {
  if (request == 'getVM') return 'vm';
  if (request == 'getCoverage') return '${params["isolateId"]}/coverage';
  if (request == 'getIsolate') return '${params["isolateId"]}';
  if (request == 'getAllocationProfile') {
    var opts = params['gc'] != null ? '?gc=${params["gc"]}' : '';
    return '${params["isolateId"]}/allocationprofile$opts';
  }
  if (request == 'resume') return '${params["isolateId"]}/debug/resume';
  throw new ArgumentError('Unknown request $request. Params: $params.');
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

  static Future<_Connection> connect(String host, int port) {
    _log.fine('Connecting to VM via HTTP GET protocol');
    var uri = 'http://$host:$port';
    return new Future.value(new _VMConnection(uri));
  }

  Future<Map> request(String request, [Map params = const {}]) async {
    request = _getLegacyRequest(request, params);
    _log.fine('Send> $uri/$request');
    var response = (await http.get('$uri/$request')).body;
    _log.fine('Recv< $response');
    return response.isEmpty ? {} : JSON.decode(response);
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

  static Future<_Connection> connect(String host, int port) async {
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

    var innerResponse = json['result'];
    if (innerResponse == null) {
      // Support for 1.9.0 <= vm version < 1.10.0.
      innerResponse = json['response'];
    }
    if (innerResponse == null) {
      _log.severe('Failed to get JSON response for message $id');
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

  static Future<_Connection> connect(String host, int port) async {
    _log.fine('Connecting to VM via Chromium remote debugging protocol');
    var uri = 'http://$host:$port/json';

    _getWebsocketDebuggerUrl(response) {
      var json =
          JSON.decode(response.body).where((p) => p['type'] == 'page').toList();
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

    var response = await http.get(uri);
    var webSocketDebuggerUrl = _getWebsocketDebuggerUrl(response);
    var socket = await WebSocket.connect(webSocketDebuggerUrl);
    return new _DevtoolsConnection(socket);
  }

  Future<Map> request(String request, [Map params = const {}]) {
    _pendingRequests[_requestId] = new Completer();
    var message = JSON.encode({
      'id': _requestId,
      'method': 'Dart.observatoryQuery',
      'params': {
        'id': '$_requestId',
        'query': _getLegacyRequest(request, params),
      },
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
