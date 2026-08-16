// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'dart:core';

import 'package:analyzer/dart/element/element.dart';
import 'package:api_summary/api_summary.dart';
import 'package:api_summary/src/api_builder.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'test_utils.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MetaAnnotationsTest);
  });
}

@reflectiveTest
class MetaAnnotationsTest extends ApiSummaryTest {
  @override
  bool get addMetaPackageDep => true;

  Future<String> _build(
    Map<String, String> files, {
    ApiSummaryCustomizer? customizer,
  }) async {
    files.forEach(newFile);
    for (final file in files.keys) {
      if (file.endsWith('.dart')) await assertNoDiagnosticsInFile(file);
    }
    final context = contextCollection.contextFor(
      convertPath(testPackageLibPath),
    );
    final package = await buildApiPackage(
      'test',
      context,
      customizer ?? const ApiSummaryCustomizer(),
    );
    return package.toString();
  }

  Future<ApiSummary> _buildModel(Map<String, String> files) async {
    files.forEach(newFile);
    for (final file in files.keys) {
      if (file.endsWith('.dart')) await assertNoDiagnosticsInFile(file);
    }
    final context = contextCollection.contextFor(
      convertPath(testPackageLibPath),
    );
    return buildApiPackage('test', context, const ApiSummaryCustomizer());
  }

  Future<void> test_class_immutable() async {
    final summary = await _build({
      '$testPackageLibPath/file.dart': '''
import 'package:meta/meta.dart';

@immutable
class ImmutableClass {
  final int x;
  const ImmutableClass(this.x);
}
''',
    });

    expect(summary, '''
package:test/file.dart:
  ImmutableClass (class extends Object, immutable):
    new (const constructor: ImmutableClass Function(int))
    x (getter: int)
dart:core:
  Object (referenced)
  int (referenced)
''');
  }

  Future<void> test_internal_annotations() async {
    final summary = await _build({
      '$testPackageLibPath/file.dart': '''
import 'src/internal.dart';

InternalClass getInternal() => InternalClass();
''',
      '$testPackageLibPath/src/internal.dart': '''
import 'package:meta/meta.dart';

@internal
class InternalClass {
  @internal
  void internalMethod() {}
}
''',
    }, customizer: _ShowInternalDetailsCustomizer());

    expect(summary, '''
package:test/file.dart:
  getInternal (function: InternalClass Function())
package:test/src/internal.dart:
  InternalClass (class extends Object, non-public, internal):
    new (constructor: InternalClass Function(), internal)
    internalMethod (method: void Function(), internal)
dart:core:
  Object (referenced)
''');
  }

  Future<void> test_member_contractual_annotations() async {
    final summary = await _build({
      '$testPackageLibPath/file.dart': '''
import 'package:meta/meta.dart';

class Base {
  @protected
  void protectedMethod() {}

  @mustCallSuper
  void mustCallSuperMethod() {}

  @visibleForOverriding
  void visibleForOverridingMethod() {}

  @nonVirtual
  void nonVirtualMethod() {}

  @mustBeOverridden
  void mustBeOverriddenMethod() {}

  @useResult
  int useResultMethod() => 42;

  @protected
  int protectedField = 0;
}

@useResult
int topLevelUseResultFunction() => 1;
''',
    });

    expect(summary, '''
package:test/file.dart:
  topLevelUseResultFunction (function: int Function(), use result)
  Base (class extends Object):
    new (constructor: Base Function())
    protectedField (getter: int, protected)
    protectedField= (setter: int, protected)
    mustBeOverriddenMethod (method: void Function(), must be overridden)
    mustCallSuperMethod (method: void Function(), must call super)
    nonVirtualMethod (method: void Function(), non-virtual)
    protectedMethod (method: void Function(), protected)
    useResultMethod (method: int Function(), use result)
    visibleForOverridingMethod (method: void Function(), visible for overriding)
dart:core:
  Object (referenced)
  int (referenced)
''');
  }

  Future<void> test_json_roundtrip_with_meta_annotations() async {
    final model = await _buildModel({
      '$testPackageLibPath/file.dart': '''
import 'package:meta/meta.dart';

@immutable
class Target {
  @protected
  @mustCallSuper
  @nonVirtual
  @useResult
  int calculate() => 0;
}
''',
    });

    final jsonMap = model.toJson();
    final rehydrated = ApiSummary.fromJson(jsonMap);

    final cls = rehydrated.libraries.single.classes.single;
    expect(cls.name, 'Target');
    expect(cls.isImmutable, isTrue);
    expect(cls.isInternal, isFalse);

    final method = cls.methods.singleWhere((m) => m.name == 'calculate');
    expect(method.isProtected, isTrue);
    expect(method.isMustCallSuper, isTrue);
    expect(method.isNonVirtual, isTrue);
    expect(method.isUseResult, isTrue);
    expect(method.isMustBeOverridden, isFalse);
    expect(method.isVisibleForOverriding, isFalse);

    // Verify traits in JSON output
    final libJson = (jsonMap['libraries'] as List)
        .cast<Map<String, dynamic>>()[0];
    final classJson = (libJson['classes'] as List)
        .cast<Map<String, dynamic>>()[0];
    final methodJson = (classJson['methods'] as List)
        .cast<Map<String, dynamic>>()[0];

    expect(
      classJson,
      containsPair('traits', [
        {
          'namespace': 'meta',
          'contracts': ['immutable'],
        },
      ]),
    );
    expect(
      methodJson,
      containsPair('traits', [
        {
          'namespace': 'meta',
          'contracts': [
            'mustCallSuper',
            'nonVirtual',
            'protected',
            'useResult',
          ],
        },
      ]),
    );
  }

  void test_traits_deduplication_sorting_and_immutability() {
    // 1. Verify MetaContractTrait deduplicates contracts and sorts them
    // deterministically.
    final metaTrait1 = MetaContractTrait([
      MetaContract.useResult,
      MetaContract.protected,
      MetaContract.useResult,
      MetaContract.immutable,
      MetaContract.protected,
      MetaContract.useResult,
    ]);

    expect(
      metaTrait1.contracts.toList(),
      equals([
        MetaContract.immutable,
        MetaContract.protected,
        MetaContract.useResult,
      ]),
    );

    // Verify immutability of contracts set
    expect(
      () => (metaTrait1.contracts as dynamic).add(MetaContract.internal),
      throwsUnsupportedError,
    );

    // Verify equality with differently ordered construction
    final metaTrait2 = MetaContractTrait([
      MetaContract.protected,
      MetaContract.immutable,
      MetaContract.useResult,
    ]);
    expect(metaTrait1, equals(metaTrait2));
    expect(metaTrait1.hashCode, equals(metaTrait2.hashCode));

    // Verify fromJson gracefully ignores unknown contracts
    final fromJsonTrait = MetaContractTrait.fromJson({
      'namespace': 'meta',
      'contracts': ['protected', 'unknownFutureContract', 'useResult'],
    });
    expect(
      fromJsonTrait.contracts.toList(),
      equals([MetaContract.protected, MetaContract.useResult]),
    );

    // 2. Verify ApiDeclaration deduplicates traits and sorts them
    // deterministically.
    final dummyExecutable = ApiExecutable(
      name: 'foo',
      kind: ApiExecutableKind.function,
      typeParameters: const {},
      returnType: const ApiVoidType(),
      parameters: const [],
      isStatic: true,
      traits: [metaTrait1, metaTrait2, metaTrait1],
    );

    expect(dummyExecutable.traits.length, equals(1));
    expect(dummyExecutable.traits.single, equals(metaTrait1));
    expect(
      () => (dummyExecutable.traits as dynamic).add(metaTrait1),
      throwsUnsupportedError,
    );
  }
}

final class _ShowInternalDetailsCustomizer extends ApiSummaryCustomizer {
  @override
  bool shouldShowDetails(Element element, ApiSummaryContext context) =>
      element.name?.contains('Internal') ?? false;
}
