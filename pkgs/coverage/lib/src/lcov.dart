part of coverage;

/// Converts the given hitmap to lcov format and appends the result to
/// env.output.
///
/// Returns a [Future] that completes as soon as all map entries have been
/// emitted.
Future lcov(Map hitmap, Resolver resolver, IOSink output, List failedResolves) {
  var emitOne = (key) {
    var v = hitmap[key];
    StringBuffer entry = new StringBuffer();
    var source = resolver.resolve(key);
    if (source == null) {
      failedResolves.add(key);
      return new Future.value();
    }
    entry.write('SF:${source}\n');
    v.keys.toList()
          ..sort()
          ..forEach((k) {
      entry.write('DA:${k},${v[k]}\n');
    });
    entry.write('end_of_record\n');
    output.write(entry.toString());
    return new Future.value();
  };

  return Future.forEach(hitmap.keys, emitOne);
}
