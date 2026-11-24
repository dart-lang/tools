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
                  {
                    'name': 'm',
                    'locationUri': 'package:test/file.dart',
                    'kind': 'method',
                    'returnType': {'kind': 'void'},
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
    }, customizer: const ApiSummaryCustomizer(includeReferencedTypes: true));

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

  Future<void> test_nonPublicSkeletonIncludedByDefault() async {
    final files = {
      '$testPackageLibPath/file.dart': '''
import 'package:foo/foo.dart';
import 'src/private.dart';

class MyClass extends Foo {
  void use(PrivateInterface p, HiddenExtType e) {}
}
''',
      '$testPackageLibPath/src/private.dart': '''
class _TransitiveBase {}
abstract interface class _TransitiveContract {}
class PrivateInterface extends _TransitiveBase implements _TransitiveContract {
  void hiddenMember() {}
}
extension type HiddenExtType(int value) {}
''',
    };

    final summary = await _build(files);
    final decodedMap = jsonDecode(summary) as Map<String, dynamic>;
    final rehydrated = ApiSummary.fromJson(decodedMap);

    expect(
      rehydrated.libraries.map((l) => l.uri),
      unorderedEquals([
        'package:test/file.dart',
        'package:test/src/private.dart',
      ]),
    );

    final privateLib = rehydrated.libraries.firstWhere(
      (l) => l.uri == 'package:test/src/private.dart',
    );
    expect(privateLib.isPublicEntryPoint, isFalse);
    final privateClass = privateLib.classes.single;
    expect(privateClass.name, 'PrivateInterface');
    expect(privateClass.status, ApiDeclarationStatus.nonPublic);
    expect(privateClass.supertype, isNull);
    expect(privateClass.interfaces, isEmpty);
    expect(privateClass.constructors, isEmpty);
    expect(privateClass.methods, isEmpty);

    final hiddenExt = privateLib.extensionTypes.single;
    expect(hiddenExt.name, 'HiddenExtType');
    expect(hiddenExt.status, ApiDeclarationStatus.nonPublic);
    expect(hiddenExt.constructors, isEmpty);
    expect(hiddenExt.methods, isEmpty);

    expect(
      rehydrated.toString(),
      allOf(
        contains('  HiddenExtType (non-public)\n'),
        contains('  PrivateInterface (non-public)\n'),
        isNot(contains('_TransitiveBase')),
        isNot(contains('_TransitiveContract')),
        isNot(contains('dart:core:')),
      ),
    );

    final detailedSummary = await _build(
      files,
      customizer: const ApiSummaryCustomizer(
        includeImplicitNonPublicMembers: true,
      ),
    );
    final detailedRehydrated = ApiSummary.fromJson(
      jsonDecode(detailedSummary) as Map<String, dynamic>,
    );
    expect(
      detailedRehydrated.toString(),
      contains('HiddenExtType (extension type, non-public):'),
    );
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

typedef PublicRecord = (int, {String label, bool flag});
typedef SinglePosRecord = (int,);
typedef PrivateRecord = (int, {_Private priv});
typedef PublicCallback =
    String Function<T extends num>(
      T, [
      int?,
      // ignore: avoid_positional_boolean_parameters
    ]);
typedef NamedCallback =
    void Function({required bool flag, String label});
typedef PrivateCallback = void Function(_Private);

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
const double kNaN = double.nan;
const double kInfinity = double.infinity;
const double kNegativeInfinity = double.negativeInfinity;
const String kString = 'a\n\$b\'c\\d';
const Object? kNull = null;
const Symbol kPublicSymbol = #mySymbol;
const Symbol kPrivateSymbol = #_secret;
const Type kSimpleType = int;
const Type kGenericType = Map<String, List<int?>>;
const Type kRecordType = PublicRecord;
const Type kSingleRecordType = SinglePosRecord;
const Type kPrivateRecordType = PrivateRecord;
const Type kFunctionType = PublicCallback;
const Type kNamedFunctionType = NamedCallback;
const Type kPrivateFunctionType = PrivateCallback;
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
      'kNaN': 'double.nan',
      'kInfinity': 'double.infinity',
      'kNegativeInfinity': 'double.negativeInfinity',
      'kString': r"'a\n\$b\'c\\d'",
      'kNull': 'null',
      'kPublicSymbol': '#mySymbol',
      'kPrivateSymbol': null,
      'kSimpleType': 'int',
      'kGenericType': 'Map<String, List<int?>>',
      'kRecordType': '(int, {bool flag, String label})',
      'kSingleRecordType': '(int,)',
      'kPrivateRecordType': null,
      'kFunctionType': 'String Function<T extends num>(T, [int?])',
      'kNamedFunctionType': 'void Function({required bool flag, String label})',
      'kPrivateFunctionType': null,
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

  Future<void> test_canonicalSortingMatchesTextOrder() async {
    final summary = await _build({
      '$testPackageLibPath/file.dart': '''
void aTopFunc(int posZ, int posA, {int? zNamed, required int aNamed}) {}
set top(int value) {}
int get top => 0;
int get top9 => 0;
set top9(int value) {}

class C {
  C.alpha();
  C({int? zParam, required int aParam});

  void aInstanceMethod() {}
  set prop(int value) {}
  int get prop => 0;
  int get prop9 => 0;
  set prop9(int value) {}

  static void aStaticMethod() {}
  static set sProp(int value) {}
  static int get sProp => 0;
}
''',
    });

    final decodedMap = jsonDecode(summary) as Map<String, dynamic>;
    final rehydrated = ApiSummary.fromJson(decodedMap);
    final lib = rehydrated.libraries.single;

    expect(
      lib.functions.map((f) => f.name).toList(),
      equals(['top', 'top=', 'top9', 'top9=', 'aTopFunc']),
    );

    final topFunc = lib.functions.singleWhere((f) => f.name == 'aTopFunc');
    expect(
      topFunc.parameters.map((p) => p.name).toList(),
      equals(['posZ', 'posA', 'aNamed', 'zNamed']),
    );

    final cls = lib.classes.single;
    expect(
      cls.constructors.map((c) => c.name).toList(),
      equals(['new', 'alpha']),
    );
    expect(
      cls.constructors.first.parameters.map((p) => p.name).toList(),
      equals(['aParam', 'zParam']),
    );
    expect(
      cls.methods.map((m) => m.name).toList(),
      equals([
        'sProp',
        'sProp=',
        'aStaticMethod',
        'prop',
        'prop=',
        'prop9',
        'prop9=',
        'aInstanceMethod',
      ]),
    );

    expect(
      rehydrated.toString(),
      equals('''
package:test/file.dart:
  top (static getter: int)
  top= (static setter: int)
  top9 (static getter: int)
  top9= (static setter: int)
  aTopFunc (function: void Function(int, int, {required int aNamed, int? zNamed}))
  C (class extends Object):
    sProp (static getter: int)
    sProp= (static setter: int)
    aStaticMethod (static method: void Function())
    new (constructor: C Function({required int aParam, int? zParam}))
    alpha (constructor: C Function())
    prop (getter: int)
    prop= (setter: int)
    prop9 (getter: int)
    prop9= (setter: int)
    aInstanceMethod (method: void Function())
dart:core:
  Object (referenced)
  int (referenced)
'''),
    );
  }

  void test_fromJson_canonicalizesUnsortedInput() {
    final rehydrated = ApiSummary.fromJson({
      'name': 'pkg',
      'libraries': [
        {
          'uri': 'package:pkg/secondary.dart',
          'isPublicEntryPoint': true,
          'classes': <Map<String, dynamic>>[],
        },
        {
          'uri': 'package:pkg/pkg.dart',
          'isPublicEntryPoint': true,
          'classes': [
            {'name': 'ZClass'},
            {
              'name': 'AClass',
              'modifiers': ['sealed'],
              'immediateSubtypes': ['ZSub', 'ASub'],
              'constructors': [
                {
                  'name': 'fromJson',
                  'kind': 'constructor',
                  'returnType': {'kind': 'void'},
                },
                {
                  'name': 'new',
                  'kind': 'constructor',
                  'returnType': {'kind': 'void'},
                  'parameters': [
                    {
                      'name': 'posSecond',
                      'type': {'kind': 'dynamic'},
                      'isRequired': true,
                    },
                    {
                      'name': 'posFirst',
                      'type': {'kind': 'dynamic'},
                      'isRequired': true,
                    },
                    {
                      'name': 'zNamed',
                      'type': {
                        'kind': 'record',
                        'namedFields': [
                          {
                            'name': 'zField',
                            'type': {'kind': 'dynamic'},
                          },
                          {
                            'name': 'aField',
                            'type': {'kind': 'dynamic'},
                          },
                        ],
                      },
                      'isNamed': true,
                    },
                    {
                      'name': 'aNamed',
                      'type': {
                        'kind': 'function',
                        'returnType': {'kind': 'void'},
                        'parameters': [
                          {
                            'name': 'posFn',
                            'type': {'kind': 'dynamic'},
                            'isRequired': true,
                          },
                          {
                            'name': 'zFnNamed',
                            'type': {'kind': 'dynamic'},
                            'isNamed': true,
                          },
                          {
                            'name': 'aFnNamed',
                            'type': {'kind': 'dynamic'},
                            'isNamed': true,
                          },
                        ],
                      },
                      'isNamed': true,
                    },
                  ],
                },
              ],
              'methods': [
                {
                  'name': 'instMethod',
                  'kind': 'method',
                  'returnType': {'kind': 'void'},
                },
                {
                  'name': 'a=',
                  'kind': 'setter',
                  'returnType': {'kind': 'void'},
                  'parameters': [
                    {
                      'name': 'v',
                      'type': {'kind': 'dynamic'},
                      'isRequired': true,
                    },
                  ],
                },
                {
                  'name': 'a9',
                  'kind': 'getter',
                  'returnType': {'kind': 'dynamic'},
                },
                {
                  'name': 'a',
                  'kind': 'getter',
                  'returnType': {'kind': 'dynamic'},
                },
                {
                  'name': 'staticGetter',
                  'kind': 'getter',
                  'isStatic': true,
                  'returnType': {'kind': 'dynamic'},
                },
              ],
            },
          ],
          'functions': [
            {
              'name': 'topFn',
              'kind': 'function',
              'returnType': {'kind': 'void'},
            },
            {
              'name': 'x=',
              'kind': 'setter',
              'returnType': {'kind': 'void'},
              'parameters': [
                {
                  'name': 'v',
                  'type': {'kind': 'dynamic'},
                  'isRequired': true,
                },
              ],
            },
            {
              'name': 'x9',
              'kind': 'getter',
              'returnType': {'kind': 'dynamic'},
            },
            {
              'name': 'x',
              'kind': 'getter',
              'returnType': {'kind': 'dynamic'},
            },
          ],
        },
      ],
    });

    expect(
      rehydrated.libraries.map((l) => l.uri).toList(),
      equals(['package:pkg/pkg.dart', 'package:pkg/secondary.dart']),
    );

    final primaryLib = rehydrated.libraries.first;
    expect(
      primaryLib.classes.map((c) => c.name).toList(),
      equals(['AClass', 'ZClass']),
    );
    expect(
      primaryLib.functions.map((f) => f.name).toList(),
      equals(['x', 'x=', 'x9', 'topFn']),
    );

    final aClass = primaryLib.classes.first;
    expect(aClass.immediateSubtypes, equals(['ASub', 'ZSub']));
    expect(
      aClass.constructors.map((c) => c.name).toList(),
      equals(['new', 'fromJson']),
    );
    expect(
      aClass.methods.map((m) => m.name).toList(),
      equals(['staticGetter', 'a', 'a=', 'a9', 'instMethod']),
    );

    final newCtor = aClass.constructors.first;
    expect(
      newCtor.parameters.map((p) => p.name).toList(),
      equals(['posSecond', 'posFirst', 'aNamed', 'zNamed']),
    );

    final fnParamType = newCtor.parameters[2].type as ApiFunctionType;
    expect(
      fnParamType.parameters.map((p) => p.name).toList(),
      equals(['posFn', 'aFnNamed', 'zFnNamed']),
    );

    final recordParamType = newCtor.parameters[3].type as ApiRecordType;
    expect(
      recordParamType.namedFields.map((f) => f.name).toList(),
      equals(['aField', 'zField']),
    );
  }

  Future<void> test_unexportedSrcConstantsAndControlChars() async {
    final summary = await _build({
      '$testPackageLibPath/src/hidden.dart': '''
class Hidden {
  const Hidden();
  static void hiddenStatic() {}
}

enum HiddenEnum { a }

void hiddenTopFunc() {}

extension type const HiddenExt(Hidden value) implements Object {}
''',
      '$testPackageLibPath/src/reexported.dart': '''
class Reexported {
  const Reexported();
}

class ReexportedBox<T> {
  const ReexportedBox();
}
''',
      '$testPackageLibPath/file.dart': r'''
export 'src/reexported.dart';

import 'src/hidden.dart';
import 'src/reexported.dart';

extension type const Meters(int value) {}

void probe({
  Object hiddenInstance = const Hidden(),
  Object hiddenTypeArg = const <Hidden>[],
  Object hiddenMapTypeArg = const <String, Hidden>{},
  Object hiddenBox = const ReexportedBox<Hidden>(),
  Object reexported = const Reexported(),
  Object reexportedBox = const ReexportedBox<int>(),
  Meters distance = const Meters(5),
  String controls = 'a\u0085b\u009bc\u2028d\u2029e\uD800f café 🚀',
}) {}

const Object kHiddenInstance = Hidden();
const Object kHiddenEnum = HiddenEnum.a;
const void Function() kHiddenTopFunc = hiddenTopFunc;
const void Function() kHiddenStatic = Hidden.hiddenStatic;
const Object kHiddenCtorTearOff = Hidden.new;
const Type kHiddenType = Hidden;
const Type kHiddenGenericType = List<Hidden>;
const Object kHiddenExt = HiddenExt(Hidden());
const Object kReexported = Reexported();
const Object kReexportedBox = ReexportedBox<int>();
const Meters kMeters = Meters(5);
''',
    });

    final decodedMap = jsonDecode(summary) as Map<String, dynamic>;
    final rehydrated = ApiSummary.fromJson(decodedMap);
    final lib = rehydrated.libraries.singleWhere(
      (l) => l.uri == 'package:test/file.dart',
    );

    final probeFn = lib.functions.firstWhere((f) => f.name == 'probe');
    final probeDefaults = {
      for (final p in probeFn.parameters) p.name: p.defaultValue,
    };
    expect(probeDefaults, {
      'hiddenInstance': null,
      'hiddenTypeArg': null,
      'hiddenMapTypeArg': null,
      'hiddenBox': null,
      'reexported': 'Reexported()',
      'reexportedBox': 'ReexportedBox()',
      'distance': '5',
      'controls': r"'a\u{85}b\u{9b}c\u{2028}d\u{2029}e\u{d800}f café 🚀'",
    });

    final constants = {
      for (final f in lib.functions)
        if (f.kind == ApiExecutableKind.getter) f.name: f.constantValue,
    };
    expect(constants, {
      'kHiddenInstance': null,
      'kHiddenEnum': null,
      'kHiddenTopFunc': null,
      'kHiddenStatic': null,
      'kHiddenCtorTearOff': null,
      'kHiddenType': null,
      'kHiddenGenericType': null,
      'kHiddenExt': null,
      'kReexported': 'Reexported()',
      'kReexportedBox': 'ReexportedBox()',
      'kMeters': '5',
    });
  }

  void test_apiClass_sealedSubtypesSerialization() {
    final plain = ApiClass(
      name: 'Plain',
      locationUri: 'package:pkg/pkg.dart',
      typeParameters: const {},
      interfaces: const [],
      mixins: const [],
      modifiers: const [ApiClassModifier.isSealed],
      constructors: const [],
      methods: const [],
    );
    expect(plain.immediateSubtypes, isEmpty);
    expect(plain.hasNonPublicSubtypes, isFalse);
    expect(plain.toJson(), {
      'name': 'Plain',
      'locationUri': 'package:pkg/pkg.dart',
      'modifiers': ['sealed'],
    });
    expect(
      ApiClass.fromJson(plain.toJson()),
      isA<ApiClass>()
          .having((c) => c.immediateSubtypes, 'immediateSubtypes', isEmpty)
          .having(
            (c) => c.hasNonPublicSubtypes,
            'hasNonPublicSubtypes',
            isFalse,
          ),
    );

    final mixed = ApiClass(
      name: 'Mixed',
      locationUri: 'package:pkg/pkg.dart',
      typeParameters: const {},
      interfaces: const [],
      mixins: const [],
      modifiers: const [ApiClassModifier.isSealed],
      immediateSubtypes: ['ZSub', 'ASub'],
      hasNonPublicSubtypes: true,
      constructors: const [],
      methods: const [],
    );
    expect(mixed.immediateSubtypes, ['ASub', 'ZSub']);
    expect(mixed.hasNonPublicSubtypes, isTrue);
    final mixedJson = mixed.toJson();
    expect(mixedJson, {
      'name': 'Mixed',
      'locationUri': 'package:pkg/pkg.dart',
      'modifiers': ['sealed'],
      'immediateSubtypes': ['ASub', 'ZSub'],
      'hasNonPublicSubtypes': true,
    });
    expect(mixedJson.keys.toList(), [
      'name',
      'locationUri',
      'modifiers',
      'immediateSubtypes',
      'hasNonPublicSubtypes',
    ]);

    final opaque = ApiClass(
      name: 'Opaque',
      locationUri: 'package:pkg/pkg.dart',
      typeParameters: const {},
      interfaces: const [],
      mixins: const [],
      modifiers: const [ApiClassModifier.isSealed],
      hasNonPublicSubtypes: true,
      constructors: const [],
      methods: const [],
    );
    expect(opaque.immediateSubtypes, isEmpty);
    expect(opaque.hasNonPublicSubtypes, isTrue);
    expect(opaque.toJson(), {
      'name': 'Opaque',
      'locationUri': 'package:pkg/pkg.dart',
      'modifiers': ['sealed'],
      'hasNonPublicSubtypes': true,
    });

    final summary = ApiSummary(
      name: 'pkg',
      libraries: [
        ApiLibrary(
          uri: 'package:pkg/pkg.dart',
          isPublicEntryPoint: true,
          classes: [plain, mixed, opaque],
          enums: const [],
          mixins: const [],
          extensions: const [],
          extensionTypes: const [],
          functions: const [],
          typeAliases: const [],
        ),
      ],
    );
    verifySummaryRoundTrip(summary);
    expect(summary.toString(), '''
package:pkg/pkg.dart:
  Mixed (class, sealed (immediate subtypes: ASub, ZSub, <non-public>))
  Opaque (class, sealed (immediate subtypes: <non-public>))
  Plain (class, sealed)
''');
  }

  Future<void> test_sealedSubtypes_genericsAndSubstitution() async {
    final summary = await _build({
      '$testPackageLibPath/src/generics.dart': '''
// ignore_for_file: unused_element
sealed class SExtra<T> {}
abstract interface class PubSame<T> implements SExtra<T> {}
final class _ImplWithExtra<T, U> extends SExtra<T> implements PubSame<T> {}

sealed class STight<T> {}
abstract interface class PubTight<T> implements STight<T> {}
final class _ImplTight<T extends num> extends STight<T>
    implements PubTight<T> {}

sealed class SPair<T> {}
abstract interface class PubPair<T> implements SPair<T> {}
final class _PairImpl<A, B> extends SPair<(A, B)> implements PubPair<(A, B)> {}

sealed class SNarrow<T> {}
final class IntPub extends SNarrow<int> {}
final class _StrPriv extends SNarrow<String> {}

sealed class SUnboundedFBound<T> {}
abstract interface class PubUnboundedFBound<T>
    implements SUnboundedFBound<T> {}
final class _ImplTighterFBound<T extends Comparable<T>>
    extends SUnboundedFBound<T>
    implements PubUnboundedFBound<T> {}

sealed class SValidExtra<T> {}
abstract interface class PubExtra<U> implements SValidExtra<int> {}
final class _ImplExtra extends SValidExtra<int> implements PubExtra<Object> {}

abstract class AstNode {}
abstract class CollectionElement implements AstNode {}
abstract class CollectionElementImpl implements CollectionElement {}
abstract class Statement implements AstNode {}
abstract class StatementImpl implements Statement {}
sealed class ForLoop<Body extends AstNode> implements AstNode {}
sealed class ForLoopImpl<Body extends AstNode, BodyImpl extends Body>
    implements ForLoop<Body> {}
abstract final class ForElement
    implements CollectionElement, ForLoop<CollectionElement> {}
final class ForElementImpl
    implements
        ForLoopImpl<CollectionElement, CollectionElementImpl>,
        ForElement {}
abstract final class ForStatement implements Statement, ForLoop<Statement> {}
final class ForStatementImpl
    implements ForLoopImpl<Statement, StatementImpl>, ForStatement {}

sealed class SFBound<T extends Comparable<T>> {}
abstract interface class PubFBound<U extends Comparable<U>>
    implements SFBound<U> {}
final class _ImplFBound<V extends Comparable<V>> extends SFBound<V>
    implements PubFBound<V> {}

sealed class SRecBound<A, B extends (A, {String tag})> {}
abstract interface class PubRecBound<X, Y extends (X, {String tag})>
    implements SRecBound<X, Y> {}
final class _ImplRecBound<P, Q extends (P, {String tag})>
    extends SRecBound<P, Q>
    implements PubRecBound<P, Q> {}

sealed class SNullBound<A, B extends A?> {}
abstract interface class PubNullBound<X, Y extends X?>
    implements SNullBound<X, Y> {}
final class _ImplNullBound<P, Q extends P?> extends SNullBound<P, Q>
    implements PubNullBound<P, Q> {}

typedef BoxAlias<T> = List<T>;
sealed class SAliasBound<A, B extends BoxAlias<A>> {}
abstract interface class PubAliasBound<X, Y extends BoxAlias<X>>
    implements SAliasBound<X, Y> {}
final class _ImplAliasBound<P, Q extends BoxAlias<P>> extends SAliasBound<P, Q>
    implements PubAliasBound<P, Q> {}

sealed class SContra<T> {}
abstract interface class PubContra<U extends void Function(U)>
    implements SContra<int> {}
final class _ImplContra extends SContra<int>
    implements PubContra<void Function(Object?)> {}

sealed class SCovFn<A, B extends A Function()> {}
abstract interface class PubCovFn<X, Y extends X Function()>
    implements SCovFn<X, Y> {}
final class _ImplCovFnExtra<P, Q extends P Function(), R>
    extends SCovFn<P, Q>
    implements PubCovFn<P, Q> {}

sealed class STightFn<A, B extends num Function(A)> {}
abstract interface class PubTightFn<X, Y extends num Function(X)>
    implements STightFn<X, Y> {}
final class _ImplTightFn<P, Q extends int Function(P)>
    extends STightFn<P, Q>
    implements PubTightFn<P, Q> {}

sealed class SMatchFn<A, B extends A Function(A, {int? opt, required A req})> {}
abstract interface class PubMatchFn<
  X,
  Y extends X Function(X, {int? opt, required X req})
> implements SMatchFn<X, Y> {}
final class _ImplMatchFn<
  P,
  Q extends P Function(P, {int? opt, required P req})
> extends SMatchFn<P, Q> implements PubMatchFn<P, Q> {}

sealed class SListFn<A, B extends List<A Function([A?])>> {}
abstract interface class PubListFn<X, Y extends List<X Function([X?])>>
    implements SListFn<X, Y> {}
final class _ImplListFn<P, Q extends List<P Function([P?])>>
    extends SListFn<P, Q>
    implements PubListFn<P, Q> {}

sealed class SRecFn<A, B extends (int, {A Function() cb})> {}
abstract interface class PubRecFn<X, Y extends (int, {X Function() cb})>
    implements SRecFn<X, Y> {}
final class _ImplRecFn<P, Q extends (int, {P Function() cb})>
    extends SRecFn<P, Q>
    implements PubRecFn<P, Q> {}

sealed class SGenFn<A, B extends Z Function<Z extends A>(Z)> {}
abstract interface class PubGenFn<X, Y extends W Function<W extends X>(W)>
    implements SGenFn<X, Y> {}
final class _ImplGenFn<P, Q extends K Function<K extends P>(K)>
    extends SGenFn<P, Q>
    implements PubGenFn<P, Q> {}
''',
      '$testPackageLibPath/file.dart': '''
export 'src/generics.dart'
    show
        AstNode,
        BoxAlias,
        CollectionElement,
        ForElement,
        ForLoop,
        ForStatement,
        IntPub,
        PubAliasBound,
        PubContra,
        PubCovFn,
        PubExtra,
        PubFBound,
        PubGenFn,
        PubListFn,
        PubMatchFn,
        PubNullBound,
        PubPair,
        PubRecBound,
        PubRecFn,
        PubSame,
        PubTight,
        PubTightFn,
        PubUnboundedFBound,
        SAliasBound,
        SContra,
        SCovFn,
        SExtra,
        SFBound,
        SGenFn,
        SListFn,
        SMatchFn,
        SNarrow,
        SNullBound,
        SPair,
        SRecBound,
        SRecFn,
        STight,
        STightFn,
        SUnboundedFBound,
        SValidExtra,
        Statement;
''',
    });

    final rehydrated = ApiSummary.fromJson(
      jsonDecode(summary) as Map<String, dynamic>,
    );
    final lib = rehydrated.libraries.singleWhere(
      (l) => l.uri == 'package:test/file.dart',
    );
    final sealedResults = {
      for (final c in lib.classes)
        if (c.modifiers.contains(ApiClassModifier.isSealed))
          c.name: {
            'immediateSubtypes': c.immediateSubtypes,
            'hasNonPublicSubtypes': c.hasNonPublicSubtypes,
          },
    };

    expect(sealedResults, {
      'SExtra': {
        'immediateSubtypes': ['PubSame'],
        'hasNonPublicSubtypes': true,
      },
      'STight': {
        'immediateSubtypes': ['PubTight'],
        'hasNonPublicSubtypes': true,
      },
      'SPair': {
        'immediateSubtypes': ['PubPair'],
        'hasNonPublicSubtypes': true,
      },
      'SNarrow': {
        'immediateSubtypes': ['IntPub'],
        'hasNonPublicSubtypes': true,
      },
      'SUnboundedFBound': {
        'immediateSubtypes': ['PubUnboundedFBound'],
        'hasNonPublicSubtypes': true,
      },
      'SCovFn': {
        'immediateSubtypes': ['PubCovFn'],
        'hasNonPublicSubtypes': true,
      },
      'STightFn': {
        'immediateSubtypes': ['PubTightFn'],
        'hasNonPublicSubtypes': true,
      },
      'SValidExtra': {
        'immediateSubtypes': ['PubExtra'],
        'hasNonPublicSubtypes': false,
      },
      'ForLoop': {
        'immediateSubtypes': ['ForElement', 'ForStatement'],
        'hasNonPublicSubtypes': false,
      },
      'SFBound': {
        'immediateSubtypes': ['PubFBound'],
        'hasNonPublicSubtypes': false,
      },
      'SRecBound': {
        'immediateSubtypes': ['PubRecBound'],
        'hasNonPublicSubtypes': false,
      },
      'SNullBound': {
        'immediateSubtypes': ['PubNullBound'],
        'hasNonPublicSubtypes': false,
      },
      'SAliasBound': {
        'immediateSubtypes': ['PubAliasBound'],
        'hasNonPublicSubtypes': false,
      },
      'SContra': {
        'immediateSubtypes': ['PubContra'],
        'hasNonPublicSubtypes': false,
      },
      'SMatchFn': {
        'immediateSubtypes': ['PubMatchFn'],
        'hasNonPublicSubtypes': false,
      },
      'SListFn': {
        'immediateSubtypes': ['PubListFn'],
        'hasNonPublicSubtypes': false,
      },
      'SRecFn': {
        'immediateSubtypes': ['PubRecFn'],
        'hasNonPublicSubtypes': false,
      },
      'SGenFn': {
        'immediateSubtypes': ['PubGenFn'],
        'hasNonPublicSubtypes': false,
      },
    });
  }

  Future<void> test_sealedSubtypes_twoPassAndDiamonds() async {
    final summary = await _build({
      '$testPackageLibPath/src/diamonds.dart': '''
// ignore_for_file: unused_element
sealed class SOrder {}
final class AlphaImpl extends SOrder implements BetaPub {}
abstract interface class BetaPub implements SOrder {}

sealed class STransOrder {}
sealed class AInternalSealed extends STransOrder {}
final class AlphaLeaf extends AInternalSealed implements ZPub {}
abstract interface class ZPub implements STransOrder {}

sealed class TileModel {}
base class CompactTile extends TileModel {}
sealed class _FopTile extends TileModel {}
final class FopCompactTile extends CompactTile implements _FopTile {}
final class FopExpandedTile extends _FopTile {}

sealed class DirectDiamond {}
base class DirectBase extends DirectDiamond {}
final class DirectSub extends DirectBase implements DirectDiamond {}

sealed class SEmptyOnly {}
sealed class _EmptyMid1 extends SEmptyOnly {}

sealed class SWithEmptyMid {}
final class PubBranch extends SWithEmptyMid {}
sealed class _EmptyMid2 extends SWithEmptyMid {}

sealed class DagRoot {}
sealed class _BranchA extends DagRoot {}
sealed class _BranchB extends DagRoot {}
sealed class _SharedMid implements _BranchA, _BranchB {}
final class DagLeaf extends _SharedMid {}
''',
      '$testPackageLibPath/file.dart': '''
export 'src/diamonds.dart'
    show
        BetaPub,
        CompactTile,
        DagLeaf,
        DagRoot,
        DirectBase,
        DirectDiamond,
        DirectSub,
        FopCompactTile,
        FopExpandedTile,
        PubBranch,
        SEmptyOnly,
        SOrder,
        STransOrder,
        SWithEmptyMid,
        TileModel,
        ZPub;
''',
    });

    final rehydrated = ApiSummary.fromJson(
      jsonDecode(summary) as Map<String, dynamic>,
    );
    final lib = rehydrated.libraries.singleWhere(
      (l) => l.uri == 'package:test/file.dart',
    );
    final sealedResults = {
      for (final c in lib.classes)
        if (c.modifiers.contains(ApiClassModifier.isSealed))
          c.name: {
            'immediateSubtypes': c.immediateSubtypes,
            'hasNonPublicSubtypes': c.hasNonPublicSubtypes,
          },
    };

    expect(sealedResults, {
      'SOrder': {
        'immediateSubtypes': ['BetaPub'],
        'hasNonPublicSubtypes': false,
      },
      'STransOrder': {
        'immediateSubtypes': ['ZPub'],
        'hasNonPublicSubtypes': false,
      },
      'TileModel': {
        'immediateSubtypes': ['CompactTile', 'FopExpandedTile'],
        'hasNonPublicSubtypes': false,
      },
      'DirectDiamond': {
        'immediateSubtypes': ['DirectBase', 'DirectSub'],
        'hasNonPublicSubtypes': false,
      },
      'SEmptyOnly': {
        'immediateSubtypes': const <String>[],
        'hasNonPublicSubtypes': false,
      },
      'SWithEmptyMid': {
        'immediateSubtypes': ['PubBranch'],
        'hasNonPublicSubtypes': false,
      },
      'DagRoot': {
        'immediateSubtypes': ['DagLeaf'],
        'hasNonPublicSubtypes': false,
      },
    });
  }

  Future<void> test_sealedSubtypes_visibilityPredicates() async {
    newPackage('foo').addFile('lib/extra.dart', '''
// ignore_for_file: unused_element
sealed class ExtComplete {}
final class ExtA extends ExtComplete {}
final class ExtB extends ExtComplete {}

sealed class ExtMixed {}
final class ExtPub extends ExtMixed {}
final class _ExtPriv extends ExtMixed {}

sealed class FilterPlatform {}
final class CompositeFilter extends FilterPlatform {}
final class FieldFilter extends FilterPlatform {}
''');

    final files = {
      '$testPackageLibPath/src/internal.dart': '''
// ignore_for_file: unused_element
sealed class SInternal {}
sealed class ClassBodyImpl extends SInternal {}
final class PubLeaf extends ClassBodyImpl {}
final class UnexportedLeaf extends SInternal {}
final class _PrivLeaf extends SInternal {}

sealed class NonPubSealed {}
final class NonPubSub extends NonPubSealed {}
''',
      '$testPackageLibPath/file.dart': '''
import 'package:foo/extra.dart';
import 'src/internal.dart';

export 'package:foo/extra.dart' show FilterPlatform;
export 'src/internal.dart' show PubLeaf, SInternal;

void useTypes(
  UnexportedLeaf unexported,
  NonPubSealed nonPubSealed,
  ExtComplete extComplete,
  ExtMixed extMixed,
) {}
''',
    };

    final implicitMembersSummary = ApiSummary.fromJson(
      jsonDecode(
            await _build(
              files,
              customizer: const ApiSummaryCustomizer(
                includeImplicitNonPublicMembers: true,
              ),
            ),
          )
          as Map<String, dynamic>,
    );
    final pubLib = implicitMembersSummary.libraries.singleWhere(
      (l) => l.uri == 'package:test/file.dart',
    );
    final sInternal = pubLib.classes.singleWhere((c) => c.name == 'SInternal');
    expect(sInternal.immediateSubtypes, ['PubLeaf']);
    expect(sInternal.hasNonPublicSubtypes, isTrue);

    final filterPlatform = pubLib.classes.singleWhere(
      (c) => c.name == 'FilterPlatform',
    );
    expect(filterPlatform.immediateSubtypes, isEmpty);
    expect(filterPlatform.hasNonPublicSubtypes, isTrue);

    final srcLib = implicitMembersSummary.libraries.singleWhere(
      (l) => l.uri == 'package:test/src/internal.dart',
    );
    final nonPubSealed = srcLib.classes.singleWhere(
      (c) => c.name == 'NonPubSealed',
    );
    expect(nonPubSealed.status, ApiDeclarationStatus.nonPublic);
    expect(nonPubSealed.immediateSubtypes, isEmpty);
    expect(nonPubSealed.hasNonPublicSubtypes, isTrue);
    expect(
      implicitMembersSummary.toString(),
      contains(
        'NonPubSealed (class extends Object, '
        'sealed (immediate subtypes: <non-public>), non-public)',
      ),
    );

    final referencedSummary = ApiSummary.fromJson(
      jsonDecode(
            await _build(
              files,
              customizer: const ApiSummaryCustomizer(
                includeReferencedTypes: true,
              ),
            ),
          )
          as Map<String, dynamic>,
    );
    final extLib = referencedSummary.libraries.singleWhere(
      (l) => l.uri == 'package:foo/extra.dart',
    );
    final extComplete = extLib.classes.singleWhere(
      (c) => c.name == 'ExtComplete',
    );
    expect(extComplete.status, ApiDeclarationStatus.referenced);
    expect(extComplete.immediateSubtypes, ['ExtA', 'ExtB']);
    expect(extComplete.hasNonPublicSubtypes, isFalse);

    final extMixed = extLib.classes.singleWhere((c) => c.name == 'ExtMixed');
    expect(extMixed.status, ApiDeclarationStatus.referenced);
    expect(extMixed.immediateSubtypes, ['ExtPub']);
    expect(extMixed.hasNonPublicSubtypes, isTrue);
  }

  Future<void> test_sealedSubtypes_brokenAstAndCycleResilience() async {
    newFile('$testPackageLibPath/broken.dart', '''
sealed class CycleA extends _CycleB {}
sealed class _CycleB extends CycleA {}

sealed class SBroken<T> {}
final class _BrokenSub<T extends UnresolvedBound> extends SBroken<T>
    implements UnresolvedSuper {}

sealed class STypeParamCycle<A extends B, B extends A> {}
final class _CycleFnSub<X, Y extends X Function()>
    extends STypeParamCycle<X, Y> {}
''');

    final context = contextCollection.contextFor(
      convertPath(testPackageLibPath),
    );
    final package = await buildApiPackage(
      'test',
      context,
      const ApiSummaryCustomizer(),
    );
    verifySummaryRoundTrip(package);

    final lib = package.libraries.singleWhere(
      (l) => l.uri == 'package:test/broken.dart',
    );
    expect(
      lib.classes.map((c) => c.name),
      containsAll(['CycleA', 'SBroken', 'STypeParamCycle']),
    );
    final cycleA = lib.classes.singleWhere((c) => c.name == 'CycleA');
    expect(cycleA.immediateSubtypes, isNot(contains('CycleA')));
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
    verifySummaryRoundTrip(package);
    return jsonEncode(package.toJson());
  }
}
