part of coverage;

/// [Resolver] resolves imports with respect to a given environment.
class Resolver {
  static const DART_PREFIX = 'dart:';
  static const PACKAGE_PREFIX = 'package:';
  static const FILE_PREFIX = 'file://';
  static const HTTP_PREFIX = 'http://';

  final String pkgRoot;
  final String sdkRoot;
  List failed = [];

  Resolver({packageRoot: null, sdkRoot: null})
      : pkgRoot = packageRoot,
        sdkRoot = sdkRoot;

  /// Returns the absolute path wrt. to the given environment or null, if the
  /// import could not be resolved.
  resolve(String uri) {
    if (uri.startsWith(DART_PREFIX)) {
      if (sdkRoot == null) {
        // No sdk-root given, do not resolve dart: URIs.
        return null;
      }
      var slashPos = uri.indexOf('/');
      var filePath;
      if (slashPos != -1) {
        var path = uri.substring(DART_PREFIX.length, slashPos);
        // Drop patch files, since we don't have their source in the compiled
        // SDK.
        if (path.endsWith('-patch')) {
          failed.add(uri);
          return null;
        }
        // Canonicalize path. For instance: _collection-dev => _collection_dev.
        path = path.replaceAll('-', '_');
        filePath = '$sdkRoot/${path}${uri.substring(slashPos, uri.length)}';
      } else {
        // Resolve 'dart:something' to be something/something.dart in the SDK.
        var lib = uri.substring(DART_PREFIX.length, uri.length);
        filePath = '$sdkRoot/$lib/${lib}.dart';
      }
      return filePath;
    }
    if (uri.startsWith(PACKAGE_PREFIX)) {
      if (pkgRoot == null) {
        // No package-root given, do not resolve package: URIs.
        return null;
      }
      return '$pkgRoot/${uri.substring(PACKAGE_PREFIX.length, uri.length)}';
    }
    if (uri.startsWith(FILE_PREFIX)) {
      return fromUri(Uri.parse(uri));
    }
    if (uri.startsWith(HTTP_PREFIX)) {
      return uri;
    }
    // We cannot deal with anything else.
    failed.add(uri);
    return null;
  }
}

/// Creates a single hitmap from a raw json object. Throws away all entries that
/// are not resolvable.
Map createHitmap(List<Map> json, Resolver resolver) {
  Map<String, Map<int,int>> hitMap = {};

  addToMap(source, line, count) {
    if (!hitMap[source].containsKey(line)) {
      hitMap[source][line] = 0;
    }
    hitMap[source][line] += count;
  }

  json.forEach((Map e) {
    String source = resolver.resolve(e['source']);
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

Future<Map> parseCoverage(List<File> files, String pkgRoot, String sdkRoot,
    int workers) {
  Map globalHitmap = {};
  var workerId = 0;
  return Future.wait(_split(files, workers).map((workerFiles) {
    return _spawnWorker('Worker ${workerId++}', pkgRoot, sdkRoot, workerFiles)
        .then((_ResultMessage msg) => mergeHitmaps(msg.hitmap, globalHitmap));
  })).then((_) => globalHitmap);
}

Future<_ResultMessage> _spawnWorker(name, pkgRoot, sdkRoot, files) {
  RawReceivePort port = new RawReceivePort();
  var completer = new Completer();
  port.handler = ((_ResultMessage msg) {
    completer.complete(msg);
    port.close();
  });
  var msg = new _WorkMessage(name, pkgRoot, sdkRoot, files, port.sendPort);
  Isolate.spawn(_worker, msg);
  return completer.future;
}

class _WorkMessage {
  final String workerName;
  final String sdkRoot;
  final String pkgRoot;
  final List files;
  final SendPort replyPort;
  _WorkMessage(this.workerName, this.pkgRoot, this.sdkRoot, this.files,
      this.replyPort);
}

class _ResultMessage {
  final hitmap;
  final failedResolves;
  _ResultMessage(this.hitmap, this.failedResolves);
}

_worker(_WorkMessage msg) {
  List files = msg.files;
  var resolver = new Resolver(packageRoot: msg.pkgRoot, sdkRoot: msg.sdkRoot);
  var workerHitmap = {};
  files.forEach((File fileEntry) {
    // Read file sync, as it only contains 1 object.
    String contents = fileEntry.readAsStringSync();
    if (contents.length > 0) {
      var json = JSON.decode(contents)['coverage'];
      mergeHitmaps(createHitmap(json, resolver), workerHitmap);
    }
  });
  msg.replyPort.send(new _ResultMessage(workerHitmap, resolver.failed));
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
