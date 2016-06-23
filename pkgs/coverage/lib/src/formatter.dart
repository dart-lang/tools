library coverage.formatter;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'resolver.dart';

abstract class Formatter {
  /// [pathFilter], if provided, is used to filter which files are included
  /// in the output.
  ///
  /// The paths in [reportOn], if provided, are used to filter the included
  /// files. Files are only included if their path starts with one of the
  /// values.
  ///
  /// [pathFilter] and [reportOn] cannot both be provided in a call to [format].
  Future<String> format(Map hitmap,
      {List<String> reportOn, bool pathFilter(String path)});
}

/// Converts the given hitmap to lcov format and appends the result to
/// env.output.
///
/// Returns a [Future] that completes as soon as all map entries have been
/// emitted.
class LcovFormatter implements Formatter {
  final Resolver resolver;
  LcovFormatter(this.resolver);

  Future<String> format(Map hitmap,
      {List<String> reportOn,
      bool pathFilter(String path),
      String basePath}) async {
    pathFilter = _getFilter(pathFilter, reportOn);

    var buf = new StringBuffer();
    for (var key in hitmap.keys) {
      var v = hitmap[key];
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
        ..forEach((k) {
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
  PrettyPrintFormatter(this.resolver, this.loader);

  Future<String> format(Map hitmap,
      {List<String> reportOn, bool pathFilter(String path)}) async {
    pathFilter = _getFilter(pathFilter, reportOn);

    var buf = new StringBuffer();
    for (var key in hitmap.keys) {
      var v = hitmap[key];
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

bool _anyPathFilter(String input) => true;

_PathFilter _getFilter(_PathFilter pathFilter, List<String> reportOn) {
  if (reportOn != null) {
    if (pathFilter != null) {
      throw new ArgumentError('Cannot provide both reportOn and pathFilter');
    }
    var absolutePaths =
        reportOn.map((path) => new File(path).absolute.path).toList();

    return (String path) => absolutePaths.any((item) => path.startsWith(item));
  }

  if (pathFilter == null) {
    return _anyPathFilter;
  }

  return pathFilter;
}
