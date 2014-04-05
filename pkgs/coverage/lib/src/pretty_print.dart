part of coverage;

/// Converts the given hitmap to a pretty-print format and appends the result
/// to env.output.
///
/// Returns a [Future] that completes as soon as all map entries have been
/// emitted.
Future prettyPrint(Map hitMap, Resolver resolver, Loader loader, IOSink output,
                   List failedResolves, List failedLoads) {
  var emitOne = (key) {
    var v = hitMap[key];
    var c = new Completer();
    var uri = resolver.resolve(key);
    if (uri == null) {
      failedResolves.add(key);
      c.complete();
    } else {
      loader.load(uri).then((lines) {
        if (lines == null) {
          failedLoads.add(key);
          c.complete();
          return;
        }
        output.write('${uri}\n');
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
          output.write('${prefix}|${lines[line-1]}\n');
        }
        c.complete();
      });
    }
    return c.future;
  };
  return Future.forEach(hitMap.keys, emitOne);
}
