// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.collect;

import 'dart:async';

import 'package:vm_service_client/vm_service_client.dart';
import 'util.dart';

const _retryInterval = const Duration(milliseconds: 200);

Future<Map> collect(String host, int port, bool resume, bool waitPaused,
    {Duration timeout}) async {
  var uri = 'ws://$host:$port/ws';

  var vmService;
  await retry(() async {
    try {
      vmService = new VMServiceClient.connect(uri);
      await vmService.getVM().timeout(_retryInterval);
    } on TimeoutException {
      vmService.close();
      rethrow;
    }
  }, _retryInterval, timeout: timeout);
  try {
    if (waitPaused) {
      await _waitIsolatesPaused(vmService, timeout: timeout);
    }

    return await _getAllCoverage(vmService);
  } finally {
    if (resume) {
      await _resumeIsolates(vmService);
    }
    await vmService.close();
  }
}

Future<Map> _getAllCoverage(VMServiceClient service) async {
  var vm = await service.getVM();
  var allCoverage = [];

  for (var isolateRef in vm.isolates) {
    var isolate = await isolateRef.load();
    var report = await isolate.getSourceReport(forceCompile: true);
    var coverage = await _getCoverageJson(service, report);
    allCoverage.addAll(coverage);
  }
  return {'type': 'CodeCoverage', 'coverage': allCoverage};
}

Future _resumeIsolates(VMServiceClient service) async {
  var vm = await service.getVM();
  for (var isolateRef in vm.isolates) {
    var isolate = await isolateRef.load();
    if (isolate.isPaused) {
      await isolateRef.resume();
    }
  }
}

Future _waitIsolatesPaused(VMServiceClient service, {Duration timeout}) async {
  Future allPaused() async {
    var vm = await service.getVM();
    for (var isolateRef in vm.isolates) {
      var isolate = await isolateRef.load();
      if (!isolate.isPaused) throw "Unpaused isolates remaining.";
    }
  }

  return retry(allPaused, _retryInterval, timeout: timeout);
}

/// Returns a JSON coverage list backward-compatible with pre-1.16.0 SDKs.
Future<List> _getCoverageJson(
    VMServiceClient service, VMSourceReport report) async {
  var scriptRefs = report.ranges.map((r) => r.script).toSet();
  var scripts = new Map<Uri, VMScript>.fromIterable(
      await Future.wait(scriptRefs.map((ref) => ref.load()).toList()),
      key: (s) => s.uri);

  // script uri -> { line -> hit count }
  var hitMaps = <Uri, Map<int, int>>{};
  for (var range in report.ranges) {
    // Not returned in scripts section of source report.
    if (range.script.uri.scheme == 'evaluate') continue;

    hitMaps.putIfAbsent(range.script.uri, () => <int, int>{});
    var hitMap = hitMaps[range.script.uri];
    var script = scripts[range.script.uri];
    for (VMScriptToken hit in range.hits ?? []) {
      var line = script.sourceLocation(hit).line + 1;
      hitMap[line] = hitMap.containsKey(line) ? hitMap[line] + 1 : 1;
    }
    for (VMScriptToken miss in range.misses ?? []) {
      var line = script.sourceLocation(miss).line + 1;
      hitMap.putIfAbsent(line, () => 0);
    }
  }

  // Output JSON
  var coverage = [];
  hitMaps.forEach((uri, hitMap) {
    var script = scripts[uri];
    coverage.add(_toScriptCoverageJson(script, hitMap));
  });
  return coverage;
}

/// Returns a JSON hit map backward-compatible with pre-1.16.0 SDKs.
Map _toScriptCoverageJson(VMScript script, Map<int, int> hitMap) {
  var json = {};
  var hits = [];
  hitMap.forEach((line, hitCount) {
    hits.add(line);
    hits.add(hitCount);
  });
  json['source'] = '${script.uri}';
  json['script'] = {
    'type': '@Script',
    'fixedId': true,
    'id': 'libraries/1/scripts/${Uri.encodeComponent(script.uri.toString())}',
    'uri': '${script.uri}',
    '_kind': 'library',
  };
  json['hits'] = hits;
  return json;
}
