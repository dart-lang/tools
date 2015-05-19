library coverage.hitmap;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// Creates a single hitmap from a raw json object. Throws away all entries that
/// are not resolvable.
Map createHitmap(List<Map> json) {
  // Map of source file to map of line to hit count for that line.
  var globalHitMap = <String, Map<int, int>>{};

  void addToMap(Map<int, int> map, int line, int count) {
    var oldCount = map.putIfAbsent(line, () => 0);
    map[line] = count + oldCount;
  }

  for (Map e in json) {
    var source = e['source'];
    if (source == null) {
      // Couldn't resolve import, so skip this entry.
      continue;
    }

    var sourceHitMap = globalHitMap.putIfAbsent(source, () => <int, int>{});
    var hits = e['hits'];
    // hits is a flat array of the following format:
    // [ <line|linerange>, <hitcount>,...]
    // line: number.
    // linerange: '<line>-<line>'.
    for (var i = 0; i < hits.length; i += 2) {
      var k = hits[i];
      if (k is num) {
        // Single line.
        addToMap(sourceHitMap, k, hits[i + 1]);
      } else {
        assert(k is String);
        // Linerange. We expand line ranges to actual lines at this point.
        var splitPos = k.indexOf('-');
        int start = int.parse(k.substring(0, splitPos));
        int end = int.parse(k.substring(splitPos + 1));
        for (var j = start; j <= end; j++) {
          addToMap(sourceHitMap, j, hits[i + 1]);
        }
      }
    }
  }
  return globalHitMap;
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

Future<Map> parseCoverage(List<File> files, int workers) async {
  Map globalHitmap = {};
  var workerId = 0;
  await Future.wait(_split(files, workers).map((workerFiles) async {
    var hitmap = await _spawnWorker('Worker ${workerId++}', workerFiles);
    mergeHitmaps(hitmap, globalHitmap);
  }));

  return globalHitmap;
}

Future<Map> _spawnWorker(String name, List<File> files) async {
  RawReceivePort port = new RawReceivePort();
  var completer = new Completer();
  port.handler = ((result) {
    try {
      if (result is Map) {
        completer.complete(result);
      } else {
        // TODO: result[1] is a String, but should map to a StackTrace
        //       consider using the stacktrace package to parse and send
        completer.completeError(result[0]);
      }
    } catch (err, stack) {
      completer.completeError(err, stack);
    } finally {
      port.close();
    }
  });
  var msg = new _WorkMessage(name, files, port.sendPort);

  Isolate isolate = await Isolate.spawn(_worker, msg, paused: true);
  isolate.setErrorsFatal(true);

  isolate.resume(isolate.pauseCapability);

  isolate.addErrorListener(port.sendPort);

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
