// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io';
import 'package:args/args.dart';
import 'package:coverage/src/devtools.dart';
import 'package:coverage/src/util.dart';

Future<Map> getAllCoverage(Observatory observatory) {
  return observatory
      .getIsolates()
      .then((isolates) => isolates.map((i) => i.getCoverage()))
      .then(Future.wait)
      .then((responses) {
    // flatten response lists
    var allCoverage = responses.expand((it) => it).toList();
    return {'type': 'CodeCoverage', 'coverage': allCoverage,};
  });
}

Future resumeIsolates(Observatory observatory) {
  return observatory
      .getIsolates()
      .then((isolates) => isolates.map((i) => i.resume()))
      .then(Future.wait);
}

Future waitIsolatesPaused(Observatory observatory) {
  allPaused() => observatory
      .getIsolates()
      .then((isolates) => isolates.every((i) => i.paused))
      .then((paused) => paused ? paused : new Future.error(paused));
  return retry(allPaused, RETRY_INTERVAL);
}

const RETRY_INTERVAL = const Duration(milliseconds: 200);

void main(List<String> arguments) {
  var options = parseArgs(arguments);
  onTimeout() {
    var timeout = options.timeout.inSeconds;
    print('Failed to collect coverage within ${timeout}s');
    exit(1);
  }
  Future connected = retry(
      () => Observatory.connect(options.host, options.port), RETRY_INTERVAL);
  if (options.timeout != null) {
    connected.timeout(options.timeout, onTimeout: onTimeout);
  }
  connected.then((observatory) {
    Future ready = options.waitPaused
        ? waitIsolatesPaused(observatory)
        : new Future.value();
    if (options.timeout != null) {
      ready.timeout(options.timeout, onTimeout: onTimeout);
    }
    return ready
        .then((_) => getAllCoverage(observatory))
        .then(JSON.encode)
        .then(options.out.write)
        .then((_) => options.out.close())
        .then((_) => options.resume ? resumeIsolates(observatory) : null)
        .then((_) => observatory.close());
  });
}

class Options {
  final String host;
  final String port;
  final IOSink out;
  final Duration timeout;
  final bool waitPaused;
  final bool resume;
  Options(this.host, this.port, this.out, this.timeout, this.waitPaused,
      this.resume);
}

Options parseArgs(List<String> arguments) {
  var parser = new ArgParser();

  parser.addOption('host',
      abbr: 'H', defaultsTo: '127.0.0.1', help: 'remote VM host');
  parser.addOption('port', abbr: 'p', help: 'remote VM port');
  parser.addOption('out',
      abbr: 'o', defaultsTo: 'stdout', help: 'output: may be file or stdout');
  parser.addOption('connect-timeout',
      abbr: 't', help: 'connect timeout in seconds');
  parser.addFlag('wait-paused',
      abbr: 'w',
      defaultsTo: false,
      help: 'wait for all isolates to be paused before collecting coverage');
  parser.addFlag('resume-isolates',
      abbr: 'r', defaultsTo: false, help: 'resume all isolates on exit');
  parser.addFlag('help', abbr: 'h', negatable: false, help: 'show this help');
  var args = parser.parse(arguments);

  printUsage() {
    print('Usage: dart collect_coverage.dart --port=NNNN [OPTION...]\n');
    print(parser.getUsage());
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
  return new Options(args['host'], args['port'], out, timeout,
      args['wait-paused'], args['resume-isolates']);
}
