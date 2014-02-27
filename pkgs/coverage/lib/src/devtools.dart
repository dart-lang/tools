// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.src.devtools;

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert' show JSON;

/// An interface to the Chrome dev tools.
class DevTools {
  final WebSocket _socket;
  final Map<int, Completer> _pendingRequests = {};
  int _requestId = 1;

  DevTools._(this._socket) {
    _socket.listen(_handleResponse);
  }

  static Future<DevTools> connect(String host, String port) {
    _getWebsocketDebuggerUrl(response) {
      var json = JSON.decode(response.body);
      if (json.length < 1) throw new StateError('No open pages');
      if (json.length > 1) {
        throw new UnsupportedError('Multiple page support not yet implemented');
      }
      var pageData = json[0];
      var debuggerUrl = pageData['webSocketDebuggerUrl'];
      if (debuggerUrl == null) {
        throw new StateError('Unable to obtain debugger URL');
      }
      return debuggerUrl;
    }

    var url = 'http://$host:$port/json';
    return http.get(url).then((response) {
      var webSocketDebuggerUrl = _getWebsocketDebuggerUrl(response);
      return WebSocket.connect(webSocketDebuggerUrl)
          .then((socket) => new DevTools._(socket));
    });
  }

  Future<List<String>> getIsolateIds() => _request('/isolates/')
      .then((resp) => resp['members'])
      .then((members) => (members == null) ? []
          : members.map((isolate) => isolate['id']).toList());

  Future<String> getCoverage(String isolateId) => _request('$isolateId/coverage')
      .then((resp) => resp['coverage']);

  Future<Map> _request(String query) {
    _pendingRequests[_requestId] = new Completer();
    _socket.add(JSON.encode({
      'id': _requestId,
      'method': 'Dart.observatoryQuery',
      'params': {
        'id': '$_requestId',
        'query': query,
      },
    }));
    return _pendingRequests[_requestId++].future;
  }

  void _handleResponse(String response) {
    var json = JSON.decode(response);
    if (json['method'] == 'Dart.observatoryData') {
      var id = int.parse(json['params']['id']);
      var message = JSON.decode(json['params']['data']);
      _pendingRequests.remove(id).complete(message);
    }
  }

  Future close() =>_socket.close();
}
