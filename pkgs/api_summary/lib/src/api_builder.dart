// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';

import 'api_declaration.dart';
import 'api_summary_customizer.dart';
import 'api_type.dart';
import 'extensions.dart';

/// Traverses the public libraries of [packageName] within [context] to build
/// a canonical [ApiSummary] representation.
///
/// Filtering and discovery behaviors are customized using [customizer].
Future<ApiSummary> buildApiPackage(
  String packageName,
  AnalysisContext context,
  ApiSummaryCustomizer customizer,
) => _ApiBuilder(packageName, customizer).build(context);

/// Internal builder traversing analysis results to build structured API
/// summaries.
final class _ApiBuilder {
  final ApiSummaryCustomizer _customizer;
  final String _pkgName;

  final _immediateSubinterfaceCache =
      <LibraryElement, Map<ClassElement, Set<InterfaceElement>>>{};

  final _processedElements = <Element>{};
  final _pendingElements = Queue<Element>();
  final _libraryBuilders = <String, _ApiLibraryBuilder>{};
  final _elementToLibraries = <Element, List<LibraryElement>>{};

  _ApiBuilder(this._pkgName, this._customizer);

  Future<ApiSummary> build(AnalysisContext context) async {
    final publicApiLibraries = <LibraryElement>[];
    final topLevelPublicElements = <Element>{};
    final scanContext = ApiSummaryContext(
      packageName: _pkgName,
      analysisContext: context,
      publicApiLibraries: publicApiLibraries,
      topLevelPublicElements: topLevelPublicElements,
    );
    await _customizer.setupComplete(scanContext);

    for (final file in context.contextRoot.analyzedFiles().sorted()) {
      if (!file.endsWith('.dart')) continue;
      final fileResult = context.currentSession.getFile(file);
      if (fileResult is! FileResult) continue;
      final uri = fileResult.uri;
      if (fileResult.isLibrary && uri.isInPublicLibOf(_pkgName)) {
        final resolvedLibraryResult = await context.currentSession
            .getResolvedLibrary(file);
        if (resolvedLibraryResult is! ResolvedLibraryResult) continue;
        final library = resolvedLibraryResult.element;
        final definedNames = library.exportNamespace.definedNames2;
        for (final key in definedNames.keys.sorted()) {
          final element = definedNames[key]!;
          topLevelPublicElements.add(element);
          (_elementToLibraries[element] ??= []).add(library);
          _registerElement(element);
        }
        publicApiLibraries.add(library);
        _libraryBuilders.putIfAbsent(
          library.uri.toString(),
          () => _ApiLibraryBuilder(
            library.uri.toString(),
            isPublicEntryPoint: true,
          ),
        );
      }
    }
    await _customizer.initialScanComplete(scanContext);

    while (_pendingElements.isNotEmpty) {
      final element = _pendingElements.removeFirst();
      if (!_processedElements.add(element)) continue;

      if (!_customizer.shouldShowDetails(element, scanContext)) continue;

      final libraries =
          _elementToLibraries[element] ??
          [if (element.library != null) element.library!];

      final apiElement = switch (element) {
        EnumElement() => _buildClass(element),
        MixinElement() => _buildClass(element),
        ClassElement() => _buildClass(element),
        ExtensionElement() => _buildExtension(element),
        ExtensionTypeElement() => _buildExtensionType(element),
        TopLevelFunctionElement() => _buildExecutable(element),
        PropertyAccessorElement() => _buildExecutable(element),
        TypeAliasElement() => _buildTypeAlias(element),
        _ => null,
      };

      if (apiElement == null) {
        stderr.writeln(
          'Warning: Skipping unsupported top-level element "${element.name}" '
          '(${element.runtimeType})',
        );
        continue;
      }

      for (final library in libraries) {
        final builder = _libraryBuilders.putIfAbsent(
          library.uri.toString(),
          () => _ApiLibraryBuilder(
            library.uri.toString(),
            isPublicEntryPoint: library.uri.isInPublicLibOf(_pkgName),
          ),
        );
        switch (apiElement) {
          case ApiClass():
            switch (element) {
              case EnumElement():
                builder.enums.add(apiElement);
              case MixinElement():
                builder.mixins.add(apiElement);
              default:
                builder.classes.add(apiElement);
            }
          case ApiExtension():
            builder.extensions.add(apiElement);
          case ApiExtensionType():
            builder.extensionTypes.add(apiElement);
          case ApiExecutable():
            builder.functions.add(apiElement);
          case ApiTypeAlias():
            builder.typeAliases.add(apiElement);
        }
      }
    }

    final libraries = _libraryBuilders.values.map((e) => e.build()).toList();

    return ApiSummary(name: _pkgName, libraries: libraries);
  }

  void _registerElement(Element element) {
    if (_processedElements.contains(element)) return;
    _pendingElements.add(element);
  }

  bool _isNullable(NullabilitySuffix suffix) => switch (suffix) {
    NullabilitySuffix.none => false,
    NullabilitySuffix.question => true,
    NullabilitySuffix.star => throw UnsupportedError(
      'Legacy nullability (.star) is not supported.',
    ),
  };

  bool _isVisibleForTesting(Element element) =>
      element.nonSynthetic.metadata.hasVisibleForTesting;

  ApiType _describeType(DartType type) {
    final isNullable = _isNullable(type.nullabilitySuffix);
    switch (type) {
      case DynamicType():
        return const ApiDynamicType();
      case FunctionType(
        :final returnType,
        :final typeParameters,
        :final formalParameters,
      ):
        final apiParameters = <ApiParameter>[];
        for (final p in formalParameters) {
          apiParameters.add(
            ApiParameter(
              name: p.name ?? '',
              type: _describeType(p.type),
              isRequired: p.isRequired,
              isNamed: p.isNamed,
              isOptionalPositional: p.isOptionalPositional,
              isDeprecated: p.isDeprecated,
            ),
          );
        }

        return ApiFunctionType(
          returnType: _describeType(returnType),
          typeParameters: _extractTypeParameters(typeParameters),
          parameters: apiParameters,
          isNullable: isNullable,
        );
      case InterfaceType(:final element, :final typeArguments):
        _registerElement(element);
        return ApiInterfaceType(
          name: element.name ?? '',
          libraryUri: element.library.uri.toString(),
          typeArguments: typeArguments.map(_describeType).toList(),
          isNullable: isNullable,
        );
      case RecordType(:final positionalFields, :final namedFields):
        return ApiRecordType(
          positionalFields: positionalFields
              .map((f) => _describeType(f.type))
              .toList(),
          namedFields: namedFields
              .sortedBy((f) => f.name)
              .map(
                (f) => ApiRecordNamedField(
                  name: f.name,
                  type: _describeType(f.type),
                ),
              )
              .toList(),
          isNullable: isNullable,
        );
      case TypeParameterType(:final element):
        return ApiTypeParameterType(
          name: element.name ?? '',
          isNullable: isNullable,
        );
      case NeverType():
        return ApiInterfaceType(
          name: 'Never',
          libraryUri: 'dart:core',
          typeArguments: const [],
          isNullable: isNullable,
        );
      case VoidType():
        return const ApiVoidType();
      // When analyzing a workspace with mid-edit syntax errors or unresolved
      // identifiers (e.g., unimported annotations), the analyzer produces an
      // InvalidType. We gracefully fall back to dynamic to avoid crashing.
      case InvalidType():
        return const ApiDynamicType();
      case dynamic(:final runtimeType):
        stderr.writeln(
          'Warning: Encountered unexpected DartType "$runtimeType", '
          'falling back to dynamic',
        );
        return const ApiDynamicType();
    }
  }

  Map<String, ApiType?> _extractTypeParameters(
    List<TypeParameterElement> elements,
  ) {
    final result = <String, ApiType?>{};
    for (final e in elements) {
      if (e.name != null) {
        result[e.name!] = e.bound != null ? _describeType(e.bound!) : null;
      }
    }
    return result;
  }

  Map<ClassElement, Set<InterfaceElement>>
  _getOrComputeImmediateSubinterfaceMap(LibraryElement library) {
    if (_immediateSubinterfaceCache[library] case final m?) return m;
    final result = <ClassElement, Set<InterfaceElement>>{};
    for (final interface in [
      ...library.classes,
      ...library.mixins,
      ...library.enums,
      ...library.extensionTypes,
    ]..sortBy((e) => e.name ?? '')) {
      for (final superinterface in [
        interface.supertype,
        ...interface.interfaces,
        ...interface.mixins,
        if (interface is MixinElement) ...interface.superclassConstraints,
      ]) {
        if (superinterface == null) continue;
        final superinterfaceElement = superinterface.element;
        if (superinterfaceElement is ClassElement &&
            superinterfaceElement.isSealed) {
          (result[superinterfaceElement] ??= {}).add(interface);
        }
      }
    }
    _immediateSubinterfaceCache[library] = result;
    return result;
  }

  ApiClass _buildClass(InterfaceElement element) {
    final constructors = <ApiExecutable>[];
    final methods = <ApiExecutable>[];

    for (final member in element.children.sortedBy((m) => m.name ?? '')) {
      if (member.name?.startsWith('_') ?? false) continue;

      switch (member) {
        case ConstructorElement():
          if (element is ClassElement &&
              element.isAbstract &&
              (element.isFinal || element.isInterface || element.isSealed) &&
              !member.isFactory) {
            continue;
          }
          if (element is EnumElement && !member.isFactory) continue;
          constructors.add(_buildExecutable(member));
        case ExecutableElement():
          methods.add(_buildExecutable(member));
      }
    }

    final modifiers = <ApiClassModifier>[];
    var immediateSubtypes = <String>[];

    if (element is ClassElement) {
      if (element.isSealed) {
        modifiers.add(ApiClassModifier.isSealed);
        final subinterfaces = _getOrComputeImmediateSubinterfaceMap(
          element.library,
        )[element];
        if (subinterfaces != null) {
          immediateSubtypes = subinterfaces.map((e) => e.name ?? '').toList();
          immediateSubtypes.sort();
        }
      } else {
        if (element.isAbstract) modifiers.add(ApiClassModifier.isAbstract);
        if (element.isBase) modifiers.add(ApiClassModifier.isBase);
        if (element.isMixinClass) modifiers.add(ApiClassModifier.isMixin);
        if (element.isInterface) modifiers.add(ApiClassModifier.isInterface);
        if (element.isFinal) modifiers.add(ApiClassModifier.isFinal);
      }
    } else if (element is MixinElement) {
      if (element.isBase) modifiers.add(ApiClassModifier.isBase);
    }
    return ApiClass(
      name: element.name ?? '',
      locationUri: element.library.uri.toString(),
      typeParameters: _extractTypeParameters(element.typeParameters),
      supertype: element is ClassElement
          ? (element.supertype != null
                ? _describeType(element.supertype!)
                : null)
          : null,
      interfaces: element.interfaces.map(_describeType).toList(),
      mixins: element.mixins.map(_describeType).toList(),
      superclassConstraints: element is MixinElement
          ? element.superclassConstraints.map(_describeType).toList()
          : const [],
      modifiers: modifiers,
      immediateSubtypes: immediateSubtypes,
      constructors: constructors,
      methods: methods,
      isExperimental: element.nonSynthetic.metadata.hasExperimental,
      isDeprecated: element.nonSynthetic.metadata.hasDeprecated,
      isVisibleForTesting: _isVisibleForTesting(element),
    );
  }

  ApiExtension _buildExtension(ExtensionElement element) {
    final methods = <ApiExecutable>[];
    for (final member in element.children.sortedBy((m) => m.name ?? '')) {
      if (member.name?.startsWith('_') ?? false) continue;
      if (member is FieldElement) continue;
      if (member is ExecutableElement) methods.add(_buildExecutable(member));
    }
    return ApiExtension(
      name: element.name ?? '',
      locationUri: element.library.uri.toString(),
      extendedType: _describeType(element.extendedType),
      typeParameters: _extractTypeParameters(element.typeParameters),
      methods: methods,
      isExperimental: element.nonSynthetic.metadata.hasExperimental,
      isDeprecated: element.nonSynthetic.metadata.hasDeprecated,
      isVisibleForTesting: _isVisibleForTesting(element),
    );
  }

  ApiExtensionType _buildExtensionType(ExtensionTypeElement element) {
    final constructors = <ApiExecutable>[];
    final methods = <ApiExecutable>[];
    for (final member in element.children.sortedBy((m) => m.name ?? '')) {
      if (member.name?.startsWith('_') ?? false) continue;
      if (member is FieldElement) continue;
      if (member is ConstructorElement) {
        constructors.add(_buildExecutable(member));
      } else if (member is ExecutableElement) {
        methods.add(_buildExecutable(member));
      }
    }
    return ApiExtensionType(
      name: element.name ?? '',
      locationUri: element.library.uri.toString(),
      representationType: _describeType(element.representation.type),
      typeParameters: _extractTypeParameters(element.typeParameters),
      interfaces: element.interfaces.map(_describeType).toList(),
      constructors: constructors,
      methods: methods,
      isExperimental: element.nonSynthetic.metadata.hasExperimental,
      isDeprecated: element.nonSynthetic.metadata.hasDeprecated,
      isVisibleForTesting: _isVisibleForTesting(element),
    );
  }

  ApiExecutable _buildExecutable(ExecutableElement element) {
    final nonSyntheticElement = element.nonSynthetic;
    final formalParameters = element.type.formalParameters;

    final kind = switch (element) {
      GetterElement() => ApiExecutableKind.getter,
      SetterElement() => ApiExecutableKind.setter,
      MethodElement() => ApiExecutableKind.method,
      ConstructorElement() => ApiExecutableKind.constructor,
      _ => ApiExecutableKind.function,
    };

    return ApiExecutable(
      name: element.apiName,
      locationUri: element.library.uri.toString(),
      kind: kind,
      returnType: _describeType(element.returnType),
      typeParameters: _extractTypeParameters(element.typeParameters),
      parameters: formalParameters
          .map(
            (e) => ApiParameter(
              name: e.name ?? '',
              type: _describeType(e.type),
              isRequired: e.isRequired,
              isNamed: e.isNamed,
              isOptionalPositional: e.isOptionalPositional,
              isDeprecated: e.isDeprecated,
            ),
          )
          .toList(),
      isStatic: element.isStatic,
      isDeprecated: nonSyntheticElement.metadata.hasDeprecated,
      isExperimental: nonSyntheticElement.metadata.hasExperimental,
      isVisibleForTesting: _isVisibleForTesting(element),
    );
  }

  ApiTypeAlias _buildTypeAlias(TypeAliasElement element) => ApiTypeAlias(
    name: element.name ?? '',
    locationUri: element.library.uri.toString(),
    typeParameters: _extractTypeParameters(element.typeParameters),
    aliasedType: _describeType(element.aliasedType),
    isDeprecated: element.nonSynthetic.metadata.hasDeprecated,
    isExperimental: element.nonSynthetic.metadata.hasExperimental,
    isVisibleForTesting: _isVisibleForTesting(element),
  );
}

/// Mutable builder accumulating declarations for a single library.
final class _ApiLibraryBuilder {
  final String uri;
  final bool isPublicEntryPoint;
  final classes = <ApiClass>[];
  final enums = <ApiClass>[];
  final mixins = <ApiClass>[];
  final extensions = <ApiExtension>[];
  final extensionTypes = <ApiExtensionType>[];
  final functions = <ApiExecutable>[];
  final typeAliases = <ApiTypeAlias>[];

  _ApiLibraryBuilder(this.uri, {required this.isPublicEntryPoint});

  ApiLibrary build() {
    classes.sortBy((e) => e.name);
    enums.sortBy((e) => e.name);
    mixins.sortBy((e) => e.name);
    extensions.sortBy((e) => e.name);
    extensionTypes.sortBy((e) => e.name);
    functions.sortBy((e) => e.name);
    typeAliases.sortBy((e) => e.name);
    return ApiLibrary(
      uri: uri,
      isPublicEntryPoint: isPublicEntryPoint,
      classes: classes,
      enums: enums,
      mixins: mixins,
      extensions: extensions,
      extensionTypes: extensionTypes,
      functions: functions,
      typeAliases: typeAliases,
    );
  }
}
