// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';

import 'api_summary_customizer.dart';
import 'extensions.dart';
import 'member_sorting.dart';
import 'node.dart';
import 'unique_namer.dart';
import 'uri_sorting.dart';

/// Data structure keeping track of a package's API while walking it to produce
/// `api.txt`.
class ApiDescription {
  final ApiSummaryCustomizer _customizer;

  final String _pkgName;

  /// Top level elements that have already had their child elements dumped.
  ///
  /// If an element is seen again in a different library, it will be followed
  /// with `(see above)` (rather than having its child elements dumped twice).
  final _dumpedTopLevelElements = <Element>{};

  /// Top level elements that have been referenced so far and haven't yet been
  /// processed by [build].
  ///
  /// This is used to ensure that all elements referred to by the public API
  /// (e.g., by being mentioned in the type of an API element) also show up in
  /// the output.
  final _potentiallyDanglingReferences = Queue<Element>();

  final _uniqueNamer = UniqueNamer();

  /// Cache of values returned by [_getOrComputeImmediateSubinterfaceMap], to
  /// avoid unnecessary recomputation.
  final _immediateSubinterfaceCache =
      <LibraryElement, Map<ClassElement, Set<InterfaceElement>>>{};

  ApiDescription(this._pkgName, this._customizer);

  /// Builds a list of [Node] objects representing all the libraries that are
  /// relevant to the package's public API.
  ///
  /// This includes libraries that are in the package's public API as well as
  /// libraries that are referenced by the package's public API (either by being
  /// re-exported as part of the package's public API, or by being used as part
  /// of the type of something in the public API).
  ///
  /// Each library node is pared with a [UriSortKey] indicating the order in
  /// which the nodes should be output.
  Future<List<(UriSortKey, Node)>> build(AnalysisContext context) async {
    _customizer.packageName = _pkgName;
    _customizer.analysisContext = context;
    await _customizer.setupComplete();

    // First, find all the libraries comprising the package's public API, and
    // all the top level elements they export.
    final publicApiLibraries = <LibraryElement>[];
    final topLevelPublicElements = <Element>{};
    for (final file in context.contextRoot.analyzedFiles().sorted()) {
      if (!file.endsWith('.dart')) continue;
      final fileResult = context.currentSession.getFile(file) as FileResult;
      final uri = fileResult.uri;
      if (fileResult.isLibrary && uri.isInPublicLibOf(_pkgName)) {
        final resolvedLibraryResult =
            (await context.currentSession.getResolvedLibrary(file))
                as ResolvedLibraryResult;
        final library = resolvedLibraryResult.element;
        topLevelPublicElements.addAll(
          library.exportNamespace.definedNames2.values,
        );
        publicApiLibraries.add(library);
      }
    }
    _customizer.publicApiLibraries = publicApiLibraries;
    _customizer.topLevelPublicElements = topLevelPublicElements;
    await _customizer.initialScanComplete();

    // Then, dump all the libraries in the package's public API.
    final nodes = <Uri, Node<MemberSortKey>>{};
    for (final library in publicApiLibraries) {
      final node = nodes[library.uri] = Node<MemberSortKey>();
      _dumpLibrary(library, node);
    }

    // Finally, dump anything referenced by those public libraries.
    while (_potentiallyDanglingReferences.isNotEmpty) {
      final element = _potentiallyDanglingReferences.removeFirst();
      if (!_dumpedTopLevelElements.add(element)) continue;
      final containingLibraryUri = element.library!.uri;
      final childNode = Node<MemberSortKey>()
        ..text.add(_uniqueNamer.name(element));
      _dumpElement(element, childNode);
      (nodes[containingLibraryUri] ??= Node<MemberSortKey>()
            ..text.add('$containingLibraryUri:'))
          .childNodes
          .add((MemberSortKey(element), childNode));
    }
    return [
      for (final entry in nodes.entries)
        (UriSortKey(entry.key, _pkgName), entry.value),
    ];
  }

  /// Creates a list of objects which, when their string representations are
  /// concatenated, describes [type].
  ///
  /// The reason we use this method rather than [DartType.toString] is to make
  /// sure that (a) every element mentioned by the type is added to
  /// [_potentiallyDanglingReferences], and (b) if an ambiguous name is used,
  /// the ambiguity will be taken care of by [_uniqueNamer].
  List<Object?> _describeType(DartType type) {
    final suffix = switch (type.nullabilitySuffix) {
      NullabilitySuffix.none => '',
      NullabilitySuffix.star => '*',
      NullabilitySuffix.question => '?',
    };
    switch (type) {
      case DynamicType():
        return ['dynamic'];
      case FunctionType(
        :final returnType,
        :final typeParameters,
        :final formalParameters,
      ):
        final params = <List<Object?>>[];
        final optionalParams = <List<Object?>>[];
        final namedParams = <String, List<Object?>>{};
        for (final formalParameter in formalParameters) {
          if (formalParameter.isNamed) {
            namedParams[formalParameter.name!] = [
              if (formalParameter.isDeprecated) 'deprecated ',
              if (formalParameter.isRequired) 'required ',
              ..._describeType(formalParameter.type),
            ];
          } else if (formalParameter.isOptional) {
            optionalParams.add([
              if (formalParameter.isDeprecated) 'deprecated ',
              ..._describeType(formalParameter.type),
            ]);
          } else {
            params.add([
              if (formalParameter.isDeprecated) 'deprecated ',
              ..._describeType(formalParameter.type),
            ]);
          }
        }
        if (optionalParams.isNotEmpty) {
          params.add(optionalParams.separatedBy(prefix: '[', suffix: ']'));
        }
        if (namedParams.isNotEmpty) {
          params.add(
            namedParams.entries
                .sortedBy((e) => e.key)
                .map((e) => [...e.value, ' ${e.key}'])
                .separatedBy(prefix: '{', suffix: '}'),
          );
        }
        return <Object?>[
          ..._describeType(returnType),
          ' Function',
          if (typeParameters.isNotEmpty)
            ...typeParameters
                .map(_describeTypeParameter)
                .separatedBy(prefix: '<', suffix: '>'),
          '(',
          ...params.separatedBy(),
          ')',
          suffix,
        ];
      case InterfaceType(:final element, :final typeArguments):
        _potentiallyDanglingReferences.addLast(element);
        return [
          _uniqueNamer.name(element),
          if (typeArguments.isNotEmpty)
            ...typeArguments
                .map(_describeType)
                .separatedBy(prefix: '<', suffix: '>'),
          suffix,
        ];
      case RecordType(:final positionalFields, :final namedFields):
        if (positionalFields.length == 1 && namedFields.isEmpty) {
          return [
            '(',
            ..._describeType(positionalFields[0].type),
            ',)',
            suffix,
          ];
        }
        return [
          ...[
            for (final positionalField in positionalFields)
              _describeType(positionalField.type),
            if (namedFields.isNotEmpty)
              namedFields
                  .sortedBy((f) => f.name)
                  .map((f) => [..._describeType(f.type), ' ', f.name])
                  .separatedBy(prefix: '{', suffix: '}'),
          ].separatedBy(prefix: '(', suffix: ')'),
          suffix,
        ];
      case TypeParameterType(:final element):
        return [element.name!, suffix];
      case VoidType():
        return ['void'];
      case dynamic(:final runtimeType):
        throw UnimplementedError('Unexpected type: $runtimeType');
    }
  }

  /// Creates a list of objects which, when their string representations are
  /// concatenated, describes [typeParameter].
  List<Object?> _describeTypeParameter(TypeParameterElement typeParameter) => [
    typeParameter.name!,
    if (typeParameter.bound case final bound?) ...[
      ' extends ',
      ..._describeType(bound),
    ],
  ];

  /// Appends information to [node] describing [element].
  void _dumpElement(Element element, Node<MemberSortKey> node) {
    final enclosingElement = element.enclosingElement;
    if (enclosingElement is LibraryElement &&
        !_customizer.shouldShowDetails(element)) {
      if (!enclosingElement.uri.isIn(_pkgName)) {
        node.text.add(' (referenced)');
      } else {
        node.text.add(' (non-public)');
      }
      return;
    }
    final parentheticals = <List<Object?>>[];
    switch (element) {
      case TypeAliasElement(:final aliasedType, :final typeParameters):
        final description = <Object?>['type alias'];
        if (typeParameters.isNotEmpty) {
          description.addAll(
            typeParameters
                .map(_describeTypeParameter)
                .separatedBy(prefix: '<', suffix: '>'),
          );
        }
        description.addAll([' for ', ..._describeType(aliasedType)]);
        parentheticals.add(description);
      case InstanceElement():
        switch (element) {
          case InterfaceElement(
            :final typeParameters,
            :final supertype,
            :final interfaces,
          ):
            final instanceDescription = <Object?>[
              switch (element) {
                ClassElement() => 'class',
                EnumElement() => 'enum',
                MixinElement() => 'mixin',
                ExtensionTypeElement() => 'extension type',
                dynamic(:final runtimeType) => 'TODO: $runtimeType',
              },
            ];
            if (typeParameters.isNotEmpty) {
              instanceDescription.addAll(
                typeParameters
                    .map(_describeTypeParameter)
                    .separatedBy(prefix: '<', suffix: '>'),
              );
            }
            if (element is! EnumElement && supertype != null) {
              instanceDescription.addAll([
                ' extends ',
                ..._describeType(supertype),
              ]);
            }
            if (element is MixinElement &&
                element.superclassConstraints.isNotEmpty) {
              instanceDescription.addAll(
                element.superclassConstraints
                    .map(_describeType)
                    .separatedBy(prefix: ' on '),
              );
            }
            if (interfaces.isNotEmpty) {
              instanceDescription.addAll(
                interfaces
                    .map(_describeType)
                    .separatedBy(prefix: ' implements '),
              );
            }
            parentheticals.add(instanceDescription);
            if (element is ClassElement) {
              if (element.isSealed) {
                final parenthetical = <Object>['sealed'];
                parentheticals.add(parenthetical);
                if (_getOrComputeImmediateSubinterfaceMap(
                      element.library,
                    )[element]
                    case final subinterfaces?) {
                  parenthetical.add(' (immediate subtypes: ');
                  // Note: it's tempting to just do
                  // `subinterfaces.map(_uniqueNamer.name).join(', ')`, but that
                  // won't work, because the names returned by
                  // `UniqueName.toString()` aren't finalized until we've
                  // visited the entire API and seen if there are class names
                  // that need to be disambiguated. So we accumulate the
                  // `UniqueName` objects into the `parenthetical` list and rely
                  // on `printNodes` converting everything to a string when the
                  // final API description is being output.
                  var commaNeeded = false;
                  for (final subinterface in subinterfaces) {
                    if (commaNeeded) {
                      parenthetical.add(', ');
                    } else {
                      commaNeeded = true;
                    }
                    parenthetical.add(_uniqueNamer.name(subinterface));
                  }
                  parenthetical.add(')');
                }
              } else {
                if (element.isAbstract) {
                  parentheticals.add(['abstract']);
                }
                if (element.isBase) {
                  parentheticals.add(['base']);
                }
                if (element.isMixinClass) {
                  parentheticals.add(['mixin']);
                }
                if (element.isInterface) {
                  parentheticals.add(['interface']);
                }
                if (element.isFinal) {
                  parentheticals.add(['final']);
                }
              }
            } else if (element is MixinElement) {
              if (element.isBase) {
                parentheticals.add(['base']);
              }
            }
          case ExtensionElement(:final extendedType):
            parentheticals.add([
              'extension on ',
              ..._describeType(extendedType),
            ]);
          case dynamic(:final runtimeType):
            throw UnimplementedError('Unexpected element: $runtimeType');
        }
        for (final member in element.children.sortedBy((m) => m.name ?? '')) {
          if (member.name case final name? when name.startsWith('_')) {
            // Ignore private members
            continue;
          }
          if (member is FieldElement) {
            // Ignore fields; we care about the getters and setters they induce.
            continue;
          }
          if (member is ConstructorElement &&
              element is ClassElement &&
              element.isAbstract &&
              (element.isFinal || element.isInterface || element.isSealed)) {
            // The class can't be constructed from outside of the library that
            // declares it, so its constructors aren't part of the public API.
            continue;
          }
          if (member is ConstructorElement && element is EnumElement) {
            // Enum constructors can't be called from outside the enum itself,
            // so they aren't part of the public API.
            continue;
          }
          final childNode = Node<MemberSortKey>();
          childNode.text.add(member.apiName);
          _dumpElement(member, childNode);
          node.childNodes.add((MemberSortKey(member), childNode));
        }
      case TopLevelFunctionElement(:final type):
        parentheticals.add(['function: ', ..._describeType(type)]);
      case ExecutableElement(:final isStatic):
        final maybeStatic = isStatic ? 'static ' : '';
        switch (element) {
          case GetterElement(:final type):
            parentheticals.add([
              '${maybeStatic}getter: ',
              ..._describeType(type.returnType),
            ]);
          case SetterElement(:final type):
            parentheticals.add([
              '${maybeStatic}setter: ',
              ..._describeType(type.formalParameters.single.type),
            ]);
          case MethodElement(:final type):
            parentheticals.add([
              '${maybeStatic}method: ',
              ..._describeType(type),
            ]);
          case ConstructorElement(:final type):
            parentheticals.add(['constructor: ', ..._describeType(type)]);
          case dynamic(:final runtimeType):
            throw UnimplementedError('Unexpected element: $runtimeType');
        }
      case dynamic(:final runtimeType):
        throw UnimplementedError('Unexpected element: $runtimeType');
    }

    // For synthetic elements such as getters/setters induced by top level
    // variables and fields, annotations can be found on the corresponding
    // non-synthetic element.
    final nonSyntheticElement = element.nonSynthetic;
    if (nonSyntheticElement.metadata.hasDeprecated) {
      parentheticals.add(['deprecated']);
    }
    if (nonSyntheticElement.metadata.hasExperimental) {
      parentheticals.add(['experimental']);
    }

    if (parentheticals.isNotEmpty) {
      node.text.addAll(parentheticals.separatedBy(prefix: ' (', suffix: ')'));
    }
    if (node.childNodes.isNotEmpty) {
      node.text.add(':');
    }
  }

  /// Appends information to [node] describing [library].
  void _dumpLibrary(LibraryElement library, Node<MemberSortKey> node) {
    final uri = library.uri;
    node.text.addAll([uri, ':']);
    final definedNames = library.exportNamespace.definedNames2;
    for (final key in definedNames.keys.sorted()) {
      final element = definedNames[key]!;
      final childNode = Node<MemberSortKey>()
        ..text.add(_uniqueNamer.name(element));
      if (!_dumpedTopLevelElements.add(element)) {
        childNode.text.add(' (see above)');
      } else {
        _dumpElement(element, childNode);
      }
      node.childNodes.add((MemberSortKey(element), childNode));
    }
  }

  /// Returns a map from each sealed class in [library] to the set of its
  /// immediate sub-interfaces.
  ///
  /// If this method has been called before with the same [library], a cached
  /// map is returned from [_immediateSubinterfaceCache]. Otherwise a fresh map
  /// is computed.
  Map<ClassElement, Set<InterfaceElement>>
  _getOrComputeImmediateSubinterfaceMap(LibraryElement library) {
    if (_immediateSubinterfaceCache[library] case final m?) return m;
    final result = <ClassElement, Set<InterfaceElement>>{};
    for (final interface in [
      ...library.classes,
      ...library.mixins,
      ...library.enums,
      ...library.extensionTypes,
    ]..sortBy((e) => e.name!)) {
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
}
