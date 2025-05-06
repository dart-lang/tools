// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'hitmap.dart';
import 'resolver.dart';

@Deprecated('Migrate to FileHitMapsFormatter')
abstract class Formatter {
  /// Returns the formatted coverage data.
  Future<String> format(Map<String, Map<int, int>> hitmap);
}

/// Converts the given hitmap to lcov format and appends the result to
/// env.output.
///
/// Returns a [Future] that completes as soon as all map entries have been
/// emitted.
@Deprecated('Migrate to FileHitMapsFormatter.formatLcov')
class LcovFormatter implements Formatter {
  /// Creates a LCOV formatter.
  ///
  /// If [reportOn] is provided, coverage report output is limited to files
  /// prefixed with one of the paths included. If [basePath] is provided, paths
  /// are reported relative to that path.
  LcovFormatter(this.resolver, {this.reportOn, this.basePath});

  final Resolver resolver;
  final String? basePath;
  final List<String>? reportOn;

  @override
  Future<String> format(Map<String, Map<int, int>> hitmap) {
    return Future.value(hitmap
        .map((key, value) => MapEntry(key, HitMap(value)))
        .formatLcov(resolver, basePath: basePath, reportOn: reportOn));
  }
}

/// Converts the given hitmap to a pretty-print format and appends the result
/// to env.output.
///
/// Returns a [Future] that completes as soon as all map entries have been
/// emitted.
@Deprecated('Migrate to FileHitMapsFormatter.prettyPrint')
class PrettyPrintFormatter implements Formatter {
  /// Creates a pretty-print formatter.
  ///
  /// If [reportOn] is provided, coverage report output is limited to files
  /// prefixed with one of the paths included.
  PrettyPrintFormatter(this.resolver, this.loader,
      {this.reportOn, this.reportFuncs = false});

  final Resolver resolver;
  final Loader loader;
  final List<String>? reportOn;
  final bool reportFuncs;

  @override
  Future<String> format(Map<String, Map<int, int>> hitmap) {
    return hitmap.map((key, value) => MapEntry(key, HitMap(value))).prettyPrint(
        resolver, loader,
        reportOn: reportOn, reportFuncs: reportFuncs);
  }
}

extension FileHitMapsFormatter on Map<String, HitMap> {
  /// Converts the given hitmap to lcov format.
  ///
  /// If [reportOn] is provided, coverage report output is limited to files
  /// prefixed with one of the paths included. If [basePath] is provided, paths
  /// are reported relative to that path.
  String formatLcov(
    Resolver resolver, {
    String? basePath,
    List<String>? reportOn,
    Set<Glob>? ignoreGlobs,
    bool Function(String path)? includeUncovered,
  }) {
    final pathFilter = _getPathFilter(
      reportOn: reportOn,
      ignoreGlobs: ignoreGlobs,
    );

    final buf = StringBuffer();
    for (final entry in entries) {
      final v = entry.value;
      final lineHits = v.lineHits;
      final funcHits = v.funcHits;
      final funcNames = v.funcNames;
      final branchHits = v.branchHits;
      var source = resolver.resolve(entry.key);
      if (source == null) {
        continue;
      }

      if (!pathFilter(source)) {
        continue;
      }

      if (basePath != null) {
        source = p.relative(source, from: basePath);
      }

      buf.write('SF:$source\n');
      if (funcHits != null && funcNames != null) {
        for (final k in funcNames.keys.toList()..sort()) {
          buf.write('FN:$k,${funcNames[k]}\n');
        }
        for (final k in funcHits.keys.toList()..sort()) {
          if (funcHits[k]! != 0) {
            buf.write('FNDA:${funcHits[k]},${funcNames[k]}\n');
          }
        }
        buf.write('FNF:${funcNames.length}\n');
        buf.write('FNH:${funcHits.values.where((v) => v > 0).length}\n');
      }
      for (final k in lineHits.keys.toList()..sort()) {
        buf.write('DA:$k,${lineHits[k]}\n');
      }
      buf.write('LF:${lineHits.length}\n');
      buf.write('LH:${lineHits.values.where((v) => v > 0).length}\n');
      if (branchHits != null) {
        for (final k in branchHits.keys.toList()..sort()) {
          buf.write('BRDA:$k,0,0,${branchHits[k]}\n');
        }
      }
      buf.write('end_of_record\n');
    }

    if (includeUncovered != null) {
      // Step 1: Identify all Dart files
      final allFiles = _findAllDartFiles(reportOn: reportOn);
      print('detected files: $allFiles');

      // Step 2: Identify covered files
      final coveredFiles = Map.fromEntries(entries
          .where((entry) => entry.value.lineHits.values.any((hit) => hit > 0)));

      // check if the file is covered or no.
      final packageName = getPackageName();

      final uncoveredFiles = <String>[];
      for (final file in allFiles) {
        final pkgUri = toPackageUri(file, packageName);
        if (!coveredFiles.containsKey(pkgUri)) {
          uncoveredFiles.add(file);
        }
      }

      print('Uncovered Dart files:');
      for (final file in uncoveredFiles) {
        print(file);
      }

      //formatlcov for including uncovered.
      final uncoveredBuf = StringBuffer();

      for (final file in uncoveredFiles) {
        if (!pathFilter(file)) continue;

        final lines = File(file).readAsLinesSync();
        var displayPath = file;
        if (basePath != null) {
          displayPath = p.relative(file, from: basePath);
        }
        displayPath =
            displayPath.replaceAll('\\', '/'); // For Windows compatibility

        uncoveredBuf.writeln('SF:$displayPath');

        var lineNumber = 1;
        var realLines = 0;
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('//')) {
            uncoveredBuf.writeln('DA:$lineNumber,0');
            realLines++;
          }
          lineNumber++;
        }

        uncoveredBuf.writeln('LF:$realLines');
        uncoveredBuf.writeln('LH:0');
        uncoveredBuf.writeln('end_of_record');
      }

      buf.write(uncoveredBuf.toString());
    }
    return buf.toString();
  }

  /// Converts the given hitmap to a pretty-print format.
  ///
  /// If [reportOn] is provided, coverage report output is limited to files
  /// prefixed with one of the paths included. If [reportFuncs] is provided,
  /// only function coverage information will be shown.
  Future<String> prettyPrint(
    Resolver resolver,
    Loader loader, {
    List<String>? reportOn,
    String? basePath,
    Set<Glob>? ignoreGlobs,
    bool reportFuncs = false,
    bool reportBranches = false,
    bool Function(String path)? includeUncovered,
  }) async {
    final pathFilter = _getPathFilter(
      reportOn: reportOn,
      ignoreGlobs: ignoreGlobs,
    );
    final buf = StringBuffer();
    for (final entry in entries) {
      final v = entry.value;
      if (reportFuncs && v.funcHits == null) {
        throw StateError(
          'Function coverage formatting was requested, but the hit map is '
          'missing function coverage information. Did you run '
          'collect_coverage with the --function-coverage flag?',
        );
      }
      if (reportBranches && v.branchHits == null) {
        throw StateError(
            'Branch coverage formatting was requested, but the hit map is '
            'missing branch coverage information. Did you run '
            'collect_coverage with the --branch-coverage flag?');
      }
      final hits = reportFuncs
          ? v.funcHits!
          : reportBranches
              ? v.branchHits!
              : v.lineHits;
      final source = resolver.resolve(entry.key);
      if (source == null) {
        continue;
      }

      if (!pathFilter(source)) {
        continue;
      }

      final lines = await loader.load(source);
      if (lines == null) {
        continue;
      }
      buf.writeln(source);
      for (var line = 1; line <= lines.length; line++) {
        var prefix = _prefix;
        if (hits.containsKey(line)) {
          prefix = hits[line].toString().padLeft(_prefix.length);
        }
        buf.writeln('$prefix|${lines[line - 1]}');
      }
    }

    if (includeUncovered != null) {
      // Step 1: Identify all Dart files
      final allFiles = _findAllDartFiles(reportOn: reportOn);
      print('detected files: $allFiles');

      // Step 2: Identify covered files
      final coveredFiles = Map.fromEntries(entries
          .where((entry) => entry.value.lineHits.values.any((hit) => hit > 0)));

      // check if the file is covered or no.
      final packageName = getPackageName();

      final uncoveredFiles = <String>[];
      for (final file in allFiles) {
        final pkgUri = toPackageUri(file, packageName);
        if (!coveredFiles.containsKey(pkgUri)) {
          uncoveredFiles.add(file);
        }
      }

      print('Uncovered Dart files:');
      for (final file in uncoveredFiles) {
        print(file);
      }

      //formatlcov for including uncovered.
      final uncoveredBuf = StringBuffer();

      for (final file in uncoveredFiles) {
        if (!pathFilter(file)) continue;

        final lines = File(file).readAsLinesSync();
        var displayPath = file;
        if (basePath != null) {
          displayPath = p.relative(file, from: basePath);
        }
        displayPath =
            displayPath.replaceAll('\\', '/'); // For Windows compatibility

        uncoveredBuf.writeln('SF:$displayPath');

        var lineNumber = 1;
        var realLines = 0;
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('//')) {
            uncoveredBuf.writeln('DA:$lineNumber,0');
            realLines++;
          }
          lineNumber++;
        }

        uncoveredBuf.writeln('LF:$realLines');
        uncoveredBuf.writeln('LH:0');
        uncoveredBuf.writeln('end_of_record');
      }

      buf.write(uncoveredBuf.toString());
    }

    return buf.toString();
  }

  List<String> _findAllDartFiles({List<String>? reportOn}) {
    final files = <String>[];
    final roots = reportOn ?? ['lib/src'];
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      files.addAll(dartFiles.map((f) => f.path));
    }
    return files;
  }

  String getPackageName() {
    final pubspecFile = File('pubspec.yaml');
    final doc = loadYaml(pubspecFile.readAsStringSync());
    return doc['name'] as String;
  }

  String toPackageUri(String filePath, String packageName) {
    if (filePath.startsWith('lib${Platform.pathSeparator}')) {
      final relativePath = p.relative(filePath, from: 'lib');
      return 'package:$packageName/$relativePath'.replaceAll('\\', '/');
    }
    return filePath.replaceAll(
        '\\', '/'); // fallback (or handle `src/`, etc. if needed)
  }
}

const _prefix = '       ';

typedef _PathFilter = bool Function(String path);

_PathFilter _getPathFilter({List<String>? reportOn, Set<Glob>? ignoreGlobs}) {
  if (reportOn == null && ignoreGlobs == null) return (String path) => true;

  final absolutePaths = reportOn?.map(p.canonicalize).toList();

  return (String path) {
    final canonicalizedPath = p.canonicalize(path);

    if (absolutePaths != null &&
        !absolutePaths.any(canonicalizedPath.startsWith)) {
      return false;
    }
    if (ignoreGlobs != null &&
        ignoreGlobs.any((glob) => glob.matches(canonicalizedPath))) {
      return false;
    }

    return true;
  };
}
