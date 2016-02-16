// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.collect;

import 'dart:async';

import 'vm_service_client.dart';
import 'util.dart';

const _retryInterval = const Duration(milliseconds: 200);

Future<Map> collect(String host, int port, bool resume, bool waitPaused,
    {Duration timeout}) async {
  var uri = 'ws://$host:$port/ws';

  var vmService = await retry(
      () => VMServiceClient.connect(uri), _retryInterval,
      timeout: timeout);
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
    var coverage = await service.getCoverage(isolate);
    allCoverage.addAll(coverage.coverage);
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
  allPaused() async {
    var vm = await service.getVM();
    for (var isolateRef in vm.isolates) {
      var isolate = await isolateRef.load();
      if (!isolate.isPaused) throw "Unpaused isolates remaining.";
    }
  }
  return retry(allPaused, _retryInterval, timeout: timeout);
}
