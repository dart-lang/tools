// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: inference_failure_on_collection_literal
// ignore_for_file: inference_failure_on_instance_creation

import 'dart:convert';

import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

import 'common.dart';

const Map<String, dynamic> _mapWithNoSourceLocation = {
  'version': 3,
  'sourceRoot': '',
  'sources': ['input.dart'],
  'names': [],
  'mappings': 'A',
  'file': 'output.dart'
};

const Map<String, dynamic> _mapWithSourceLocation = {
  'version': 3,
  'sourceRoot': '',
  'sources': ['input.dart'],
  'names': [],
  'mappings': 'AAAA',
  'file': 'output.dart'
};

const Map<String, dynamic> _mapWithSourceLocationAndMissingNames = {
  'version': 3,
  'sourceRoot': '',
  'sources': ['input.dart'],
  'mappings': 'AAAA',
  'file': 'output.dart'
};

const Map<String, dynamic> _mapWithSourceLocationAndName = {
  'version': 3,
  'sourceRoot': '',
  'sources': ['input.dart'],
  'names': ['var'],
  'mappings': 'AAAAA',
  'file': 'output.dart'
};

const Map<String, dynamic> _mapWithSourceLocationAndName1 = {
  'version': 3,
  'sourceRoot': 'pkg/',
  'sources': ['input1.dart'],
  'names': ['var1'],
  'mappings': 'AAAAA',
  'file': 'output.dart'
};

const Map<String, dynamic> _mapWithSourceLocationAndName2 = {
  'version': 3,
  'sourceRoot': 'pkg/',
  'sources': ['input2.dart'],
  'names': ['var2'],
  'mappings': 'AAAAA',
  'file': 'output2.dart'
};

const Map<String, dynamic> _mapWithSourceLocationAndName3 = {
  'version': 3,
  'sourceRoot': 'pkg/',
  'sources': ['input3.dart'],
  'names': ['var3'],
  'mappings': 'AAAAA',
  'file': '3/output.dart'
};

const _sourceMapBundle = [
  _mapWithSourceLocationAndName1,
  _mapWithSourceLocationAndName2,
  _mapWithSourceLocationAndName3,
];

void main() {
  test('parse', () {
    var mapping = parseJson(expectedMap);
    check(outputVar1, mapping, inputVar1, false);
    check(outputVar2, mapping, inputVar2, false);
    check(outputFunction, mapping, inputFunction, false);
    check(outputExpr, mapping, inputExpr, false);
  });

  test('parse + json', () {
    var mapping = parse(jsonEncode(expectedMap));
    check(outputVar1, mapping, inputVar1, false);
    check(outputVar2, mapping, inputVar2, false);
    check(outputFunction, mapping, inputFunction, false);
    check(outputExpr, mapping, inputExpr, false);
  });

  test('parse with file', () {
    var mapping = parseJson(expectedMap);
    check(outputVar1, mapping, inputVar1, true);
    check(outputVar2, mapping, inputVar2, true);
    check(outputFunction, mapping, inputFunction, true);
    check(outputExpr, mapping, inputExpr, true);
  });

  test('parse with no source location', () {
    var map = parse(jsonEncode(_mapWithNoSourceLocation)) as SingleMapping;
    expect(map.lines.length, 1);
    expect(map.lines.first.entries.length, 1);
    var entry = map.lines.first.entries.first;

    expect(entry.column, 0);
    expect(entry.sourceUrlId, null);
    expect(entry.sourceColumn, null);
    expect(entry.sourceLine, null);
    expect(entry.sourceNameId, null);
  });

  test('parse with source location and no name', () {
    var map = parse(jsonEncode(_mapWithSourceLocation)) as SingleMapping;
    expect(map.lines.length, 1);
    expect(map.lines.first.entries.length, 1);
    var entry = map.lines.first.entries.first;

    expect(entry.column, 0);
    expect(entry.sourceUrlId, 0);
    expect(entry.sourceColumn, 0);
    expect(entry.sourceLine, 0);
    expect(entry.sourceNameId, null);
  });

  test('parse with source location and missing names entry', () {
    var map = parse(jsonEncode(_mapWithSourceLocationAndMissingNames))
        as SingleMapping;
    expect(map.lines.length, 1);
    expect(map.lines.first.entries.length, 1);
    var entry = map.lines.first.entries.first;

    expect(entry.column, 0);
    expect(entry.sourceUrlId, 0);
    expect(entry.sourceColumn, 0);
    expect(entry.sourceLine, 0);
    expect(entry.sourceNameId, null);
  });

  test('parse with source location and name', () {
    var map = parse(jsonEncode(_mapWithSourceLocationAndName)) as SingleMapping;
    expect(map.lines.length, 1);
    expect(map.lines.first.entries.length, 1);
    var entry = map.lines.first.entries.first;

    expect(entry.sourceUrlId, 0);
    expect(entry.sourceUrlId, 0);
    expect(entry.sourceColumn, 0);
    expect(entry.sourceLine, 0);
    expect(entry.sourceNameId, 0);
  });

  test('parse with source root', () {
    var inputMap = Map.from(_mapWithSourceLocation);
    inputMap['sourceRoot'] = '/pkg/';
    var mapping = parseJson(inputMap) as SingleMapping;
    expect(mapping.spanFor(0, 0)?.sourceUrl, Uri.parse('/pkg/input.dart'));
    expect(
        mapping
            .spanForLocation(
                SourceLocation(0, sourceUrl: Uri.parse('ignored.dart')))
            ?.sourceUrl,
        Uri.parse('/pkg/input.dart'));

    var newSourceRoot = '/new/';

    mapping.sourceRoot = newSourceRoot;
    inputMap['sourceRoot'] = newSourceRoot;

    expect(mapping.toJson(), equals(inputMap));
  });

  test('parse with map URL', () {
    var inputMap = Map.from(_mapWithSourceLocation);
    inputMap['sourceRoot'] = 'pkg/';
    var mapping = parseJson(inputMap, mapUrl: 'file:///path/to/map');
    expect(mapping.spanFor(0, 0)?.sourceUrl,
        Uri.parse('file:///path/to/pkg/input.dart'));
  });

  test('parse throws StateError on negative source url id', () {
    expect(
        () => parse(jsonEncode({
              'version': 3,
              'sources': ['a.dart'],
              'names': ['x'],
              'mappings': 'AAAAA,ADAAA'
            })),
        throwsA(isA<StateError>()));
  });

  test('parse throws StateError on negative source name id', () {
    expect(
        () => parse(jsonEncode({
              'version': 3,
              'sources': ['a.dart'],
              'names': ['x'],
              'mappings': 'AAAAA,AAAAD'
            })),
        throwsA(isA<StateError>()));
  });

  group('parse with bundle', () {
    var mapping =
        parseJsonExtended(_sourceMapBundle, mapUrl: 'file:///path/to/map');

    test('simple', () {
      expect(
          mapping
              .spanForLocation(SourceLocation(0,
                  sourceUrl: Uri.file('/path/to/output.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(
          mapping
              .spanForLocation(SourceLocation(0,
                  sourceUrl: Uri.file('/path/to/output2.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(
          mapping
              .spanForLocation(SourceLocation(0,
                  sourceUrl: Uri.file('/path/to/3/output.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));

      expect(
          mapping.spanFor(0, 0, uri: 'file:///path/to/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(
          mapping.spanFor(0, 0, uri: 'file:///path/to/output2.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(
          mapping
              .spanFor(0, 0, uri: 'file:///path/to/3/output.dart')
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
    });

    test('package uris', () {
      expect(
          mapping
              .spanForLocation(SourceLocation(0,
                  sourceUrl: Uri.parse('package:1/output.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(
          mapping
              .spanForLocation(SourceLocation(0,
                  sourceUrl: Uri.parse('package:2/output2.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(
          mapping
              .spanForLocation(SourceLocation(0,
                  sourceUrl: Uri.parse('package:3/output.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));

      expect(mapping.spanFor(0, 0, uri: 'package:1/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(mapping.spanFor(0, 0, uri: 'package:2/output2.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(mapping.spanFor(0, 0, uri: 'package:3/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
    });

    test('unmapped path', () {
      var span = mapping.spanFor(0, 0, uri: 'unmapped_output.dart')!;
      expect(span.sourceUrl, Uri.parse('unmapped_output.dart'));
      expect(span.start.line, equals(0));
      expect(span.start.column, equals(0));

      span = mapping.spanFor(10, 5, uri: 'unmapped_output.dart')!;
      expect(span.sourceUrl, Uri.parse('unmapped_output.dart'));
      expect(span.start.line, equals(10));
      expect(span.start.column, equals(5));
    });

    test('missing path', () {
      expect(() => mapping.spanFor(0, 0), throwsA(anything));
    });

    test('incomplete paths', () {
      expect(mapping.spanFor(0, 0, uri: 'output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(mapping.spanFor(0, 0, uri: 'output2.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(mapping.spanFor(0, 0, uri: '3/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
    });

    test('parseExtended', () {
      var mapping = parseExtended(jsonEncode(_sourceMapBundle),
          mapUrl: 'file:///path/to/map');

      expect(mapping.spanFor(0, 0, uri: 'output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(mapping.spanFor(0, 0, uri: 'output2.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(mapping.spanFor(0, 0, uri: '3/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
    });

    test('build bundle incrementally', () {
      var mapping = MappingBundle();

      mapping.addMapping(parseJson(_mapWithSourceLocationAndName1,
          mapUrl: 'file:///path/to/map') as SingleMapping);
      expect(mapping.spanFor(0, 0, uri: 'output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));

      expect(mapping.containsMapping('output2.dart'), isFalse);
      mapping.addMapping(parseJson(_mapWithSourceLocationAndName2,
          mapUrl: 'file:///path/to/map') as SingleMapping);
      expect(mapping.containsMapping('output2.dart'), isTrue);
      expect(mapping.spanFor(0, 0, uri: 'output2.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));

      expect(mapping.containsMapping('3/output.dart'), isFalse);
      mapping.addMapping(parseJson(_mapWithSourceLocationAndName3,
          mapUrl: 'file:///path/to/map') as SingleMapping);
      expect(mapping.containsMapping('3/output.dart'), isTrue);
      expect(mapping.spanFor(0, 0, uri: '3/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
    });

    // Test that the source map can handle cases where the uri passed in is
    // not from the expected host but it is still unambiguous which source
    // map should be used.
    test('different paths', () {
      expect(
          mapping
              .spanForLocation(SourceLocation(0,
                  sourceUrl: Uri.parse('http://localhost/output.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(
          mapping
              .spanForLocation(SourceLocation(0,
                  sourceUrl: Uri.parse('http://localhost/output2.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(
          mapping
              .spanForLocation(SourceLocation(0,
                  sourceUrl: Uri.parse('http://localhost/3/output.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));

      expect(
          mapping.spanFor(0, 0, uri: 'http://localhost/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(
          mapping
              .spanFor(0, 0, uri: 'http://localhost/output2.dart')
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(
          mapping
              .spanFor(0, 0, uri: 'http://localhost/3/output.dart')
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
    });
  });

  test('parse and re-emit', () {
    for (var expected in [
      expectedMap,
      _mapWithNoSourceLocation,
      _mapWithSourceLocation,
      _mapWithSourceLocationAndName
    ]) {
      var mapping = parseJson(expected) as SingleMapping;
      expect(mapping.toJson(), equals(expected));

      mapping = parseJsonExtended(expected) as SingleMapping;
      expect(mapping.toJson(), equals(expected));
    }

    var mapping = parseJsonExtended(_sourceMapBundle) as MappingBundle;
    expect(mapping.toJson(), equals(_sourceMapBundle));
  });

  test('parse extensions', () {
    var map = Map.from(expectedMap);
    map['x_foo'] = 'a';
    map['x_bar'] = [3];
    var mapping = parseJson(map) as SingleMapping;
    expect(mapping.toJson(), equals(map));
    expect(mapping.extensions['x_foo'], equals('a'));
    expect((mapping.extensions['x_bar'] as List).first, equals(3));
  });

  group('ECMA-426 scopes, ranges, and ignoreList', () {
    Map<String, dynamic> buildEcma426WasmMap() => <String, dynamic>{
          'version': 3,
          'file': 'out.wasm',
          'sourceRoot': '',
          'sources': ['sdk/core.dart', 'app/main.dart'],
          'names': ['inlinedLeaf', 'caller', 'Class1'],
          'mappings': 'AAAA,ECAA',
          'ignoreList': [0],
          'scopes': ['BAAA,CAAE', null],
          'ranges': ['EAAA,IAAC,FAAK'],
          'x_org_dartlang_dart2js': {
            'minified_names': {'global': 'Class1,2', 'instance': ''},
          },
        };

    test(
        'preserves scopes, ranges, ignoreList, and x_ extensions on round-trip',
        () {
      var inputMap = buildEcma426WasmMap();
      var mapping = parse(jsonEncode(inputMap)) as SingleMapping;

      expect(mapping.ignoreList, equals([0]));
      expect(mapping.scopes, equals(['BAAA,CAAE', null]));
      expect(mapping.ranges, equals(['EAAA,IAAC,FAAK']));
      expect(
        mapping.extensions['x_org_dartlang_dart2js'],
        equals({
          'minified_names': {'global': 'Class1,2', 'instance': ''},
        }),
      );
      expect(mapping.toJson(), equals(inputMap));
    });

    test('preserves ECMA-426 fields when rewriting sourceRoot and urls', () {
      var inputMap = buildEcma426WasmMap();
      var mapping = parseJson(inputMap) as SingleMapping;

      mapping.sourceRoot = 'g3-root/';
      mapping.urls[0] = 'dart/sdk/core.dart';
      mapping.urls[1] = 'my_pkg/main.dart';

      var encoded =
          jsonDecode(jsonEncode(mapping.toJson())) as Map<String, dynamic>;
      expect(encoded['sourceRoot'], equals('g3-root/'));
      expect(encoded['sources'],
          equals(['dart/sdk/core.dart', 'my_pkg/main.dart']));
      expect(encoded['ignoreList'], equals([0]));
      expect(encoded['scopes'], equals(['BAAA,CAAE', null]));
      expect(encoded['ranges'], equals(['EAAA,IAAC,FAAK']));
      expect(
        encoded['x_org_dartlang_dart2js'],
        equals(inputMap['x_org_dartlang_dart2js']),
      );
    });

    test('preserves ECMA-426 fields across MappingBundle round-trip', () {
      var map1 = buildEcma426WasmMap();
      var map2 = <String, dynamic>{
        ...buildEcma426WasmMap(),
        'file': 'out_part1.wasm',
        'scopes': [null, 'BAGA,CAAI'],
        'ranges': ['EAIA,FAAM'],
      };
      var bundle = parseExtended(jsonEncode([map1, map2])) as MappingBundle;
      expect(bundle.toJson(), equals([map1, map2]));
    });

    test('omits scopes, ranges, and ignoreList when null', () {
      var fromJsonMap = parseJson(expectedMap) as SingleMapping;
      expect(fromJsonMap.ignoreList, isNull);
      expect(fromJsonMap.scopes, isNull);
      expect(fromJsonMap.ranges, isNull);
      expect(fromJsonMap.toJson().containsKey('ignoreList'), isFalse);
      expect(fromJsonMap.toJson().containsKey('scopes'), isFalse);
      expect(fromJsonMap.toJson().containsKey('ranges'), isFalse);

      var fromEntriesMap = SingleMapping.fromEntries(
        [Entry(inputVar1.start, outputVar1.start, 'var1')],
        'output.dart',
      );
      expect(fromEntriesMap.ignoreList, isNull);
      expect(fromEntriesMap.scopes, isNull);
      expect(fromEntriesMap.ranges, isNull);
      expect(fromEntriesMap.toJson().containsKey('scopes'), isFalse);
    });
  });

  group('source files', () {
    group('from fromEntries()', () {
      test('are null for non-FileLocations', () {
        var mapping = SingleMapping.fromEntries([
          Entry(SourceLocation(10, line: 1, column: 8), outputVar1.start, null)
        ]);
        expect(mapping.files, equals([null]));
      });

      test("use a file location's file", () {
        var mapping = SingleMapping.fromEntries(
            [Entry(inputVar1.start, outputVar1.start, null)]);
        expect(mapping.files, equals([input]));
      });
    });

    group('from parse()', () {
      group('are null', () {
        test('with no sourcesContent field', () {
          var mapping = parseJson(expectedMap) as SingleMapping;
          expect(mapping.files, equals([null]));
        });

        test('with null sourcesContent values', () {
          var map = Map.from(expectedMap);
          map['sourcesContent'] = [null];
          var mapping = parseJson(map) as SingleMapping;
          expect(mapping.files, equals([null]));
        });

        test('with a too-short sourcesContent', () {
          var map = Map.from(expectedMap);
          map['sourcesContent'] = [];
          var mapping = parseJson(map) as SingleMapping;
          expect(mapping.files, equals([null]));
        });
      });

      test('are parsed from sourcesContent', () {
        var map = Map.from(expectedMap);
        map['sourcesContent'] = ['hello, world!'];
        var mapping = parseJson(map) as SingleMapping;

        var file = mapping.files[0]!;
        expect(file.url, equals(Uri.parse('input.dart')));
        expect(file.getText(0), equals('hello, world!'));
      });
    });
  });
}
