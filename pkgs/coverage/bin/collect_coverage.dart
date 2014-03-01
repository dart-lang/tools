// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io';
import 'package:args/args.dart';
import 'package:coverage/src/devtools.dart';

Future<List> getAllCoverage(String host, String port) {
  return DevTools.connect(host, port).then((devTools) {
    return devTools.getIsolateIds().then((isolateIds) {
      var requests = isolateIds.map(devTools.getCoverage).toList();
      return Future.wait(requests).then((responses) {
        // flatten response lists
        var allCoverage = responses.expand((it) => it).toList();
        devTools.close();
        return {
          'type': 'CodeCoverage',
          'coverage': allCoverage,
        };
      });
    });
  });
}

void main(List<String> arguments) {
  var options = parseArgs(arguments);
  getAllCoverage(options.host, options.port).then((coverage) {
    options.out.write(JSON.encode(coverage));
    options.out.close();
  });
}

class Options {
  final String host;
  final String port;
  final IOSink out;
  Options(this.host, this.port, this.out);
}

Options parseArgs(List<String> arguments) {
  var parser = new ArgParser();

  parser.addOption('host', abbr: 'H', defaultsTo: 'localhost',
      help: 'remote VM host');
  parser.addOption('port', abbr: 'p', help: 'remote VM port');
  parser.addOption('out', abbr: 'o', defaultsTo: 'stdout',
      help: 'output: may be file or stdout');
  parser.addFlag('help', abbr: 'h', negatable: false,
      help: 'show this help');
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

  return new Options(args['host'], args['port'],
      (args['out'] == 'stdout') ? stdout : new File(args['out']).openWrite());
}
