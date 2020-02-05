// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

// TODO(cbracken) make generic
/// Retries the specified function with the specified interval and returns
/// the result on successful completion.
Future<dynamic> retry(Future Function() f, Duration interval,
    {Duration timeout}) async {
  var keepGoing = true;

  Future<dynamic> _withTimeout(Future Function() f, {Duration duration}) {
    if (duration == null) {
      return f();
    }

    return f().timeout(duration, onTimeout: () {
      keepGoing = false;
      final msg = duration.inSeconds == 0
          ? '${duration.inMilliseconds}ms'
          : '${duration.inSeconds}s';
      throw StateError('Failed to complete within $msg');
    });
  }

  return _withTimeout(() async {
    while (keepGoing) {
      try {
        return await f();
      } catch (_) {
        if (keepGoing) {
          await Future<dynamic>.delayed(interval);
        }
      }
    }
  }, duration: timeout);
}

/// Scrapes and returns the observatory URI from a string, or null if not found.
///
/// Potentially useful as a means to extract it from log statements.
Uri extractObservatoryUri(String str) {
  const kObservatoryListening = 'Observatory listening on ';
  final msgPos = str.indexOf(kObservatoryListening);
  if (msgPos == -1) return null;
  final startPos = msgPos + kObservatoryListening.length;
  final endPos = str.indexOf(RegExp(r'(\s|$)'), startPos);
  try {
    return Uri.parse(str.substring(startPos, endPos));
  } on FormatException {
    return null;
  }
}

/// Returns an open port by creating a temporary Socket
Future<int> getOpenPort() async {
  ServerSocket socket;

  try {
    socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  } catch (_) {
    // try again v/ V6 only. Slight possibility that V4 is disabled
    socket =
        await ServerSocket.bind(InternetAddress.loopbackIPv6, 0, v6Only: true);
  }

  try {
    return socket.port;
  } finally {
    await socket.close();
  }
}

/// Returns a JSON hit map backward-compatible with pre-1.16.0 SDKs.
Map<String, dynamic> toScriptCoverageJson(Uri scriptUri, Map<int, int> hitMap) {
  final json = <String, dynamic>{};
  final hits = <int>[];
  hitMap.forEach((line, hitCount) {
    hits.add(line);
    hits.add(hitCount);
  });
  json['source'] = '$scriptUri';
  json['script'] = {
    'type': '@Script',
    'fixedId': true,
    'id': 'libraries/1/scripts/${Uri.encodeComponent(scriptUri.toString())}',
    'uri': '$scriptUri',
    '_kind': 'library',
  };
  json['hits'] = hits;
  return json;
}

/// Generates a hash code for two objects.
int hash2(dynamic a, dynamic b) =>
    _finish(_combine(_combine(0, a.hashCode), b.hashCode));

int _combine(int hash, int value) {
  hash = 0x1fffffff & (hash + value);
  hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
  return hash ^ (hash >> 6);
}

int _finish(int hash) {
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash = hash ^ (hash >> 11);
  return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
}
