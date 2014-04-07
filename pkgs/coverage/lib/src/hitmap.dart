part of coverage;

/// Creates a single hitmap from a raw json object. Throws away all entries that
/// are not resolvable.
Map createHitmap(List<Map> json) {
  Map<String, Map<int,int>> hitMap = {};

  addToMap(source, line, count) {
    if (!hitMap[source].containsKey(line)) {
      hitMap[source][line] = 0;
    }
    hitMap[source][line] += count;
  }

  json.forEach((Map e) {
    var source = e['source'];
    if (source == null) {
      // Couldnt resolve import, so skip this entry.
      return;
    }
    if (!hitMap.containsKey(source)) {
      hitMap[source] = {};
    }
    var hits = e['hits'];
    // hits is a flat array of the following format:
    // [ <line|linerange>, <hitcount>,...]
    // line: number.
    // linerange: '<line>-<line>'.
    for (var i = 0; i < hits.length; i += 2) {
      var k = hits[i];
      if (k is num) {
        // Single line.
        addToMap(source, k, hits[i+1]);
      }
      if (k is String) {
        // Linerange. We expand line ranges to actual lines at this point.
        var splitPos = k.indexOf('-');
        int start = int.parse(k.substring(0, splitPos));
        int end = int.parse(k.substring(splitPos + 1, k.length));
        for (var j = start; j <= end; j++) {
          addToMap(source, j, hits[i+1]);
        }
      }
    }
  });
  return hitMap;
}

/// Merges [newMap] into [result].
mergeHitmaps(Map newMap, Map result) {
  newMap.forEach((String file, Map v) {
    if (result.containsKey(file)) {
      v.forEach((int line, int cnt) {
        if (result[file][line] == null) {
          result[file][line] = cnt;
        } else {
          result[file][line] += cnt;
        }
      });
    } else {
      result[file] = v;
    }
  });
}

Future<Map> parseCoverage(List<File> files, int workers) {
  Map globalHitmap = {};
  var workerId = 0;
  return Future.wait(_split(files, workers).map((workerFiles) {
    return _spawnWorker('Worker ${workerId++}', workerFiles)
        .then((Map hitmap) => mergeHitmaps(hitmap, globalHitmap));
  })).then((_) => globalHitmap);
}

Future<Map> _spawnWorker(name, files) {
  RawReceivePort port = new RawReceivePort();
  var completer = new Completer();
  port.handler = ((Map hitmap) {
    completer.complete(hitmap);
    port.close();
  });
  var msg = new _WorkMessage(name, files, port.sendPort);
  Isolate.spawn(_worker, msg);
  return completer.future;
}

class _WorkMessage {
  final String workerName;
  final List files;
  final SendPort replyPort;
  _WorkMessage(this.workerName, this.files, this.replyPort);
}

void _worker(_WorkMessage msg) {
  List files = msg.files;
  var hitmap = {};
  files.forEach((File fileEntry) {
    // Read file sync, as it only contains 1 object.
    String contents = fileEntry.readAsStringSync();
    if (contents.length > 0) {
      var json = JSON.decode(contents)['coverage'];
      mergeHitmaps(createHitmap(json), hitmap);
    }
  });
  msg.replyPort.send(hitmap);
}

List<List> _split(List list, int nBuckets) {
  var buckets = new List(nBuckets);
  var bucketSize = list.length ~/ nBuckets;
  var leftover = list.length % nBuckets;
  var taken = 0;
  var start = 0;
  for (int i = 0; i < nBuckets; i++) {
    var end = (i < leftover) ? (start + bucketSize + 1) : (start + bucketSize);
    buckets[i] = list.sublist(start, end);
    taken += buckets[i].length;
    start = end;
  }
  if (taken != list.length) throw 'Error splitting';
  return buckets;
}
