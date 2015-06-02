// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io';

import 'package:args/args.dart';
import 'package:coverage/src/devtools.dart';
import 'package:coverage/src/util.dart';
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

Future<Map> getAllCoverage(VMService service) async {
  var vm = await service.getVM();
  var coverageRequests = vm.isolates.map((i) => service.getCoverage(i.id));
  var coverageResponses = await Future.wait(coverageRequests);
  var allCoverage = coverageResponses.expand((c) => c.coverage).toList();
  return {'type': 'CodeCoverage', 'coverage': allCoverage,};
}

Future resumeIsolates(VMService service) async {
  var vm = await service.getVM();
  var isolateRequests = vm.isolates.map((i) => service.resume(i.id));
  return Future.wait(isolateRequests);
}

Future waitIsolatesPaused(VMService service) async {
  allPaused() async {
    var vm = await service.getVM();
    var isolateRequests = vm.isolates.map((i) => service.getIsolate(i.id));
    var isolates = await Future.wait(isolateRequests);
    var paused = isolates.every((i) => i.paused);
    if (!paused) throw "Unpaused isolates remaining.";
  }
  return retry(allPaused, retryInterval);
}

const retryInterval = const Duration(milliseconds: 200);

main(List<String> arguments) async {
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  var options = parseArgs(arguments);
  await Chain.capture(() async {
    exitOnTimeout() {
      var timeout = options.timeout.inSeconds;
      print('Failed to collect coverage within ${timeout}s');
      exit(1);
    }

    Future connected = retry(
        () => VMService.connect(options.host, options.port), retryInterval);
    if (options.timeout != null) {
      connected = connected.timeout(options.timeout, onTimeout: exitOnTimeout);
    }
    var vmService = await connected;
    Future ready =
        options.waitPaused ? waitIsolatesPaused(vmService) : new Future.value();
    if (options.timeout != null) {
      ready = ready.timeout(options.timeout, onTimeout: exitOnTimeout);
    }
    await ready;
    var coverage = await getAllCoverage(vmService);
    options.out.write(JSON.encode(coverage));
    await options.out.close();
    if (options.resume) {
      await resumeIsolates(vmService);
    }
    await vmService.close();
  }, onError: (error, Chain chain) {
    print(error);
    print(chain.terse);
    // See http://www.retro11.de/ouxr/211bsd/usr/include/sysexits.h.html
    // EX_SOFTWARE
    exit(70);
  });
}

class Options {
  final String host;
  final int port;
  final IOSink out;
  final Duration timeout;
  final bool waitPaused;
  final bool resume;
  Options(this.host, this.port, this.out, this.timeout, this.waitPaused,
      this.resume);
}

Options parseArgs(List<String> arguments) {
  var parser = new ArgParser()
    ..addOption('host',
        abbr: 'H', defaultsTo: '127.0.0.1', help: 'remote VM host')
    ..addOption('port', abbr: 'p', help: 'remote VM port', defaultsTo: '8181')
    ..addOption('out',
        abbr: 'o', defaultsTo: 'stdout', help: 'output: may be file or stdout')
    ..addOption('connect-timeout',
        abbr: 't', help: 'connect timeout in seconds')
    ..addFlag('wait-paused',
        abbr: 'w',
        defaultsTo: false,
        help: 'wait for all isolates to be paused before collecting coverage')
    ..addFlag('resume-isolates',
        abbr: 'r', defaultsTo: false, help: 'resume all isolates on exit')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'show this help');

  var args = parser.parse(arguments);

  printUsage() {
    print('Usage: dart collect_coverage.dart --port=NNNN [OPTION...]\n');
    print(parser.usage);
  }

  fail(message) {
    print('Error: $message\n');
    printUsage();
    exit(1);
  }

  if (args['help']) {
    printUsage();
    exit(0);
  }

  if (args['port'] == null) fail('port not specified');
  var port = int.parse(args['port']);

  var out;
  if (args['out'] == 'stdout') {
    out = stdout;
  } else {
    var outfile = new File(args['out'])..createSync(recursive: true);
    out = outfile.openWrite();
  }
  var timeout = (args['connect-timeout'] == null)
      ? null
      : new Duration(seconds: int.parse(args['connect-timeout']));
  return new Options(args['host'], port, out, timeout, args['wait-paused'],
      args['resume-isolates']);
}
