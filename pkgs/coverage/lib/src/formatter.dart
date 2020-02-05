// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:path/path.dart' as p;

import 'resolver.dart';

abstract class Formatter {
  /// Returns the formatted coverage data.
  Future<String> format(Map<String, Map<int, int>> hitmap);
}

/// Converts the given hitmap to lcov format and appends the result to
/// env.output.
///
/// Returns a [Future] that completes as soon as all map entries have been
/// emitted.
class LcovFormatter implements Formatter {
  /// Creates a LCOV formatter.
  ///
  /// If [reportOn] is provided, coverage report output is limited to files
  /// prefixed with one of the paths included. If [basePath] is provided, paths
  /// are reported relative to that path.
  LcovFormatter(this.resolver, {this.reportOn, this.basePath});

  final Resolver resolver;
  final String basePath;
  final List<String> reportOn;

  @override
  Future<String> format(Map<String, Map<int, int>> hitmap) async {
    final pathFilter = _getPathFilter(reportOn);
    final buf = StringBuffer();
    for (var key in hitmap.keys) {
      final v = hitmap[key];
      var source = resolver.resolve(key);
      if (source == null) {
        continue;
      }

      if (!pathFilter(source)) {
        continue;
      }

      if (basePath != null) {
        source = p.relative(source, from: basePath);
      }

      buf.write('SF:$source\n');
      final lines = v.keys.toList()..sort();
      for (var k in lines) {
        buf.write('DA:$k,${v[k]}\n');
      }
      buf.write('LF:${lines.length}\n');
      buf.write('LH:${lines.where((k) => v[k] > 0).length}\n');
      buf.write('end_of_record\n');
    }

    return buf.toString();
  }
}

/// Converts the given hitmap to a pretty-print format and appends the result
/// to env.output.
///
/// Returns a [Future] that completes as soon as all map entries have been
/// emitted.
class PrettyPrintFormatter implements Formatter {
  /// Creates a pretty-print formatter.
  ///
  /// If [reportOn] is provided, coverage report output is limited to files
  /// prefixed with one of the paths included.
  PrettyPrintFormatter(this.resolver, this.loader, {this.reportOn});

  final Resolver resolver;
  final Loader loader;
  final List<String> reportOn;

  @override
  Future<String> format(Map<String, dynamic> hitmap) async {
    final pathFilter = _getPathFilter(reportOn);
    final buf = StringBuffer();
    for (var key in hitmap.keys) {
      final v = hitmap[key] as Map<int, int>;
      final source = resolver.resolve(key);
      if (source == null) {
        continue;
      }

      if (!pathFilter(source)) {
        continue;
      }

      final lines = await loader.load(source);
      if (lines == null) {
        continue;
      }
      buf.writeln(source);
      for (var line = 1; line <= lines.length; line++) {
        var prefix = _prefix;
        if (v.containsKey(line)) {
          prefix = v[line].toString().padLeft(_prefix.length);
        }
        buf.writeln('$prefix|${lines[line - 1]}');
      }
    }

    return buf.toString();
  }
}

const _prefix = '       ';

typedef _PathFilter = bool Function(String path);

_PathFilter _getPathFilter(List<String> reportOn) {
  if (reportOn == null) return (String path) => true;

  final absolutePaths = reportOn.map(p.absolute).toList();
  return (String path) => absolutePaths.any((item) => path.startsWith(item));
}
