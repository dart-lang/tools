// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:vm_service_lib/vm_service_lib.dart';
import 'util.dart';

const _retryInterval = Duration(milliseconds: 200);

/// Collects coverage for all isolates in the running VM.
///
/// Collects a hit-map containing merged coverage for all isolates in the Dart
/// VM associated with the specified [serviceUri]. Returns a map suitable for
/// input to the coverage formatters that ship with this package.
///
/// [serviceUri] must specify the http/https URI of the service port of a
/// running Dart VM and must not be null.
///
/// If [resume] is true, all isolates will be resumed once coverage collection
/// is complate.
///
/// If [waitPaused] is true, collection will not begin until all isolates are
/// in the paused state.
Future<Map<String, dynamic>> collect(
    Uri serviceUri, bool resume, bool waitPaused, bool includeDart,
    {Duration timeout}) async {
  if (serviceUri == null) throw ArgumentError('serviceUri must not be null');

  // Create websocket URI. Handle any trailing slashes.
  final pathSegments =
      serviceUri.pathSegments.where((c) => c.isNotEmpty).toList()..add('ws');
  final uri = serviceUri.replace(scheme: 'ws', pathSegments: pathSegments);

  VmService service;
  await retry(() async {
    try {
      final options = const CompressionOptions(enabled: false);
      final socket = await WebSocket.connect('$uri', compression: options);
      final controller = StreamController<String>();
      socket.listen((dynamic data) => controller.add(data));
      service = VmService(
          controller.stream, (String message) => socket.add(message),
          log: StdoutLog(), disposeHandler: () => socket.close());
      await service.getVM().timeout(_retryInterval);
    } on TimeoutException {
      service.dispose();
      rethrow;
    }
  }, _retryInterval, timeout: timeout);
  try {
    if (waitPaused) {
      await _waitIsolatesPaused(service, timeout: timeout);
    }

    return await _getAllCoverage(service, includeDart);
  } finally {
    if (resume) {
      await _resumeIsolates(service);
    }
    service.dispose();
  }
}

Future<Map<String, dynamic>> _getAllCoverage(
    VmService service, bool includeDart) async {
  final vm = await service.getVM();
  final allCoverage = <Map<String, dynamic>>[];

  for (var isolateRef in vm.isolates) {
    final SourceReport report = await service.getSourceReport(
      isolateRef.id,
      <String>[SourceReportKind.kCoverage],
      forceCompile: true,
    );
    final coverage =
        await _getCoverageJson(service, isolateRef, report, includeDart);
    allCoverage.addAll(coverage);
  }
  return <String, dynamic>{'type': 'CodeCoverage', 'coverage': allCoverage};
}

Future _resumeIsolates(VmService service) async {
  final vm = await service.getVM();
  for (var isolateRef in vm.isolates) {
    final Isolate isolate = await service.getIsolate(isolateRef.id);
    if (isolate.pauseEvent.kind != EventKind.kResume) {
      await service.resume(isolateRef.id);
    }
  }
}

Future _waitIsolatesPaused(VmService service, {Duration timeout}) async {
  final pauseEvents = Set<String>.from(<String>[
    EventKind.kPauseStart,
    EventKind.kPauseException,
    EventKind.kPauseExit,
    EventKind.kPauseInterrupted,
    EventKind.kPauseBreakpoint
  ]);

  Future allPaused() async {
    final VM vm = await service.getVM();
    for (var isolateRef in vm.isolates) {
      final Isolate isolate = await service.getIsolate(isolateRef.id);
      if (!pauseEvents.contains(isolate.pauseEvent.kind)) {
        throw "Unpaused isolates remaining.";
      }
    }
  }

  return retry(allPaused, _retryInterval, timeout: timeout);
}

/// Returns the line number to which the specified token position maps.
///
/// Performs a binary search within the script's token position table to locate
/// the line in question.
int _getLineFromTokenPos(Script script, int tokenPos) {
  // TODO(cbracken): investigate whether caching this lookup results in
  // significant performance gains.
  var min = 0;
  var max = script.tokenPosTable.length;
  while (min < max) {
    final mid = min + ((max - min) >> 1);
    final row = script.tokenPosTable[mid];
    if (row[1] > tokenPos) {
      max = mid;
    } else {
      for (var i = 1; i < row.length; i += 2) {
        if (row[i] == tokenPos) return row.first;
      }
      min = mid + 1;
    }
  }
  return null;
}

/// Returns a JSON coverage list backward-compatible with pre-1.16.0 SDKs.
Future<List<Map<String, dynamic>>> _getCoverageJson(VmService service,
    IsolateRef isolateRef, SourceReport report, bool includeDart) async {
  // script uri -> { line -> hit count }
  final hitMaps = <Uri, Map<int, int>>{};
  final scripts = <ScriptRef, Script>{};
  for (var range in report.ranges) {
    final scriptRef = report.scripts[range.scriptIndex];
    final Uri scriptUri = Uri.parse(report.scripts[range.scriptIndex].uri);

    // Not returned in scripts section of source report.
    if (scriptUri.scheme == 'evaluate') continue;

    // Skip scripts from dart:.
    if (!includeDart && scriptUri.scheme == 'dart') continue;

    if (!scripts.containsKey(scriptRef)) {
      scripts[scriptRef] = await service.getObject(isolateRef.id, scriptRef.id);
    }
    final script = scripts[scriptRef];

    // Look up the hit map for this script (shared across isolates).
    final hitMap = hitMaps.putIfAbsent(scriptUri, () => <int, int>{});

    // Collect hits and misses.
    final coverage = range.coverage;

    if (coverage == null) continue;

    for (final tokenPos in coverage.hits) {
      final line = _getLineFromTokenPos(script, tokenPos);
      if (line == null) {
        print('tokenPos $tokenPos has no line mapping for script $scriptUri');
      }
      hitMap[line] = hitMap.containsKey(line) ? hitMap[line] + 1 : 1;
    }
    for (final tokenPos in coverage.misses) {
      final line = _getLineFromTokenPos(script, tokenPos);
      if (line == null) {
        print('tokenPos $tokenPos has no line mapping for script $scriptUri');
      }
      hitMap.putIfAbsent(line, () => 0);
    }
  }

  // Output JSON
  final coverage = <Map<String, dynamic>>[];
  hitMaps.forEach((uri, hitMap) {
    coverage.add(_toScriptCoverageJson(uri, hitMap));
  });
  return coverage;
}

/// Returns a JSON hit map backward-compatible with pre-1.16.0 SDKs.
Map<String, dynamic> _toScriptCoverageJson(
    Uri scriptUri, Map<int, int> hitMap) {
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

class StdoutLog extends Log {
  @override
  void warning(String message) => print(message);
  @override
  void severe(String message) => print(message);
}
