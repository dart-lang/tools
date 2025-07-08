// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:vm_service/vm_service.dart';
import 'package:yaml/yaml.dart';

// TODO(cbracken) make generic
/// Retries the specified function with the specified interval and returns
/// the result on successful completion.
Future<dynamic> retry(Future Function() f, Duration interval,
    {Duration? timeout}) async {
  var keepGoing = true;

  Future<dynamic> withTimeout(Future Function() f, {Duration? duration}) {
    if (duration == null) {
      return f();
    }

    return f().timeout(duration, onTimeout: () {
      keepGoing = false;
      final msg = duration.inSeconds == 0
          ? '${duration.inMilliseconds}ms'
          : '${duration.inSeconds}s';
      throw StateError('Failed to complete within $msg');
    });
  }

  return withTimeout(() async {
    while (keepGoing) {
      try {
        return await f();
      } catch (_) {
        if (keepGoing) {
          await Future<dynamic>.delayed(interval);
        }
      }
    }
  }, duration: timeout);
}

/// Scrapes and returns the Dart VM service URI from a string, or null if not
/// found.
///
/// Potentially useful as a means to extract it from log statements.
Uri? extractVMServiceUri(String str) {
  final listeningMessageRegExp = RegExp(
    r'(?:Observatory|The Dart VM service is) listening on ((http|//)[a-zA-Z0-9:/=_\-\.\[\]]+)',
  );
  final match = listeningMessageRegExp.firstMatch(str);
  if (match != null) {
    return Uri.parse(match[1]!);
  }
  return null;
}

final multiLineIgnoreStart = RegExp(r'//\s*coverage:ignore-start[\w\d\s]*$');
final multiLineIgnoreEnd = RegExp(r'//\s*coverage:ignore-end[\w\d\s]*$');
final singleLineIgnore = RegExp(r'//\s*coverage:ignore-line[\w\d\s]*$');
final ignoreFile = RegExp(r'//\s*coverage:ignore-file[\w\d\s]*$');

/// Return list containing inclusive ranges of lines to be ignored by coverage.
/// If there is a error in balancing the statements it will throw a
/// [FormatException],
/// unless `coverage:ignore-file` is found.
/// Return null if the whole file is ignored.
///
/// ```
/// 1.  final str = ''; // coverage:ignore-line
/// 2.  final str = '';
/// 3.  final str = ''; // coverage:ignore-start
/// 4.  final str = '';
/// 5.  final str = ''; // coverage:ignore-end
/// ```
///
/// Returns
/// ```
/// [
///   [1,1],
///   [3,5],
/// ]
/// ```
///
/// The returned ranges are in sorted order, and never overlap.
List<List<int>>? getIgnoredLines(String filePath, List<String>? lines) {
  final ignoredLines = <List<int>>[];
  if (lines == null) return ignoredLines;

  FormatException? err;
  var i = 0;
  while (i < lines.length) {
    if (lines[i].contains(ignoreFile)) return null;

    if (lines[i].contains(multiLineIgnoreEnd)) {
      err ??= FormatException(
        'unmatched coverage:ignore-end found at $filePath:${i + 1}',
      );
    }

    if (lines[i].contains(singleLineIgnore)) ignoredLines.add([i + 1, i + 1]);

    if (lines[i].contains(multiLineIgnoreStart)) {
      final start = i;
      var isUnmatched = true;
      ++i;
      while (i < lines.length) {
        if (lines[i].contains(ignoreFile)) return null;
        if (lines[i].contains(multiLineIgnoreStart)) {
          err ??= FormatException(
            'coverage:ignore-start found at $filePath:${i + 1}'
            ' before previous coverage:ignore-start ended',
          );
          break;
        }

        if (lines[i].contains(multiLineIgnoreEnd)) {
          ignoredLines.add([start + 1, i + 1]);
          isUnmatched = false;
          break;
        }
        ++i;
      }

      if (isUnmatched) {
        err ??= FormatException(
          'coverage:ignore-start found at $filePath:${start + 1}'
          ' has no matching coverage:ignore-end',
        );
      }
    }
    ++i;
  }

  if (err == null) {
    return ignoredLines;
  }

  throw err;
}

extension IgnoredLinesContains on List<List<int>> {
  /// Returns whether this list of line ranges contains the given line.
  bool ignoredContains(int line) {
    if (length == 0 || this[0][0] > line) return false;

    // Binary search for the range with the largest start value that is <= line.
    var lo = 0;
    var hi = length;
    while (lo < hi - 1) {
      final mid = lo + (hi - lo) ~/ 2;
      if (this[mid][0] <= line) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return this[lo][1] >= line;
  }
}

extension StandardOutExtension on Stream<List<int>> {
  Stream<String> lines() =>
      transform(const SystemEncoding().decoder).transform(const LineSplitter());
}

Future<Uri> serviceUriFromProcess(Stream<String> procStdout) {
  // Capture the VM service URI.
  final serviceUriCompleter = Completer<Uri>();
  procStdout.listen((line) {
    if (!serviceUriCompleter.isCompleted) {
      final serviceUri = extractVMServiceUri(line);
      if (serviceUri != null) {
        serviceUriCompleter.complete(serviceUri);
      }
    }
  });
  return serviceUriCompleter.future;
}

Future<List<IsolateRef>> getAllIsolates(VmService service) async =>
    (await service.getVM()).isolates ?? [];

String getPubspecPath(String root) => path.join(root, 'pubspec.yaml');

List<String> getAllWorkspaceNames(String packageRoot) =>
    _getAllWorkspaceNames(packageRoot, <String>[]);

List<String> _getAllWorkspaceNames(String packageRoot, List<String> results) {
  final pubspec = _loadPubspec(packageRoot);
  results.add(pubspec['name'] as String);
  for (final workspace in pubspec['workspace'] as YamlList? ?? []) {
    _getAllWorkspaceNames(path.join(packageRoot, workspace as String), results);
  }
  return results;
}

YamlMap _loadPubspec(String packageRoot) {
  final pubspecPath = getPubspecPath(packageRoot);
  final yaml = File(pubspecPath).readAsStringSync();
  return loadYaml(yaml, sourceUrl: Uri.file(pubspecPath)) as YamlMap;
}
