// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

import 'api_declaration.dart';
import 'api_type.dart';
import 'extensions.dart';
import 'member_sorting.dart';
import 'node.dart';
import 'uri_sorting.dart';

/// Converts the [package] model into a canonical, human-readable textual
/// summary for `api.txt`.
String renderTextSummary(ApiSummary package) =>
    _ApiTextRenderer(package).render();

class _JsonUniqueName {
  final String _nameHint;
  int? _disambiguator;

  _JsonUniqueName(_JsonUniqueNamer uniqueNamer, this._nameHint)
    : assert(!_nameHint.contains('@')) {
    final conflicts = uniqueNamer._conflicts[_nameHint] ??= [];
    if (conflicts.length == 1) {
      conflicts[0]._disambiguator = 1;
    }
    conflicts.add(this);
    if (conflicts.length > 1) {
      _disambiguator = conflicts.length;
    }
  }

  @override
  String toString() => [
    _nameHint,
    if (_disambiguator case final disambiguator?) '@$disambiguator',
  ].join();
}

class _JsonUniqueNamer {
  final _names = <String, _JsonUniqueName>{};
  final _conflicts = <String, List<_JsonUniqueName>>{};

  _JsonUniqueName name(String elementKey, String nameHint) =>
      _names[elementKey] ??= _JsonUniqueName(this, nameHint);
}

enum _Kind { classDeclaration, enumDeclaration, mixinDeclaration }

class _ApiTextRenderer {
  final ApiSummary _package;
  final _uniqueNamer = _JsonUniqueNamer();
  final _renderedTopLevelElements =
      <String>{}; // unique key: "locationUri#name"
  final _potentiallyDanglingReferences = <ApiInterfaceType>[];

  _ApiTextRenderer(this._package);

  String render() {
    final nodes = <Uri, Node<MemberSortKey>>{};

    for (final library in _package.libraries) {
      final uri = Uri.parse(library.uri);
      final node = nodes[uri] = Node<MemberSortKey>();
      _renderLibrary(library, node);
    }

    // Process dangling references
    var i = 0;
    while (i < _potentiallyDanglingReferences.length) {
      final type = _potentiallyDanglingReferences[i];
      i++;
      if (type.libraryUri == null) continue;

      final key = '${type.libraryUri}#${type.name}';
      if (!_renderedTopLevelElements.add(key)) continue;

      final containingLibraryUri = Uri.parse(type.libraryUri!);
      final childNode = Node<MemberSortKey>()
        ..text.add(_uniqueNamer.name(key, type.name));

      // Since it's a dangling reference, it is either referenced or non-public
      if (!containingLibraryUri.isIn(_package.name)) {
        childNode.text.add(' (referenced)');
      } else {
        childNode.text.add(' (non-public)');
      }

      (nodes[containingLibraryUri] ??= Node<MemberSortKey>()
            ..text.add('$containingLibraryUri:'))
          .childNodes
          .add((_computeSortKeyForDangling(type), childNode));
    }

    final sortedNodes = [
      for (final entry in nodes.entries)
        (UriSortKey(entry.key, _package.name), entry.value),
    ];

    final stringBuffer = StringBuffer();
    printNodes(stringBuffer, sortedNodes);
    return stringBuffer.toString();
  }

  void _renderLibrary(ApiLibrary library, Node<MemberSortKey> node) {
    node.text.addAll([Uri.parse(library.uri), ':']);

    // Combine all top level items to sort them correctly
    final allItems =
        <({MemberSortKey sortKey, ApiDeclaration element, _Kind? kind})>[];
    for (final e in library.classes) {
      allItems.add((
        sortKey: _computeSortKey(e),
        element: e,
        kind: _Kind.classDeclaration,
      ));
    }
    for (final e in library.enums) {
      allItems.add((
        sortKey: _computeSortKey(e),
        element: e,
        kind: _Kind.enumDeclaration,
      ));
    }
    for (final e in library.mixins) {
      allItems.add((
        sortKey: _computeSortKey(e),
        element: e,
        kind: _Kind.mixinDeclaration,
      ));
    }
    for (final e in library.extensions) {
      allItems.add((sortKey: _computeSortKey(e), element: e, kind: null));
    }
    for (final e in library.extensionTypes) {
      allItems.add((sortKey: _computeSortKey(e), element: e, kind: null));
    }
    for (final e in library.functions) {
      allItems.add((
        sortKey: _computeSortKey(e, isTopLevel: true),
        element: e,
        kind: null,
      ));
    }

    for (final e in library.typeAliases) {
      allItems.add((sortKey: _computeSortKey(e), element: e, kind: null));
    }

    allItems.sort((a, b) => a.sortKey.compareTo(b.sortKey));

    for (final item in allItems) {
      final element = item.element;
      final name = element.name;
      final locationUri = element.locationUri;
      var key = '$locationUri#$name';
      if (element is ApiExtension && name.isEmpty) {
        final memberNames = element.methods.map((m) => m.name).join(',');
        key = '$key#${element.extendedType.toJson()}#$memberNames';
      }

      final childNode = Node<MemberSortKey>()
        ..text.add(_uniqueNamer.name(key, name));

      if (!_renderedTopLevelElements.add(key)) {
        childNode.text.add(' (see above)');
      } else {
        switch (element) {
          case ApiClass():
            _renderClass(library.uri, element, childNode, kind: item.kind!);
          case ApiExtension():
            _renderExtension(library.uri, element, childNode);
          case ApiExtensionType():
            _renderExtensionType(library.uri, element, childNode);
          case ApiExecutable():
            _renderExecutable(
              library.uri,
              element,
              childNode,
              isTopLevel: true,
            );
          case ApiTypeAlias():
            _renderTypeAlias(library.uri, element, childNode);
        }
      }

      node.childNodes.add((item.sortKey, childNode));
    }
  }

  void _renderClass(
    String libraryUri,
    ApiClass element,
    Node<MemberSortKey> node, {
    required _Kind kind,
  }) {
    final parentheticals = <List<Object?>>[];
    final instanceDescription = <Object?>[];

    // Determine type
    if (kind == _Kind.enumDeclaration) {
      instanceDescription.add('enum');
    } else if (element.modifiers.contains(ApiClassModifier.isMixin) &&
        kind == _Kind.classDeclaration) {
      instanceDescription.add('mixin class');
    } else if (element.modifiers.contains(ApiClassModifier.isMixin) ||
        kind == _Kind.mixinDeclaration) {
      instanceDescription.add('mixin');
    } else {
      instanceDescription.add('class');
    }

    if (element.typeParameters.isNotEmpty) {
      instanceDescription.addAll(_renderTypeParameters(element.typeParameters));
    }

    if (element.supertype != null) {
      instanceDescription.addAll([
        ' extends ',
        ..._describeType(element.supertype!),
      ]);
    }

    if (element.superclassConstraints.isNotEmpty) {
      instanceDescription.addAll(
        element.superclassConstraints
            .map(_describeType)
            .separatedBy(prefix: ' on '),
      );
    }

    if (element.mixins.isNotEmpty) {
      instanceDescription.addAll(
        element.mixins.map(_describeType).separatedBy(prefix: ' with '),
      );
    }

    if (element.interfaces.isNotEmpty) {
      instanceDescription.addAll(
        element.interfaces
            .map(_describeType)
            .separatedBy(prefix: ' implements '),
      );
    }

    parentheticals.add(instanceDescription);

    if (element.modifiers.contains(ApiClassModifier.isSealed)) {
      final parenthetical = <Object?>['sealed'];
      parentheticals.add(parenthetical);
      if (element.immediateSubtypes.isNotEmpty) {
        parenthetical.add(' (immediate subtypes: ');
        var commaNeeded = false;
        for (final sub in element.immediateSubtypes) {
          if (commaNeeded) {
            parenthetical.add(', ');
          } else {
            commaNeeded = true;
          }
          parenthetical.add(sub);
        }
        parenthetical.add(')');
      }
    } else if (kind != _Kind.enumDeclaration) {
      if (element.modifiers.contains(ApiClassModifier.isAbstract)) {
        parentheticals.add(['abstract']);
      }
      if (element.modifiers.contains(ApiClassModifier.isBase)) {
        parentheticals.add(['base']);
      }
      if (element.modifiers.contains(ApiClassModifier.isMixin)) {
        parentheticals.add(['mixin']);
      }
      if (element.modifiers.contains(ApiClassModifier.isInterface)) {
        parentheticals.add(['interface']);
      }
      if (element.modifiers.contains(ApiClassModifier.isFinal)) {
        parentheticals.add(['final']);
      }
    }

    if (element.status == ApiDeclarationStatus.referenced) {
      parentheticals.add(['referenced']);
    } else if (element.status == ApiDeclarationStatus.nonPublic) {
      parentheticals.add(['non-public']);
    }

    _renderParentheticals(
      parentheticals: parentheticals,
      element: element,
      node: node,
    );

    _renderMembers(element.constructors, element.methods, node);
  }

  void _renderExtension(
    String libraryUri,
    ApiExtension element,
    Node<MemberSortKey> node,
  ) {
    final parentheticals = <List<Object?>>[];
    for (final bound in element.typeParameters.values) {
      if (bound != null) _describeType(bound);
    }
    parentheticals.add([
      'extension on ',
      ..._describeType(element.extendedType),
    ]);

    _renderParentheticals(
      parentheticals: parentheticals,
      element: element,
      node: node,
    );
    _renderMembers([], element.methods, node);
  }

  void _renderExtensionType(
    String libraryUri,
    ApiExtensionType element,
    Node<MemberSortKey> node,
  ) {
    final parentheticals = <List<Object?>>[];
    final instanceDescription = <Object?>['extension type'];

    if (element.typeParameters.isNotEmpty) {
      instanceDescription.addAll(_renderTypeParameters(element.typeParameters));
    }
    if (element.interfaces.isNotEmpty) {
      instanceDescription.addAll(
        element.interfaces
            .map(_describeType)
            .separatedBy(prefix: ' implements '),
      );
    }
    parentheticals.add(instanceDescription);

    _renderParentheticals(
      parentheticals: parentheticals,
      element: element,
      node: node,
    );
    _renderMembers(element.constructors, element.methods, node);
  }

  void _renderExecutable(
    String libraryUri,
    ApiExecutable element,
    Node<MemberSortKey> node, {
    bool isTopLevel = false,
  }) {
    final parentheticals = <List<Object?>>[];
    for (final bound in element.typeParameters.values) {
      if (bound != null) _describeType(bound);
    }

    final maybeStatic =
        ((element.isStatic || isTopLevel) &&
            element.kind != ApiExecutableKind.function)
        ? 'static '
        : '';
    switch (element.kind) {
      case ApiExecutableKind.getter:
        parentheticals.add([
          '$maybeStatic${'getter: '}',
          ..._describeType(element.returnType),
        ]);
      case ApiExecutableKind.setter:
        parentheticals.add([
          '$maybeStatic${'setter: '}',
          ..._describeType(element.parameters.single.type),
        ]);
      case ApiExecutableKind.method || ApiExecutableKind.function:
        parentheticals.add([
          '$maybeStatic${element.kind.name}: ',
          ..._describeFunctionLike(element),
        ]);
      case ApiExecutableKind.constructor:
        parentheticals.add([
          'constructor: ',
          ..._describeFunctionLike(element),
        ]);
    }

    _renderParentheticals(
      parentheticals: parentheticals,
      element: element,
      node: node,
    );
  }

  void _renderTypeAlias(
    String libraryUri,
    ApiTypeAlias element,
    Node<MemberSortKey> node,
  ) {
    final parentheticals = <List<Object?>>[];
    final description = <Object?>['type alias'];
    if (element.typeParameters.isNotEmpty) {
      description.addAll(_renderTypeParameters(element.typeParameters));
    }
    description.addAll([' for ', ..._describeType(element.aliasedType)]);
    parentheticals.add(description);

    _renderParentheticals(
      parentheticals: parentheticals,
      element: element,
      node: node,
    );
  }

  void _renderMembers(
    List<ApiExecutable> constructors,
    List<ApiExecutable> methods,
    Node<MemberSortKey> node,
  ) {
    final members = <({MemberSortKey sortKey, ApiExecutable element})>[];
    for (final e in constructors) {
      members.add((sortKey: _computeSortKey(e, isInstance: true), element: e));
    }
    for (final e in methods) {
      members.add((sortKey: _computeSortKey(e, isInstance: true), element: e));
    }
    members.sort((a, b) => a.sortKey.compareTo(b.sortKey));

    if (members.isNotEmpty) {
      node.text.add(':');
    }

    for (final item in members) {
      final member = item.element;
      final childNode = Node<MemberSortKey>();
      childNode.text.add(member.name);
      _renderExecutable('', member, childNode);
      node.childNodes.add((item.sortKey, childNode));
    }
  }

  List<Object?> _describeFunctionLike(ApiExecutable element) {
    final params = <List<Object?>>[];
    final optionalParams = <List<Object?>>[];
    final namedParams = <String, List<Object?>>{};

    for (final param in element.parameters) {
      if (param.isNamed) {
        namedParams[param.name] = <Object?>[
          if (param.isDeprecated) 'deprecated ',
          if (param.isRequired) 'required ',
          ..._describeType(param.type),
        ];
      } else if (param.isOptionalPositional) {
        optionalParams.add(<Object?>[
          if (param.isDeprecated) 'deprecated ',
          ..._describeType(param.type),
        ]);
      } else {
        params.add(<Object?>[
          if (param.isDeprecated) 'deprecated ',
          ..._describeType(param.type),
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
            .map((e) => <Object?>[...e.value, ' ${e.key}'])
            .separatedBy(prefix: '{', suffix: '}'),
      );
    }

    return <Object?>[
      ..._describeType(element.returnType),
      ' Function',
      if (element.typeParameters.isNotEmpty)
        ..._renderTypeParameters(element.typeParameters),
      '(',
      ...params.separatedBy(),
      ')',
    ];
  }

  List<Object?> _describeType(ApiType type) {
    switch (type) {
      case ApiDynamicType():
        return ['dynamic'];
      case ApiVoidType():
        return ['void'];
      case ApiTypeParameterType():
        return [type.name, if (type.isNullable) '?'];
      case ApiInterfaceType():
        _potentiallyDanglingReferences.add(type);
        final key = '${type.libraryUri}#${type.name}';
        final name = type.libraryUri != null
            ? _uniqueNamer.name(key, type.name)
            : type.name;
        return [
          name,
          if (type.typeArguments.isNotEmpty)
            ...type.typeArguments
                .map(_describeType)
                .separatedBy(prefix: '<', suffix: '>'),
          if (type.isNullable) '?',
        ];
      case ApiRecordType():
        if (type.positionalFields.length == 1 && type.namedFields.isEmpty) {
          return [
            '(',
            ..._describeType(type.positionalFields[0]),
            ',)',
            if (type.isNullable) '?',
          ];
        }
        return [
          ...<List<Object?>>[
            for (final positionalField in type.positionalFields)
              _describeType(positionalField),
            if (type.namedFields.isNotEmpty)
              type.namedFields
                  .sortedBy((f) => f.name)
                  .map((f) => <Object?>[..._describeType(f.type), ' ', f.name])
                  .separatedBy(prefix: '{', suffix: '}'),
          ].separatedBy(prefix: '(', suffix: ')'),
          if (type.isNullable) '?',
        ];
      case ApiFunctionType():
        for (final bound in type.typeParameters.values) {
          if (bound != null) _describeType(bound);
        }
        final params = <List<Object?>>[];
        final optionalParams = <List<Object?>>[];
        final namedParams = <String, List<Object?>>{};
        for (final formalParameter in type.parameters) {
          if (formalParameter.isNamed) {
            namedParams[formalParameter.name] = <Object?>[
              if (formalParameter.isDeprecated) 'deprecated ',
              if (formalParameter.isRequired) 'required ',
              ..._describeType(formalParameter.type),
            ];
          } else if (formalParameter.isOptionalPositional) {
            optionalParams.add(<Object?>[
              if (formalParameter.isDeprecated) 'deprecated ',
              ..._describeType(formalParameter.type),
            ]);
          } else {
            params.add(<Object?>[
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
                .map((e) => <Object?>[...e.value, ' ${e.key}'])
                .separatedBy(prefix: '{', suffix: '}'),
          );
        }
        return <Object?>[
          ..._describeType(type.returnType),
          ' Function',
          if (type.typeParameters.isNotEmpty)
            ..._renderTypeParameters(type.typeParameters),
          '(',
          ...params.separatedBy(),
          ')',
          if (type.isNullable) '?',
        ];
    }
  }

  void _renderParentheticals({
    required List<List<Object?>> parentheticals,
    required ApiDeclaration element,
    required Node<MemberSortKey> node,
  }) {
    if (element.isDeprecated) {
      parentheticals.add(['deprecated']);
    }
    if (element.isExperimental) {
      parentheticals.add(['experimental']);
    }
    if (element.isVisibleForTesting) {
      parentheticals.add(['visible for testing']);
    }
    if (parentheticals.isNotEmpty) {
      node.text.addAll(parentheticals.separatedBy(prefix: ' (', suffix: ')'));
    }
  }

  List<Object?> _renderTypeParameters(Map<String, ApiType?> typeParameters) {
    if (typeParameters.isEmpty) return const [];
    return typeParameters.entries
        .map(
          (e) => <Object?>[
            e.key,
            if (e.value != null) ...[' extends ', ..._describeType(e.value!)],
          ],
        )
        .separatedBy(prefix: '<', suffix: '>');
  }
}

MemberSortKey _computeSortKey(
  ApiDeclaration element, {
  bool isInstance = false,
  bool isTopLevel = false,
}) => switch (element) {
  ApiClass() || ApiExtensionType() => MemberSortKey(
    isInstanceMember: isInstance,
    category: MemberCategory.interface,
    name: element.name,
    isSetter: false,
  ),
  ApiExtension() => MemberSortKey(
    isInstanceMember: isInstance,
    category: MemberCategory.extension,
    name: element.name,
    isSetter: false,
  ),
  ApiExecutable(:final kind, :final isStatic) => MemberSortKey(
    isInstanceMember: isInstance && !(isTopLevel || isStatic),
    category: switch (kind) {
      ApiExecutableKind.constructor => MemberCategory.constructor,
      ApiExecutableKind.getter ||
      ApiExecutableKind.setter => MemberCategory.propertyAccessor,
      _ => MemberCategory.topLevelFunctionOrMethod,
    },
    name: element.name,
    isSetter: kind == ApiExecutableKind.setter,
  ),
  ApiTypeAlias() => MemberSortKey(
    isInstanceMember: isInstance,
    category: MemberCategory.typeAlias,
    name: element.name,
    isSetter: false,
  ),
};

MemberSortKey _computeSortKeyForDangling(ApiInterfaceType type) =>
    MemberSortKey(
      isInstanceMember: false,
      category: MemberCategory.interface,
      name: type.name,
      isSetter: false,
    );
