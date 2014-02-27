part of coverage;

/// Converts the given hitmap to a pretty-print format and appends the result
/// to env.output.
///
/// Returns a [Future] that completes as soon as all map entries have been
/// emitted.
Future prettyPrint(Map hitMap, List failedLoads, IOSink output) {
  var emitOne = (key) {
    var v = hitMap[key];
    var c = new Completer();
    _loadResource(key).then((lines) {
      if (lines == null) {
        failedLoads.add(key);
        c.complete();
        return;
      }
      output.write('${key}\n');
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
    return c.future;
  };

  return Future.forEach(hitMap.keys, emitOne);
}

/// Load an import resource and return a [Future] with a [List] of its lines.
/// Returns [null] instead of a list if the resource could not be loaded.
Future<List> _loadResource(String uri) {
  if (uri.startsWith('http')) {
    Completer c = new Completer();
    HttpClient client = new HttpClient();
    client.getUrl(Uri.parse(uri))
        .then((HttpClientRequest request) {
          return request.close();
        })
        .then((HttpClientResponse response) {
          response.transform(UTF8.decoder).toList().then((data) {
            c.complete(data);
            client.close();
          });
        })
        .catchError((e) {
          c.complete(null);
        });
    return c.future;
  } else {
    File f = new File(uri);
    return f.readAsLines()
        .catchError((e) {
          return new Future.value(null);
        });
  }
}
