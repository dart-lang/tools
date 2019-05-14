// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show json;
import 'dart:io';

/// Creates a single hitmap from a raw json object. Throws away all entries that
/// are not resolvable.
///
/// `jsonResult` is expected to be a List<Map<String, dynamic>>.
Map<String, Map<int, int>> createHitmap(List jsonResult) {
  // Map of source file to map of line to hit count for that line.
  final globalHitMap = <String, Map<int, int>>{};

  void addToMap(Map<int, int> map, int line, int count) {
    final oldCount = map.putIfAbsent(line, () => 0);
    map[line] = count + oldCount;
  }

  for (Map<String, dynamic> e in jsonResult) {
    final String source = e['source'];
    if (source == null) {
      // Couldn't resolve import, so skip this entry.
      continue;
    }

    final sourceHitMap = globalHitMap.putIfAbsent(source, () => <int, int>{});
    final List<dynamic> hits = e['hits'];
    // hits is a flat array of the following format:
    // [ <line|linerange>, <hitcount>,...]
    // line: number.
    // linerange: '<line>-<line>'.
    for (var i = 0; i < hits.length; i += 2) {
      final dynamic k = hits[i];
      if (k is num) {
        // Single line.
        addToMap(sourceHitMap, k, hits[i + 1]);
      } else {
        assert(k is String);
        // Linerange. We expand line ranges to actual lines at this point.
        final int splitPos = k.indexOf('-');
        final start = int.parse(k.substring(0, splitPos));
        final end = int.parse(k.substring(splitPos + 1));
        for (var j = start; j <= end; j++) {
          addToMap(sourceHitMap, j, hits[i + 1]);
        }
      }
    }
  }
  return globalHitMap;
}

/// Merges [newMap] into [result].
void mergeHitmaps(
    Map<String, Map<int, int>> newMap, Map<String, Map<int, int>> result) {
  newMap.forEach((String file, Map<int, int> v) {
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

/// Generates a merged hitmap from a set of coverage JSON files.
Future<Map> parseCoverage(Iterable<File> files, int _) async {
  final globalHitmap = <String, Map<int, int>>{};
  for (var file in files) {
    final contents = file.readAsStringSync();
    final List jsonResult = json.decode(contents)['coverage'];
    mergeHitmaps(createHitmap(jsonResult), globalHitmap);
  }
  return globalHitmap;
}
