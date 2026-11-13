// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
// TODO(paulberry): move pub_package_resolution.dart out of src
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart';
import 'package:api_summary/api_summary.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

class ApiSummaryTest extends PubPackageResolutionTest {
  Future<LibraryElement> analyzeLibrary(
    String content, {
    String pathWithinLib = 'test.dart',
  }) async {
    final file = newFile('$testPackageLibPath/$pathWithinLib', content);
    final resolvedUnitResult = await resolveFile(file.path);
    expect(
      resolvedUnitResult.diagnostics.where(
        (diagnostic) => diagnostic.severity == Severity.error,
      ),
      isEmpty,
    );
    return resolvedUnitResult.libraryElement;
  }
}

/// Verifies that [package] round-trips losslessly through both JSON and YAML,
/// renders identical `api.txt` output after rehydration, and includes every
/// in-package referenced interface type in [ApiSummary.libraries].
void verifySummaryRoundTrip(ApiSummary package) {
  final expectedText = ApiSummaryFormat.text.format(package);
  expect(package.toString(), equals(expectedText));

  final jsonText = ApiSummaryFormat.json.format(package);
  final fromJson = ApiSummary.fromJson(
    jsonDecode(jsonText) as Map<String, dynamic>,
  );
  expect(ApiSummaryFormat.json.format(fromJson), equals(jsonText));
  expect(fromJson.toString(), equals(expectedText));

  final yamlText = ApiSummaryFormat.yaml.format(package);
  final fromYaml = ApiSummary.fromJson(
    jsonDecode(jsonEncode(loadYaml(yamlText))) as Map<String, dynamic>,
  );
  expect(ApiSummaryFormat.yaml.format(fromYaml), equals(yamlText));
  expect(fromYaml.toJson(), equals(package.toJson()));
  expect(fromYaml.toString(), equals(expectedText));

  _expectAllInPackageTypesInLibraries(package);
  _expectAllInPackageTypesInLibraries(fromJson);
  _expectAllInPackageTypesInLibraries(fromYaml);
}

void _expectAllInPackageTypesInLibraries(ApiSummary package) {
  final declaredKeys = <String>{
    for (final decl in package.libraries.expand(_allDeclarations))
      '${decl.locationUri}#${decl.name}',
  };
  final inPackagePrefix = 'package:${package.name}/';
  final referencedTypes = package.libraries
      .expand(_allDeclarations)
      .expand(_renderedSignatureTypes)
      .expand(_nestedInterfaceTypes);
  for (final type in referencedTypes) {
    final libraryUri = type.libraryUri;
    if (libraryUri != null && libraryUri.startsWith(inPackagePrefix)) {
      expect(declaredKeys, contains('$libraryUri#${type.name}'));
    }
  }
}

Iterable<ApiDeclaration> _allDeclarations(ApiLibrary library) sync* {
  yield* library.classes;
  yield* library.enums;
  yield* library.mixins;
  yield* library.extensions;
  yield* library.extensionTypes;
  yield* library.functions;
  yield* library.typeAliases;
}

Iterable<ApiType> _renderedSignatureTypes(ApiDeclaration declaration) sync* {
  switch (declaration) {
    case ApiClass():
      yield* declaration.typeParameters.values.nonNulls;
      if (declaration.supertype case final supertype?) yield supertype;
      yield* declaration.interfaces;
      yield* declaration.mixins;
      yield* declaration.superclassConstraints;
      for (final constructor in declaration.constructors) {
        yield* _renderedSignatureTypes(constructor);
      }
      for (final method in declaration.methods) {
        yield* _renderedSignatureTypes(method);
      }
    case ApiExtension():
      yield* declaration.typeParameters.values.nonNulls;
      yield declaration.extendedType;
      for (final method in declaration.methods) {
        yield* _renderedSignatureTypes(method);
      }
    case ApiExtensionType():
      yield* declaration.typeParameters.values.nonNulls;
      yield* declaration.interfaces;
      for (final constructor in declaration.constructors) {
        yield* _renderedSignatureTypes(constructor);
      }
      for (final method in declaration.methods) {
        yield* _renderedSignatureTypes(method);
      }
    case ApiExecutable():
      yield* declaration.typeParameters.values.nonNulls;
      yield declaration.returnType;
      for (final parameter in declaration.parameters) {
        yield parameter.type;
      }
    case ApiTypeAlias():
      yield* declaration.typeParameters.values.nonNulls;
      yield declaration.aliasedType;
  }
}

Iterable<ApiInterfaceType> _nestedInterfaceTypes(ApiType type) sync* {
  switch (type) {
    case ApiDynamicType() || ApiVoidType() || ApiTypeParameterType():
      return;
    case ApiInterfaceType():
      yield type;
      for (final arg in type.typeArguments) {
        yield* _nestedInterfaceTypes(arg);
      }
    case ApiRecordType():
      for (final field in type.positionalFields) {
        yield* _nestedInterfaceTypes(field);
      }
      for (final field in type.namedFields) {
        yield* _nestedInterfaceTypes(field.type);
      }
    case ApiFunctionType():
      yield* _nestedInterfaceTypes(type.returnType);
      for (final bound in type.typeParameters.values.nonNulls) {
        yield* _nestedInterfaceTypes(bound);
      }
      for (final parameter in type.parameters) {
        yield* _nestedInterfaceTypes(parameter.type);
      }
  }
}
