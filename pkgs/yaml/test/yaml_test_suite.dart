// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Represents a single test case from the yaml-test-suite.
typedef YamlTestCase = ({
  /// The unique identifier of the test case, typically the filename and an
  /// index (e.g., '229Q-0').
  String id,

  /// The URI of the test file this case was loaded from.
  Uri file,

  /// A short descriptive phrase for the test. Uses the [id] as a fallback if
  /// not provided.
  String name,

  /// The origin of the test, such as a link to the YAML spec or the author.
  String? from,

  /// A set of tags categorizing the test.
  Set<String> tags,

  /// The actual YAML string payload that the parser is meant to process.
  String yaml,

  /// A boolean indicating if the yaml input is invalid and the parser must
  /// throw an error.
  bool fail,

  /// A boolean indicating if the test suite descriptor included a 'json' field.
  bool hasJson,

  /// The expected parsed result in JSON format.
  /// If there are no json docs, the list is empty.
  List<({String source, Object? json})> json,

  /// A low-level event stream representation.
  String? tree,

  /// The expected output string if a YAML dumper were to reconstruct the YAML.
  String? dump,

  /// The expected output string if a YAML emitter were to reconstruct the YAML.
  String? emit,
});

/// Loads all test cases from the yaml-test-suite descriptors.
Iterable<YamlTestCase> loadYamlTestSuite() sync* {
  final libUri = Isolate.resolvePackageUriSync(Uri.parse('package:yaml/'))!;
  final srcUri = libUri.resolve('../third_party/yaml-test-suite/src');
  final srcDir = Directory.fromUri(srcUri);

  final files = srcDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yaml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    throw AssertionError('yaml-test-suite files not found');
  }

  for (final file in files) {
    final content = file.readAsStringSync();
    // Load the yaml test descriptor
    final yamlList = loadYaml(content) as YamlList;

    final fileId = file.uri.pathSegments.last.replaceAll('.yaml', '');

    for (var i = 0; i < yamlList.length; i++) {
      final item = yamlList[i] as YamlMap;
      final id = '$fileId-$i';

      // Parse tags into a Set<String>
      final tagsStr = item['tags'] as String?;
      final tags = tagsStr != null && tagsStr.trim().isNotEmpty
          ? tagsStr.trim().split(RegExp(r'\s+')).toSet()
          : const <String>{};

      yield (
        id: id,
        file: file.uri,
        name:
            item['name'] as String? ?? id, // Fallback to id if name is missing
        from: item['from'] as String?,
        tags: tags,
        yaml: _replaceSpecialCharacters(item['yaml'] as String? ?? ''),
        fail: item['fail'] as bool? ?? false,
        hasJson: item['json'] != null,
        json: (() {
          final j = item['json'] as String?;
          if (j == null) return <({String source, Object? json})>[];
          return splitMultiJson(j)
              .map((s) => (source: s, json: jsonDecode(s)))
              .toList();
        })(),
        tree: item['tree'] as String?,
        dump: item['dump'] as String?,
        emit: item['emit'] as String?,
      );
    }
  }
}

/// Replaces special characters used by yaml-test-suite to visualize invisible
/// characters.
/// See: https://github.com/yaml/yaml-test-suite/blob/main/ReadMe.md#special-characters
String _replaceSpecialCharacters(String input) => input
    .replaceAll('␣', ' ')
    .replaceAll(RegExp(r'—*»'), '\t')
    .replaceAll('↵', '')
    .replaceAll('←', '\r')
    .replaceAll('⇔', '\uFEFF')
    .replaceFirst(RegExp(r'∎\n?$'), '');

extension YamlTestCaseExtension on YamlTestCase {
  void runTest() {
    if (this.fail) {
      try {
        loadYamlStream(this.yaml);
      } on YamlException {
        return;
      }
      throw TestFailure('Expected parsing to fail');
    }

    final docs = loadYamlStream(this.yaml);

    if (this.hasJson) {
      final actualDocs = docs.map(_toJson).toList();
      final expectedDocs = this.json.map((e) => e.json).toList();

      if (!const DeepCollectionEquality().equals(actualDocs, expectedDocs)) {
        const encoder = JsonEncoder.withIndent('  ');
        final actualJson = encoder.convert(actualDocs);
        final expectedStr = encoder.convert(expectedDocs);
        throw TestFailure(
            'JSON mismatch\nExpected:\n$expectedStr\nActual:\n$actualJson');
      }
    }
  }
}

/// Splits concatenated JSON documents into separate strings
Iterable<String> splitMultiJson(String json) sync* {
  final scanner = StringScanner(json);

  while (!scanner.isDone) {
    scanner.scan(RegExp(r'\s+'));
    if (scanner.isDone) break;

    final start = scanner.position;
    if (scanner.scan(RegExp(r'[{[]'))) {
      var depth = 1;
      while (depth > 0 && !scanner.isDone) {
        if (scanner.scan(RegExp(r'"(?:\\.|[^"\\])*"'))) continue;
        if (scanner.scan(RegExp(r'[{[]'))) {
          depth++;
        } else if (scanner.scan(RegExp(r'[}\]]'))) {
          depth--;
        } else {
          scanner.readChar();
        }
      }
    } else if (scanner.scan(RegExp(r'"(?:\\.|[^"\\])*"'))) {
      // scanned string
    } else {
      // primitive (number, true, false, null)
      scanner.scan(RegExp(r'[^ \n\r\t,\]}]+'));
    }
    yield json.substring(start, scanner.position);
  }
}

/// Recursively converts Yaml nodes to standard JSON-encodable Dart objects.
Object? _toJson(Object? node) {
  if (node is YamlMap) {
    final map = <String, Object?>{};
    for (final entry in node.entries) {
      final key = entry.key;
      map[_toJson(key)?.toString() ?? 'null'] = _toJson(entry.value);
    }
    return map;
  } else if (node is YamlList) {
    return node.map(_toJson).toList();
  } else if (node is YamlScalar) {
    final val = node.value;
    if (val is double) {
      if (val.isNaN) return '.nan';
      if (val == double.infinity) return '.inf';
      if (val == double.negativeInfinity) return '-.inf';
    }
    return val;
  }
  return node;
}
