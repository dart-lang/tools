// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/args.dart';

class CliParser {
  final ArgParser parser = () {
    final parser = ArgParser();
    parser.addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help.',
    );
    parser.addMultiOption(
      'define',
      abbr: 'D',
      help: '''Define or override a config property from command line.
The same option can be passed multiple times.
Keys should only contain lower-case alphanumeric characters, underscores,
and '.'s''',
    );
    parser.addOption(
      'config',
      abbr: 'c',
      help: '''Path to JSON or YAML config file.
Keys should only contain lower-case alphanumeric characters, and underscores.
Hierarchies should be maps.''',
    );
    return parser;
  }();

  ArgResults parse(List<String> args) => parser.parse(args);
}

class DefinesParser {
  Map<String, List<String>> parse(List<String> args) {
    final regex = RegExp('([a-z_.]+)=(.+)');
    final defines = <String, List<String>>{};
    for (final arg in args) {
      final match = regex.matchAsPrefix(arg);
      if (match == null || match.group(0) != arg) {
        throw FormatException("Define '$arg' does not match expected pattern "
            "'${regex.pattern}'.");
      }
      final key = match.group(1)!;
      final value = match.group(2)!;
      defines[key] = (defines[key] ?? [])..add(value);
    }
    return defines;
  }
}
