// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:core';

import 'package:api_summary/api_summary.dart';
import 'package:api_summary/src/api_builder.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'test_utils.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ApiBuilderTest);
  });
}

@reflectiveTest
class ApiBuilderTest extends ApiSummaryTest {
  @override
  bool get addMetaPackageDep => true;

  @override
  void setUp() {
    newPackage('foo').addFile('lib/foo.dart', r'''
foo() {}
class Foo {}
''');
    super.setUp();
  }

  Future<void> test_fromJson_roundTrip() async {
    final summary = await _build({
      '$testPackageLibPath/file.dart': '''
class C<T extends Object> {
  int x = 0;
  void m(String requiredParam, {int? optionalParam}) {}
}
enum E { a, b }
extension Ext on int {}
''',
    });

    final decodedMap = jsonDecode(summary) as Map<String, dynamic>;
    final rehydrated = ApiSummary.fromJson(decodedMap);

    expect(rehydrated.name, 'test');
    expect(rehydrated.libraries, hasLength(1));

    final library = rehydrated.libraries.single;
    expect(library.uri, 'package:test/file.dart');
    expect(library.classes, hasLength(1));
    expect(library.enums, hasLength(1));
    expect(library.extensions, hasLength(1));

    final cls = library.classes.single;
    expect(cls.name, 'C');
    expect(cls.typeParameters, contains('T extends Object'));
    expect(cls.methods.map((m) => m.name), containsAll(['m', 'x', 'x=']));

    final methodM = cls.methods.firstWhere((m) => m.name == 'm');
    expect(
      methodM,
      isA<ApiExecutable>()
          .having((m) => m.returnType, 'returnType', isA<ApiVoidType>())
          .having((m) => m.parameters, 'parameters', hasLength(2)),
    );
    expect(
      methodM.parameters[0],
      isA<ApiParameter>()
          .having((p) => p.name, 'name', 'requiredParam')
          .having(
            (p) => p.type,
            'type',
            isA<ApiInterfaceType>().having((t) => t.name, 'name', 'String'),
          )
          .having((p) => p.isRequired, 'isRequired', isTrue),
    );
    expect(
      methodM.parameters[1],
      isA<ApiParameter>()
          .having((p) => p.name, 'name', 'optionalParam')
          .having(
            (p) => p.type,
            'type',
            isA<ApiInterfaceType>().having((t) => t.name, 'name', 'int'),
          )
          .having((p) => p.isNamed, 'isNamed', isTrue),
    );

    // Verify re-encoding produces the same output
    final reEncodedSummary = jsonEncode(rehydrated.toJson());
    expect(reEncodedSummary, summary);
  }

  Future<void> test_fromJson_roundTrip_comprehensive() async {
    final summary = await _build({
      '$testPackageLibPath/comprehensive.dart': '''
import 'package:meta/meta.dart';

@experimental
@deprecated
int topLevelVar = 42;

typedef IntAlias = int;
typedef BoundedAlias<T extends num> = Map<String, T>;

void takeRecord((int, {String name}) rec) {}
void takeFunc(int Function(String) fn) {}
void takeGenericFunc(void Function<T extends num>(T) fn) {}
void genericMethod<T extends num>(T t) {}

extension type Id(int value) {}
extension type IdBounded<T extends num>(int value) implements int {}

extension Ext<T extends num> on List<T> {}
mixin M on Object {}
''',
    });

    final decodedMap = jsonDecode(summary) as Map<String, dynamic>;
    final rehydrated = ApiSummary.fromJson(decodedMap);
    final reEncodedSummary = jsonEncode(rehydrated.toJson());
    expect(reEncodedSummary, summary);

    final renderedText = rehydrated.toString();
    expect(
      renderedText,
      equals('''
package:test/comprehensive.dart:
  topLevelVar (static getter: int, deprecated, experimental)
  topLevelVar= (static setter: int, deprecated, experimental)
  genericMethod (function: void Function<T extends num>(T))
  takeFunc (function: void Function(int Function(String)))
  takeGenericFunc (function: void Function(void Function<T extends num>(T)))
  takeRecord (function: void Function((int, {String name})))
  Id (extension type):
    new (constructor: Id Function(int))
    value (getter: int)
  IdBounded (extension type<T extends num> implements int):
    new (constructor: IdBounded<T> Function(int))
    value (getter: int)
  M (mixin on Object)
  Ext (extension on List<T>)
  BoundedAlias (type alias<T extends num> for Map<String, T>)
  IntAlias (type alias for int)
dart:core:
  List (referenced)
  Map (referenced)
  Object (referenced)
  String (referenced)
  int (referenced)
  num (referenced)
'''),
    );
  }

  Future<void> test_jsonOutput() async {
    final summary = await _build({
      '$testPackageLibPath/file.dart': '''
class C {
  int x = 0;
  void m() {}
}
''',
    });

    final decoded = jsonDecode(summary) as Map<String, dynamic>;
    expect(
      decoded,
      equals({
        'name': 'test',
        'libraries': [
          {
            'uri': 'package:test/file.dart',
            'classes': [
              {
                'name': 'C',
                'locationUri': 'package:test/file.dart',
                'supertype': {
                  'kind': 'interface',
                  'name': 'Object',
                  'libraryUri': 'dart:core',
                },
                'constructors': [
                  {
                    'name': 'new',
                    'locationUri': 'package:test/file.dart',
                    'kind': 'constructor',
                    'returnType': {
                      'kind': 'interface',
                      'name': 'C',
                      'libraryUri': 'package:test/file.dart',
                    },
                  },
                ],
                'methods': [
                  {
                    'name': 'm',
                    'locationUri': 'package:test/file.dart',
                    'kind': 'method',
                    'returnType': {'kind': 'void'},
                  },
                  {
                    'name': 'x',
                    'locationUri': 'package:test/file.dart',
                    'kind': 'getter',
                    'returnType': {
                      'kind': 'interface',
                      'name': 'int',
                      'libraryUri': 'dart:core',
                    },
                  },
                  {
                    'name': 'x=',
                    'locationUri': 'package:test/file.dart',
                    'kind': 'setter',
                    'returnType': {'kind': 'void'},
                    'parameters': [
                      {
                        'name': 'value',
                        'type': {
                          'kind': 'interface',
                          'name': 'int',
                          'libraryUri': 'dart:core',
                        },
                        'isRequired': true,
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      }),
    );
  }

  Future<String> _build(
    Map<String, String> files, {
    ApiSummaryCustomizer Function()? createCustomizer,
  }) async {
    // Create all the files.
    files.forEach(newFile);

    // As a sanity check, make sure there are no errors in any of the files.
    for (final file in files.keys) {
      if (file.endsWith('.dart')) await assertNoDiagnosticsInFile(file);
    }

    // Generate the API description.
    final context = contextCollection.contextFor(
      convertPath(testPackageLibPath),
    );
    final customizer = createCustomizer?.call() ?? ApiSummaryCustomizer();
    final package = await buildApiPackage('test', context, customizer);
    return jsonEncode(package.toJson());
  }
}
