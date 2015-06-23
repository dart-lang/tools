library coverage.formatter;

import 'dart:async';
import 'dart:io';

import 'resolver.dart';

abstract class Formatter {
  Future<String> format(Map json);
}

/// Converts the given hitmap to lcov format and appends the result to
/// env.output.
///
/// Returns a [Future] that completes as soon as all map entries have been
/// emitted.
class LcovFormatter implements Formatter {
  final Resolver resolver;
  LcovFormatter(this.resolver);

  Future<String> format(Map hitmap, {List<String> reportOn}) async {
    var buf = new StringBuffer();
    var reportOnPaths = reportOn != null
        ? reportOn.map((path) => new File(path).absolute.path)
        : [];

    hitmap.forEach((key, v) {
      var source = resolver.resolve(key);
      if (source == null) {
        return;
      } else if (!reportOnPaths.isEmpty &&
          !reportOnPaths.any((p) => source.startsWith(p))) {
        return;
      }
      buf.write('SF:${source}\n');
      v.keys.toList()
        ..sort()
        ..forEach((k) {
          buf.write('DA:${k},${v[k]}\n');
        });
      buf.write('end_of_record\n');
    });

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

  Future<String> format(Map hitmap, {List<String> reportOn}) async {
    var buf = new StringBuffer();
    var reportOnPaths = reportOn != null
        ? reportOn.map((path) => new File(path).absolute.path)
        : [];
    for (var key in hitmap.keys) {
      var v = hitmap[key];
      var uri = resolver.resolve(key);
      if (uri == null) {
        continue;
      } else if (!reportOnPaths.isEmpty &&
          !reportOnPaths.any((p) => uri.startsWith(p))) {
        continue;
      } else {
        var lines = await loader.load(uri);
        if (lines == null) {
          continue;
        }
        buf.writeln(uri);
        for (var line = 1; line <= lines.length; line++) {
          var prefix = _prefix;
          if (v.containsKey(line)) {
            prefix = v[line].toString().padLeft(_prefix.length);
          }
          buf.writeln('${prefix}|${lines[line-1]}');
        }
      }
    }

    return buf.toString();
  }
}

const _prefix = '       ';
