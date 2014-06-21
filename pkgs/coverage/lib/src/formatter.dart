part of coverage;

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

  Future<String> format(Map hitmap) {
    var buf = new StringBuffer();
    var emitOne = (key) {
      var v = hitmap[key];
      StringBuffer entry = new StringBuffer();
      var source = resolver.resolve(key);
      if (source == null) {
        return new Future.value();
      }
      entry.write('SF:${source}\n');
      v.keys.toList()
            ..sort()
            ..forEach((k) {
        entry.write('DA:${k},${v[k]}\n');
      });
      entry.write('end_of_record\n');
      buf.write(entry.toString());
      return new Future.value();
    };

    return Future.forEach(hitmap.keys, emitOne).then((_) => buf);
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

  Future<String> format(Map hitmap) {
    var buf = new StringBuffer();
    var emitOne = (key) {
      var v = hitmap[key];
      var c = new Completer();
      var uri = resolver.resolve(key);
      if (uri == null) {
        c.complete();
      } else {
        loader.load(uri).then((lines) {
          if (lines == null) {
            c.complete();
            return;
          }
          buf.write('${uri}\n');
          for (var line = 1; line <= lines.length; line++) {
            String prefix = '       ';
            if (v.containsKey(line)) {
              prefix = v[line].toString();
              StringBuffer b = new StringBuffer();
              for (int i = prefix.length; i < 7; i++) {
                b.write(' ');
              }
              b.write(prefix);
              prefix = b.toString();
            }
            buf.write('${prefix}|${lines[line-1]}\n');
          }
          c.complete();
        });
      }
      return c.future;
    };
    return Future.forEach(hitmap.keys, emitOne).then((_) => buf);
  }
}
