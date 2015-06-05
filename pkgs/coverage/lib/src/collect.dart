// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.collect;

import 'dart:async';

import 'devtools.dart';
import 'util.dart';

const _retryInterval = const Duration(milliseconds: 200);

Future<Map> collect(String host, int port, bool resume, bool waitPaused,
    {Duration timeout}) async {
  var vmService = await retry(
      () => VMService.connect(host, port), _retryInterval, timeout: timeout);
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

Future<Map> _getAllCoverage(VMService service) async {
  var vm = await service.getVM();
  var allCoverage = [];

  for (var isolate in vm.isolates) {
    var coverage = await service.getCoverage(isolate.id);
    allCoverage.addAll(coverage.coverage);
  }
  return {'type': 'CodeCoverage', 'coverage': allCoverage};
}

Future _resumeIsolates(VMService service) async {
  var vm = await service.getVM();
  var isolateRequests = vm.isolates.map((i) => service.resume(i.id));
  return Future.wait(isolateRequests);
}

Future _waitIsolatesPaused(VMService service, {Duration timeout}) async {
  allPaused() async {
    var vm = await service.getVM();
    var isolateRequests = vm.isolates.map((i) => service.getIsolate(i.id));
    var isolates = await Future.wait(isolateRequests);
    var paused = isolates.every((i) => i.paused);
    if (!paused) throw "Unpaused isolates remaining.";
  }
  return retry(allPaused, _retryInterval, timeout: timeout);
}
