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
    expect(cls.typeParameters, contains('T'));
    expect(
      cls.typeParameters['T'],
      isA<ApiInterfaceType>().having((t) => t.name, 'name', 'Object'),
    );
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
            'isPublicEntryPoint': true,
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

  Future<void> test_includeReferencedTypes() async {
    final summary = await _build({
      '$testPackageLibPath/file.dart': '''
import 'package:foo/foo.dart';
import 'src/private.dart';

class MyClass extends Foo implements PrivateInterface {}
''',
      '$testPackageLibPath/src/private.dart': '''
class PrivateInterface {}
''',
    }, customizer: _IncludeReferencedTypesCustomizer());

    final decodedMap = jsonDecode(summary) as Map<String, dynamic>;
    final rehydrated = ApiSummary.fromJson(decodedMap);

    // Verify package:foo/foo.dart is in the summary libraries
    final fooLib = rehydrated.libraries.firstWhere(
      (l) => l.uri == 'package:foo/foo.dart',
    );
    expect(fooLib.isPublicEntryPoint, isFalse);
    expect(fooLib.classes, hasLength(1));

    final fooClass = fooLib.classes.single;
    expect(fooClass.name, 'Foo');
    expect(fooClass.status, ApiDeclarationStatus.referenced);
    expect(fooClass.constructors, isEmpty);
    expect(fooClass.methods, isEmpty);

    // Verify private.dart is in the summary libraries
    final privateLib = rehydrated.libraries.firstWhere(
      (l) => l.uri == 'package:test/src/private.dart',
    );
    expect(privateLib.isPublicEntryPoint, isFalse);
    expect(privateLib.classes, hasLength(1));

    final privateClass = privateLib.classes.single;
    expect(privateClass.name, 'PrivateInterface');
    expect(privateClass.status, ApiDeclarationStatus.nonPublic);
    expect(privateClass.constructors, isEmpty);
    expect(privateClass.methods, isEmpty);

    // Verify dart:core is also in the summary libraries for Object
    final coreLib = rehydrated.libraries.firstWhere(
      (l) => l.uri == 'dart:core',
    );
    expect(coreLib.isPublicEntryPoint, isFalse);
    expect(coreLib.classes.map((c) => c.name), contains('Object'));
    final objectClass = coreLib.classes.firstWhere((c) => c.name == 'Object');
    expect(objectClass.status, ApiDeclarationStatus.referenced);
    expect(objectClass.constructors, isEmpty);
  }

  Future<void> test_constMembers() async {
    final summary = await _build({
      '$testPackageLibPath/file.dart': '''
class MyClass {
  static const int myConstField = 42;
  final int myFinalField;
  
  const MyClass(this.myFinalField);
  MyClass.nonConst() : myFinalField = 0;
}
const int myTopLevelConst = 100;
enum MyEnum {
  v1, v2;
  static const int customConst = 3;
}
''',
    });

    final decodedMap = jsonDecode(summary) as Map<String, dynamic>;
    final rehydrated = ApiSummary.fromJson(decodedMap);

    final lib = rehydrated.libraries.single;

    // Verify top-level const
    final topLevelConst = lib.functions.firstWhere(
      (e) => e.name == 'myTopLevelConst',
    );
    expect(topLevelConst.kind, ApiExecutableKind.getter);
    expect(topLevelConst.isConst, isTrue);
    expect(topLevelConst.isEnumConstant, isFalse);
    expect(topLevelConst.constantValue, '100');

    final myClass = lib.classes.single;

    // Verify static const field (getter)
    final constField = myClass.methods.firstWhere(
      (e) => e.name == 'myConstField',
    );
    expect(constField.kind, ApiExecutableKind.getter);
    expect(constField.isConst, isTrue);
    expect(constField.isEnumConstant, isFalse);
    expect(constField.constantValue, '42');

    // Verify final field (getter)
    final finalField = myClass.methods.firstWhere(
      (e) => e.name == 'myFinalField',
    );
    expect(finalField.kind, ApiExecutableKind.getter);
    expect(finalField.isConst, isFalse);
    expect(finalField.isEnumConstant, isFalse);
    expect(finalField.constantValue, isNull);

    // Verify const constructor
    final constConstructor = myClass.constructors.firstWhere(
      (e) => e.name == 'new',
    );
    expect(constConstructor.kind, ApiExecutableKind.constructor);
    expect(constConstructor.isConst, isTrue);

    // Verify non-const constructor
    final nonConstConstructor = myClass.constructors.firstWhere(
      (e) => e.name == 'nonConst',
    );
    expect(nonConstConstructor.kind, ApiExecutableKind.constructor);
    expect(nonConstConstructor.isConst, isFalse);

    // Verify enum constants
    final myEnum = lib.enums.single;
    final enumVal1 = myEnum.methods.firstWhere((e) => e.name == 'v1');
    expect(enumVal1.isConst, isTrue);
    expect(enumVal1.isEnumConstant, isTrue);
    expect(enumVal1.constantValue, isNull);

    final enumCustomConst = myEnum.methods.firstWhere(
      (e) => e.name == 'customConst',
    );
    expect(enumCustomConst.isConst, isTrue);
    expect(enumCustomConst.isEnumConstant, isFalse);
    expect(enumCustomConst.constantValue, '3');

    final enumValues = myEnum.methods.firstWhere((e) => e.name == 'values');
    expect(enumValues.isConst, isTrue);
    expect(enumValues.isEnumConstant, isFalse);
    expect(enumValues.constantValue, isNull);
  }

  Future<void> test_parameterDefaultValues() async {
    final summary = await _build({
      '$testPackageLibPath/file.dart': r'''
enum Mode { fast, safe }

class Config {
  final int count;
  final String label;
  const Config(this.count, {this.label = 'default'});
}

class _PrivateSentinel {
  const _PrivateSentinel();
}

class PublicWithPrivateCtor {
  const PublicWithPrivateCtor._();
}

class Base {
  const Base({int inherited = 10, int overridden = 20, int? noDefault});
}

class Sub extends Base {
  const Sub({super.inherited, super.overridden = 99, super.noDefault});
}

void configure(
  int requiredPositional, [
  int optionalInt = 7,
  int? implicitNull,
  int? explicitNull = null,
]) {}

void withNamed({
  required int req,
  int count = 42,
  String name = 'a\nb',
  Mode mode = Mode.safe,
  Config config = const Config(1, label: 'ok'),
  Object redactedClass = const _PrivateSentinel(),
  Object redactedCtor = const PublicWithPrivateCtor._(),
  Object redactedTypeArg = const <_PrivateSentinel>[],
}) {}
''',
    });

    final decodedMap = jsonDecode(summary) as Map<String, dynamic>;
    final rehydrated = ApiSummary.fromJson(decodedMap);
    final lib = rehydrated.libraries.singleWhere(
      (l) => l.uri == 'package:test/file.dart',
    );

    final configureFn = lib.functions.firstWhere((f) => f.name == 'configure');
    final posParams = {
      for (final p in configureFn.parameters) p.name: p.defaultValue,
    };
    expect(posParams, {
      'requiredPositional': null,
      'optionalInt': '7',
      'implicitNull': null,
      'explicitNull': null,
    });

    final withNamedFn = lib.functions.firstWhere((f) => f.name == 'withNamed');
    final namedParams = {
      for (final p in withNamedFn.parameters) p.name: p.defaultValue,
    };
    expect(namedParams, {
      'req': null,
      'count': '42',
      'name': r"'a\nb'",
      'mode': 'Mode.safe',
      'config': "Config(1, label: 'ok')",
      'redactedClass': null,
      'redactedCtor': null,
      'redactedTypeArg': null,
    });

    final subClass = lib.classes.firstWhere((c) => c.name == 'Sub');
    final subCtor = subClass.constructors.single;
    final subParams = {
      for (final p in subCtor.parameters) p.name: p.defaultValue,
    };
    expect(subParams, {
      'inherited': '10',
      'overridden': '99',
      'noDefault': null,
    });

    final rendered = rehydrated.toString();
    expect(
      rendered,
      contains(
        'configure (function: void Function(int, '
        '[int = 7, int?, int?]))',
      ),
    );
    expect(
      rendered,
      contains(
        "Config(1, label: 'ok'), "
        'int count = 42, '
        'Mode mode = Mode.safe, '
        r"String name = 'a\nb', "
        'Object redactedClass, '
        'Object redactedCtor, '
        'Object redactedTypeArg, '
        'required int req',
      ),
    );
    expect(
      rendered,
      contains(
        'new (const constructor: Sub Function({int inherited = 10, '
        'int? noDefault, int overridden = 99}))',
      ),
    );
  }

  Future<void> test_constantValues() async {
    final summary = await _build({
      '$testPackageLibPath/file.dart': r'''
enum Color { red, blue }

enum _PrivateEnum { a }

class _Private {
  const _Private();
}

void publicTopFunc() {}
void _privateTopFunc() {}

class Holder {
  final int x;
  final String label;
  final bool flag;
  const Holder(this.x, {this.label = '', this.flag = false});
  const Holder.named() : x = 0, label = 'named', flag = true;
  const Holder._private() : x = -1, label = '', flag = false;

  static void publicStatic() {}
  static void _privateStatic() {}
}

const bool kBool = false;
const int kInt = -42;
const double kDouble = 3.14;
const String kString = 'a\n\$b\'c\\d';
const Object? kNull = null;
const Symbol kPublicSymbol = #mySymbol;
const Symbol kPrivateSymbol = #_secret;
const Type kSimpleType = int;
const Type kGenericType = Map<String, List<int?>>;
const Type kPrivateType = _Private;
const Type kPrivateTypeArg = List<_Private>;
const List<int> kList = [1, 2];
const Set<String> kSet = {'a', 'b'};
const Map<String, int> kMap = {'x': 1};
const List<Object> kRedactedList = [_Private()];
const List<Object> kRedactedTypeArgList = <_Private>[];
const (int,) kSingleRecord = (1,);
const (int, {String a, bool b}) kNamedRecord = (1, b: true, a: 'hi');
const Color kEnum = Color.blue;
const Object kPrivateEnum = _PrivateEnum.a;
const void Function() kTopFunc = publicTopFunc;
const void Function() kPrivateTopFunc = _privateTopFunc;
const void Function() kStaticMethod = Holder.publicStatic;
const void Function() kPrivateStaticMethod = Holder._privateStatic;
const Holder Function(int, {bool flag, String label}) kCtorTearOff = Holder.new;
const Holder Function() kNamedCtorTearOff = Holder.named;
const Object kPrivateCtorTearOff = Holder._private;
const Holder kConstInstance = Holder(5, label: 'z', flag: true);
const Holder kNamedInstance = Holder.named();
const Holder kPrivateCtorInstance = Holder._private();
const Object kPrivateClassInstance = _Private();
int get kComputedGetter => 1;
''',
    });

    final decodedMap = jsonDecode(summary) as Map<String, dynamic>;
    final rehydrated = ApiSummary.fromJson(decodedMap);
    final lib = rehydrated.libraries.singleWhere(
      (l) => l.uri == 'package:test/file.dart',
    );

    final constants = {
      for (final f in lib.functions)
        if (f.kind == ApiExecutableKind.getter) f.name: f.constantValue,
    };

    expect(constants, {
      'kBool': 'false',
      'kInt': '-42',
      'kDouble': '3.14',
      'kString': r"'a\n\$b\'c\\d'",
      'kNull': 'null',
      'kPublicSymbol': '#mySymbol',
      'kPrivateSymbol': null,
      'kSimpleType': 'int',
      'kGenericType': 'Map<String, List<int?>>',
      'kPrivateType': null,
      'kPrivateTypeArg': null,
      'kList': '[1, 2]',
      'kSet': "{'a', 'b'}",
      'kMap': "{'x': 1}",
      'kRedactedList': null,
      'kRedactedTypeArgList': null,
      'kSingleRecord': '(1,)',
      'kNamedRecord': "(1, a: 'hi', b: true)",
      'kEnum': 'Color.blue',
      'kPrivateEnum': null,
      'kTopFunc': 'publicTopFunc',
      'kPrivateTopFunc': null,
      'kStaticMethod': 'Holder.publicStatic',
      'kPrivateStaticMethod': null,
      'kCtorTearOff': 'Holder.new',
      'kNamedCtorTearOff': 'Holder.named',
      'kPrivateCtorTearOff': null,
      'kConstInstance': "Holder(5, flag: true, label: 'z')",
      'kNamedInstance': 'Holder.named()',
      'kPrivateCtorInstance': null,
      'kPrivateClassInstance': null,
      'kComputedGetter': null,
    });

    final rendered = rehydrated.toString();
    expect(rendered, contains('kInt (static const getter: int = -42)'));
    expect(rendered, contains('kNull (static const getter: Object? = null)'));
    expect(
      rendered,
      contains('kPrivateClassInstance (static const getter: Object)\n'),
    );
  }

  Future<void> test_customizerConstructorFlags() async {
    final summary = await _build(
      {
        '$testPackageLibPath/file.dart': '''
import 'src/private.dart';

class PublicClass extends LeakedBase {}
''',
        '$testPackageLibPath/src/private.dart': '''
class LeakedBase {
  void leakedMethod(TransitiveLeak arg) {}
}
class TransitiveLeak {
  int get count => 0;
}
''',
      },
      customizer: const ApiSummaryCustomizer(
        includeImplicitNonPublicMembers: true,
      ),
    );

    final decodedMap = jsonDecode(summary) as Map<String, dynamic>;
    final rehydrated = ApiSummary.fromJson(decodedMap);

    final privateLib = rehydrated.libraries.firstWhere(
      (l) => l.uri == 'package:test/src/private.dart',
    );
    expect(privateLib.isPublicEntryPoint, isFalse);
    expect(
      privateLib.classes.map((c) => c.name),
      containsAll(['LeakedBase', 'TransitiveLeak']),
    );

    final leakedBase = privateLib.classes.firstWhere(
      (c) => c.name == 'LeakedBase',
    );
    expect(leakedBase.status, ApiDeclarationStatus.nonPublic);
    expect(leakedBase.methods.map((m) => m.name), contains('leakedMethod'));

    final transitiveLeak = privateLib.classes.firstWhere(
      (c) => c.name == 'TransitiveLeak',
    );
    expect(transitiveLeak.status, ApiDeclarationStatus.nonPublic);
    expect(transitiveLeak.methods.map((m) => m.name), contains('count'));
  }

  Future<String> _build(
    Map<String, String> files, {
    ApiSummaryCustomizer? customizer,
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
    final resolvedCustomizer = customizer ?? const ApiSummaryCustomizer();
    final package = await buildApiPackage('test', context, resolvedCustomizer);
    return jsonEncode(package.toJson());
  }
}

base class _IncludeReferencedTypesCustomizer extends ApiSummaryCustomizer {
  @override
  bool get includeReferencedTypes => true;
}
