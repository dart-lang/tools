// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show json;
import 'dart:io';

import 'package:coverage/src/resolver.dart';
import 'package:coverage/src/util.dart';

/// Contains line and function hit information for a single script.
class HitMap {
  /// Map from line to hit count for that line.
  final lineHits = <int, int>{};

  /// Map from function definition line to hit count for that function.
  final funcHits = <int, int>{};

  /// Map from function definition line to function name.
  final funcNames = <int, String>{};
}

/// Class containing information about a coverage hit.
class _HitInfo {
  _HitInfo(this.firstLine, this.hitRange, this.hitCount);

  /// The line number of the first line of this hit range.
  final int firstLine;

  /// A hit range is either a number (1 line) or a String of the form
  /// "start-end" (multi-line range).
  final dynamic hitRange;

  /// How many times this hit range was executed.
  final int hitCount;
}

/// Creates a single hitmap from a raw json object. Throws away all entries that
/// are not resolvable.
///
/// `jsonResult` is expected to be a List<Map<String, dynamic>>.
Future<Map<String, HitMap>> createHitmap(
  List<Map<String, dynamic>> jsonResult, {
  bool checkIgnoredLines = false,
  String? packagesPath,
}) async {
  final resolver = Resolver(packagesPath: packagesPath);
  final loader = Loader();

  // Map of source file to map of line to hit count for that line.
  final globalHitMap = <String, HitMap>{};

  for (var e in jsonResult) {
    final source = e['source'] as String?;
    if (source == null) {
      // Couldn't resolve import, so skip this entry.
      continue;
    }

    var ignoredLinesList = <List<int>>[];

    if (checkIgnoredLines) {
      final path = resolver.resolve(source);
      if (path != null) {
        final lines = await loader.load(path);
        ignoredLinesList = getIgnoredLines(lines!);

        // Ignore the whole file.
        if (ignoredLinesList.length == 1 &&
            ignoredLinesList[0][0] == 0 &&
            ignoredLinesList[0][1] == lines.length) {
          continue;
        }
      }
    }

    // Move to the first ignore range.
    final ignoredLines = ignoredLinesList.iterator;
    var hasCurrent = ignoredLines.moveNext();

    bool _shouldIgnoreLine(Iterator<List<int>> ignoredRanges, int line) {
      if (!hasCurrent || ignoredRanges.current.isEmpty) {
        return false;
      }

      if (line < ignoredRanges.current[0]) return false;

      while (hasCurrent &&
          ignoredRanges.current.isNotEmpty &&
          ignoredRanges.current[1] < line) {
        hasCurrent = ignoredRanges.moveNext();
      }

      if (hasCurrent &&
          ignoredRanges.current.isNotEmpty &&
          ignoredRanges.current[0] <= line &&
          line <= ignoredRanges.current[1]) {
        return true;
      }

      return false;
    }

    void addToMap(Map<int, int> map, int line, int count) {
      final oldCount = map.putIfAbsent(line, () => 0);
      map[line] = count + oldCount;
    }

    void fillHitMap(List hits, Map<int, int> hitMap) {
      // Ignore line annotations require hits to be sorted.
      hits = _sortHits(hits);
      // hits is a flat array of the following format:
      // [ <line|linerange>, <hitcount>,...]
      // line: number.
      // linerange: '<line>-<line>'.
      for (var i = 0; i < hits.length; i += 2) {
        final k = hits[i];
        if (k is int) {
          // Single line.
          if (_shouldIgnoreLine(ignoredLines, k)) continue;

          addToMap(hitMap, k, hits[i + 1] as int);
        } else if (k is String) {
          // Linerange. We expand line ranges to actual lines at this point.
          final splitPos = k.indexOf('-');
          final start = int.parse(k.substring(0, splitPos));
          final end = int.parse(k.substring(splitPos + 1));
          for (var j = start; j <= end; j++) {
            if (_shouldIgnoreLine(ignoredLines, j)) continue;

            addToMap(hitMap, j, hits[i + 1] as int);
          }
        } else {
          throw StateError('Expected value of type int or String');
        }
      }
    }

    final sourceHitMap = globalHitMap.putIfAbsent(source, () => HitMap());
    fillHitMap(e['hits'] as List, sourceHitMap.lineHits);
    fillHitMap(e['funcHits'] as List, sourceHitMap.funcHits);
    final funcNames = e['funcNames'] as List;
    for (var i = 0; i < funcNames.length; i += 2) {
      sourceHitMap.funcNames[funcNames[i] as int] = funcNames[i + 1] as String;
    }
  }
  return globalHitMap;
}

/// Merges [newMap] into [result].
void mergeHitmaps(Map<String, HitMap> newMap, Map<String, HitMap> result) {
  newMap.forEach((String file, HitMap v) {
    final fileResult = result[file];
    if (fileResult != null) {
      void mergeHitCounts(Map<int, int> src, Map<int, int> dest) {
        src.forEach((int line, int cnt) {
          final lineFileResult = dest[line];
          if (lineFileResult == null) {
            dest[line] = cnt;
          } else {
            dest[line] = lineFileResult + cnt;
          }
        });
      }

      mergeHitCounts(v.lineHits, fileResult.lineHits);
      mergeHitCounts(v.funcHits, fileResult.funcHits);
      final destFuncNames = fileResult.funcNames;
      v.funcNames.forEach((int line, String name) {
        if (destFuncNames.containsKey(line) && destFuncNames[line] != name) {
          print('Multiple functions defined on line $line of script $file');
        } else {
          destFuncNames[line] = name;
        }
      });
    } else {
      result[file] = v;
    }
  });
}

/// Generates a merged hitmap from a set of coverage JSON files.
Future<Map<String, HitMap>> parseCoverage(
  Iterable<File> files,
  int _, {
  bool checkIgnoredLines = false,
  String? packagesPath,
}) async {
  final globalHitmap = <String, HitMap>{};
  for (var file in files) {
    final contents = file.readAsStringSync();
    final jsonMap = json.decode(contents) as Map<String, dynamic>;
    if (jsonMap.containsKey('coverage')) {
      final jsonResult = jsonMap['coverage'] as List;
      mergeHitmaps(
        await createHitmap(
          jsonResult.cast<Map<String, dynamic>>(),
          checkIgnoredLines: checkIgnoredLines,
          packagesPath: packagesPath,
        ),
        globalHitmap,
      );
    }
  }
  return globalHitmap;
}

/// Returns a JSON hit map backward-compatible with pre-1.16.0 SDKs.
Map<String, dynamic> toScriptCoverageJson(Uri scriptUri, HitMap hits) {
  final json = <String, dynamic>{};
  List<T> flattenMap<T>(Map map) {
    final kvs = <T>[];
    map.forEach((k, v) {
      kvs.add(k as T);
      kvs.add(v as T);
    });
    return kvs;
  }

  json['source'] = '$scriptUri';
  json['script'] = {
    'type': '@Script',
    'fixedId': true,
    'id': 'libraries/1/scripts/${Uri.encodeComponent(scriptUri.toString())}',
    'uri': '$scriptUri',
    '_kind': 'library',
  };
  json['hits'] = flattenMap<int>(hits.lineHits);
  json['funcHits'] = flattenMap<int>(hits.funcHits);
  json['funcNames'] = flattenMap<dynamic>(hits.funcNames);
  return json;
}

/// Sorts the hits array based on the line numbers.
List _sortHits(List hits) {
  final structuredHits = <_HitInfo>[];
  for (var i = 0; i < hits.length - 1; i += 2) {
    final lineOrLineRange = hits[i];
    final firstLineInRange = lineOrLineRange is int
        ? lineOrLineRange
        : int.parse(lineOrLineRange.split('-')[0] as String);
    structuredHits.add(_HitInfo(firstLineInRange, hits[i], hits[i + 1] as int));
  }
  structuredHits.sort((a, b) => a.firstLine.compareTo(b.firstLine));
  return structuredHits
      .map((item) => [item.hitRange, item.hitCount])
      .expand((item) => item)
      .toList();
}
