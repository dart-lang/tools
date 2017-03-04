library coverage.formatter;

import 'dart:async';

import 'package:path/path.dart' as p;

import 'resolver.dart';

abstract class Formatter {
  /// Returns the formatted coverage data.
  Future<String> format(Map hitmap);
}

/// Converts the given hitmap to lcov format and appends the result to
/// env.output.
///
/// Returns a [Future] that completes as soon as all map entries have been
/// emitted.
class LcovFormatter implements Formatter {
  final Resolver resolver;
  final String basePath;
  final List<String> reportOn;

  /// Creates a new LCOV formatter.
  ///
  /// If [reportOn] is provided, coverage report output is limited to files
  /// prefixed with one of the paths included. If [basePath] is provided, paths
  /// are reported relative to that path.
  LcovFormatter(this.resolver, {this.reportOn, this.basePath});

  Future<String> format(Map hitmap) async {
    _PathFilter pathFilter = _getPathFilter(reportOn);
    var buf = new StringBuffer();
    for (var key in hitmap.keys) {
      Map<int, int> v = hitmap[key];
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

      buf.write('SF:${source}\n');
      v.keys.toList()
        ..sort()
        ..forEach((int k) {
          buf.write('DA:${k},${v[k]}\n');
        });
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
  final Resolver resolver;
  final Loader loader;
  final List<String> reportOn;

  /// Creates a new pretty-print formatter.
  ///
  /// If [reportOn] is provided, coverage report output is limited to files
  /// prefixed with one of the paths included. If [basePath] is provided, paths
  /// are reported relative to that path.
  PrettyPrintFormatter(this.resolver, this.loader, {this.reportOn});

  Future<String> format(Map hitmap) async {
    _PathFilter pathFilter = _getPathFilter(reportOn);
    var buf = new StringBuffer();
    for (var key in hitmap.keys) {
      Map<int, int> v = hitmap[key];
      var source = resolver.resolve(key);
      if (source == null) {
        continue;
      }

      if (!pathFilter(source)) {
        continue;
      }

      var lines = await loader.load(source);
      if (lines == null) {
        continue;
      }
      buf.writeln(source);
      for (var line = 1; line <= lines.length; line++) {
        var prefix = _prefix;
        if (v.containsKey(line)) {
          prefix = v[line].toString().padLeft(_prefix.length);
        }
        buf.writeln('${prefix}|${lines[line-1]}');
      }
    }

    return buf.toString();
  }
}

const _prefix = '       ';

typedef bool _PathFilter(String path);

_PathFilter _getPathFilter(List<String> reportOn) {
  if (reportOn == null) return (String path) => true;

  var absolutePaths = reportOn.map(p.absolute).toList();
  return (String path) => absolutePaths.any((item) => path.startsWith(item));
}
