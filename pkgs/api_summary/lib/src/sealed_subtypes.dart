// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:collection/collection.dart';

/// The public subtype frontier and non-public subtype coverage flag for a
/// `sealed` class.
typedef SealedSubtypeSummary = ({
  List<String> immediateSubtypes,
  bool hasNonPublicSubtypes,
});

typedef _SealedNode = ({
  ClassElement element,
  InterfaceType spaceType,
  bool isDirect,
  Set<ClassElement> ancestors,
});

typedef _FrontierCollection = ({
  Map<InterfaceElement, InterfaceType> publicSpaces,
  Set<InterfaceElement> directPublic,
  List<InterfaceType> nonPublicLeafTypes,
});

typedef _SubstType = ({
  DartType type,
  Map<TypeParameterElement, DartType> subst,
});

typedef _FuncSubstType = ({
  FunctionType fn,
  Map<TypeParameterElement, DartType> subst,
});

typedef _SubtypeEnv = ({
  LibraryElement library,
  Set<TypeParameterElement> visitedBounds,
});

/// Computes the transitive public subtype frontier and whether any uncovered
/// non-public subtypes exist for [sealedClass].
///
/// Mirrors the analyzer's sealed exhaustiveness expansion in two passes:
/// 1. Pass 1 expands reachable non-public `sealed` intermediate classes to
///    collect public frontier subtypes and non-public leaf subtype spaces.
/// 2. Pass 2 prunes transitively-discovered public subtypes whose space type is
///    already a strict subtype of another collected public subtype, then sets
///    `hasNonPublicSubtypes` if any non-public leaf space is not covered by a
///    kept public subtype space.
///
/// Non-public subtypes exposed only via a public `typedef` remain classified as
/// non-public (`immediateSubtypes` tracks exported interface declarations, not
/// type aliases).
SealedSubtypeSummary computeSealedSubtypes(
  ClassElement sealedClass,
  Map<ClassElement, Set<InterfaceElement>> immediateSubinterfaceMap, {
  required Set<Element> topLevelPublicElements,
  required bool isReferenced,
}) {
  final definedNames = isReferenced
      ? sealedClass.library.exportNamespace.definedNames2
      : null;
  bool isPublicSubtype(InterfaceElement sub) => definedNames != null
      ? definedNames.containsValue(sub.baseElement)
      : topLevelPublicElements.contains(sub.baseElement);

  final typeSystem = sealedClass.library.typeSystem;
  final nodes = _reachableSealedNodes(
    sealedClass,
    immediateSubinterfaceMap,
    isPublicSubtype: isPublicSubtype,
  );
  final frontier = _collectFrontierFromNodes(
    sealedClass.thisType,
    nodes,
    immediateSubinterfaceMap,
    isPublicSubtype: isPublicSubtype,
  );
  final keptPublic = _pruneRedundantTransitiveSubtypes(
    typeSystem,
    frontier.publicSpaces,
    frontier.directPublic,
  );
  final keptSpaceTypes = keptPublic.values.toList();
  final hasNonPublicSubtypes = frontier.nonPublicLeafTypes.any(
    (leaf) => !keptSpaceTypes.any((pub) => typeSystem.isSubtypeOf(leaf, pub)),
  );
  final immediateSubtypes = {
    for (final sub in keptPublic.keys)
      if (sub.name case final name? when name.isNotEmpty) name,
  }.sorted();

  return (
    immediateSubtypes: immediateSubtypes,
    hasNonPublicSubtypes: hasNonPublicSubtypes,
  );
}

List<_SealedNode> _reachableSealedNodes(
  ClassElement sealedClass,
  Map<ClassElement, Set<InterfaceElement>> immediateSubinterfaceMap, {
  required bool Function(InterfaceElement) isPublicSubtype,
}) {
  final rootType = sealedClass.thisType;
  final visited = <(ClassElement, DartType)>{(sealedClass, rootType)};
  final nodes = <_SealedNode>[
    (
      element: sealedClass,
      spaceType: rootType,
      isDirect: true,
      ancestors: {sealedClass},
    ),
  ];

  for (var i = 0; i < nodes.length; i++) {
    final current = nodes[i];
    final directSubs =
        immediateSubinterfaceMap[current.element] ?? const <InterfaceElement>{};
    for (final sub in directSubs) {
      if (sub is ClassElement && sub.isSealed && !isPublicSubtype(sub)) {
        final subSpace = _subclassAsInstanceOf(sub, current.spaceType);
        if (!current.ancestors.contains(sub) && visited.add((sub, subSpace))) {
          nodes.add((
            element: sub,
            spaceType: subSpace,
            isDirect: false,
            ancestors: {...current.ancestors, sub},
          ));
        }
      }
    }
  }
  return nodes;
}

_FrontierCollection _collectFrontierFromNodes(
  InterfaceType rootType,
  List<_SealedNode> nodes,
  Map<ClassElement, Set<InterfaceElement>> immediateSubinterfaceMap, {
  required bool Function(InterfaceElement) isPublicSubtype,
}) {
  final publicSpaces = <InterfaceElement, InterfaceType>{};
  final directPublic = <InterfaceElement>{};
  final nonPublicLeafTypes = <InterfaceType>[];

  for (final node in nodes) {
    final directSubs =
        immediateSubinterfaceMap[node.element] ?? const <InterfaceElement>{};
    for (final sub in directSubs) {
      if (isPublicSubtype(sub)) {
        publicSpaces[sub] ??= _subclassAsInstanceOf(sub, rootType);
        if (node.isDirect) {
          directPublic.add(sub);
        }
      } else if (!(sub is ClassElement && sub.isSealed)) {
        nonPublicLeafTypes.add(_subclassAsInstanceOf(sub, node.spaceType));
      }
    }
  }
  return (
    publicSpaces: publicSpaces,
    directPublic: directPublic,
    nonPublicLeafTypes: nonPublicLeafTypes,
  );
}

Map<InterfaceElement, InterfaceType> _pruneRedundantTransitiveSubtypes(
  TypeSystem typeSystem,
  Map<InterfaceElement, InterfaceType> publicSpaces,
  Set<InterfaceElement> directPublic,
) {
  final kept = <InterfaceElement, InterfaceType>{};
  for (final MapEntry(:key, :value) in publicSpaces.entries) {
    final isRedundantTransitive =
        !directPublic.contains(key) &&
        publicSpaces.entries.any(
          (other) =>
              other.key != key &&
              typeSystem.isSubtypeOf(value, other.value) &&
              !typeSystem.isSubtypeOf(other.value, value),
        );
    if (!isRedundantTransitive) {
      kept[key] = value;
    }
  }
  return kept;
}

/// Computes the exhaustiveness space type of [subClass] as an instance of
/// [sealedClassType], mirroring
/// `AnalyzerSealedClassOperations.getSubclassAsInstanceOf`.
InterfaceType _subclassAsInstanceOf(
  InterfaceElement subClass,
  InterfaceType sealedClassType,
) {
  final thisType = subClass.thisType;
  if (thisType.typeArguments.isEmpty) {
    return thisType;
  }
  final asSealedClass = thisType.asInstanceOf(sealedClassType.element);
  if (asSealedClass != null &&
      _canTriviallySubstitute(
        subClass,
        asSealedTypeArgs: asSealedClass.typeArguments,
        targetTypeArgs: sealedClassType.typeArguments,
      )) {
    return subClass.instantiate(
      typeArguments: sealedClassType.typeArguments,
      nullabilitySuffix: NullabilitySuffix.none,
    );
  }
  return subClass.library.typeSystem.instantiateInterfaceToBounds(
    element: subClass,
    nullabilitySuffix: NullabilitySuffix.none,
  );
}

bool _canTriviallySubstitute(
  InterfaceElement subClass, {
  required List<DartType> asSealedTypeArgs,
  required List<DartType> targetTypeArgs,
}) {
  final thisTypeArgs = subClass.thisType.typeArguments;
  final typeParameters = subClass.typeParameters;
  if (thisTypeArgs.length != asSealedTypeArgs.length ||
      typeParameters.length != targetTypeArgs.length) {
    return false;
  }
  for (var i = 0; i < thisTypeArgs.length; i++) {
    if (thisTypeArgs[i] != asSealedTypeArgs[i]) {
      return false;
    }
  }
  final substitution = <TypeParameterElement, DartType>{
    for (var i = 0; i < typeParameters.length; i++)
      typeParameters[i]: targetTypeArgs[i],
  };
  final env = (
    library: subClass.library,
    visitedBounds: const <TypeParameterElement>{},
  );
  for (var i = 0; i < typeParameters.length; i++) {
    final bound = typeParameters[i].bound;
    if (bound != null &&
        !_isSubstSubtype(
          (type: targetTypeArgs[i], subst: const {}),
          (type: bound, subst: substitution),
          env,
        )) {
      return false;
    }
  }
  return true;
}

_SubstType _resolveSubstType(_SubstType term, LibraryElement library) {
  if (term.subst.isEmpty) return term;
  if (!_hasUnaliasedFunctionWithSubst(term.type, term.subst)) {
    return (
      type: _substituteType(term.type, term.subst, library),
      subst: const {},
    );
  }
  return term;
}

bool _hasUnaliasedFunctionWithSubst(
  DartType type,
  Map<TypeParameterElement, DartType> subst, [
  bool insideUnaliasedFunction = false,
]) {
  if (subst.isEmpty) return false;
  if (type.alias case final alias? when !insideUnaliasedFunction) {
    return alias.typeArguments.any(
      (arg) => _hasUnaliasedFunctionWithSubst(arg, subst),
    );
  }
  return switch (type) {
    TypeParameterType(:final element) =>
      insideUnaliasedFunction && subst.containsKey(element),
    FunctionType(
      :final returnType,
      :final typeParameters,
      :final formalParameters,
    ) =>
      _hasUnaliasedFunctionWithSubst(returnType, subst, true) ||
          typeParameters.any(
            (p) =>
                p.bound != null &&
                _hasUnaliasedFunctionWithSubst(p.bound!, subst, true),
          ) ||
          formalParameters.any(
            (p) => _hasUnaliasedFunctionWithSubst(p.type, subst, true),
          ),
    InterfaceType(:final typeArguments) => typeArguments.any(
      (arg) =>
          _hasUnaliasedFunctionWithSubst(arg, subst, insideUnaliasedFunction),
    ),
    RecordType(:final positionalFields, :final namedFields) =>
      positionalFields.any(
            (f) => _hasUnaliasedFunctionWithSubst(
              f.type,
              subst,
              insideUnaliasedFunction,
            ),
          ) ||
          namedFields.any(
            (f) => _hasUnaliasedFunctionWithSubst(
              f.type,
              subst,
              insideUnaliasedFunction,
            ),
          ),
    _ => false,
  };
}

DartType _substituteType(
  DartType type,
  Map<TypeParameterElement, DartType> substitution,
  LibraryElement library,
) {
  if (type.alias case final alias? when alias.typeArguments.isNotEmpty) {
    return alias.element.instantiate(
      typeArguments: alias.typeArguments
          .map((arg) => _substituteType(arg, substitution, library))
          .toList(),
      nullabilitySuffix: alias.nullabilitySuffix,
    );
  }
  return switch (type) {
    TypeParameterType(:final element, :final nullabilitySuffix) =>
      switch (substitution[element]) {
        null => type,
        final replacement
            when nullabilitySuffix == NullabilitySuffix.question =>
          library.typeSystem.leastUpperBound(
            replacement,
            library.typeProvider.nullType,
          ),
        final replacement => replacement,
      },
    InterfaceType(
      :final element,
      :final typeArguments,
      :final nullabilitySuffix,
    )
        when typeArguments.isNotEmpty =>
      element.instantiate(
        typeArguments: typeArguments
            .map((arg) => _substituteType(arg, substitution, library))
            .toList(),
        nullabilitySuffix: nullabilitySuffix,
      ),
    RecordType(
      :final positionalFields,
      :final namedFields,
      :final nullabilitySuffix,
    ) =>
      RecordType(
        positional: positionalFields
            .map((field) => _substituteType(field.type, substitution, library))
            .toList(),
        named: {
          for (final field in namedFields)
            field.name: _substituteType(field.type, substitution, library),
        },
        nullabilitySuffix: nullabilitySuffix,
      ),
    _ => type,
  };
}

bool _isSubstSubtype(_SubstType rawSub, _SubstType rawSup, _SubtypeEnv env) {
  final sub = _resolveSubstType(rawSub, env.library);
  final sup = _resolveSubstType(rawSup, env.library);
  if (sub.subst.isEmpty && sup.subst.isEmpty) {
    return env.library.typeSystem.isSubtypeOf(sub.type, sup.type);
  }
  if (_checkLeftSpecialSubtype(sub, sup, env) case final result?) {
    return result;
  }
  if (_checkRightSpecialSubtype(sub, sup, env) case final result?) {
    return result;
  }
  return _checkCompoundSubstSubtype(sub, sup, env);
}

bool? _checkLeftSpecialSubtype(
  _SubstType sub,
  _SubstType sup,
  _SubtypeEnv env,
) {
  final subType = sub.type;
  final supType = sup.type;
  final typeProvider = env.library.typeProvider;
  if (_isTrivialTopOrBottomMatch(subType, supType)) return true;
  if (subType is DynamicType || subType is VoidType) {
    return _isSubstSubtype(
      (type: typeProvider.objectQuestionType, subst: const {}),
      sup,
      env,
    );
  }
  if (subType.nullabilitySuffix == NullabilitySuffix.question) {
    final nonNullSub = _withoutQuestion(subType, env.library.typeSystem);
    return _isSubstSubtype((type: nonNullSub, subst: sub.subst), sup, env) &&
        _isSubstSubtype(
          (type: typeProvider.nullType, subst: const {}),
          sup,
          env,
        );
  }
  if (subType.isDartCoreNull) {
    return supType.nullabilitySuffix == NullabilitySuffix.question ||
        (supType is InterfaceType &&
            supType.isDartAsyncFutureOr &&
            _isSubstSubtype(sub, (
              type: supType.typeArguments[0],
              subst: sup.subst,
            ), env));
  }
  if (subType case TypeParameterType(:final element)) {
    final bound = element.bound;
    if (bound == null || env.visitedBounds.contains(element)) return false;
    return _isSubstSubtype(
      (type: bound, subst: const {}),
      sup,
      (library: env.library, visitedBounds: {...env.visitedBounds, element}),
    );
  }
  return null;
}

bool _isTrivialTopOrBottomMatch(DartType subType, DartType supType) =>
    subType is InvalidType ||
    supType is InvalidType ||
    supType is DynamicType ||
    supType is VoidType ||
    (supType.isDartCoreObject &&
        supType.nullabilitySuffix == NullabilitySuffix.question) ||
    (subType is NeverType &&
        subType.nullabilitySuffix == NullabilitySuffix.none);

DartType _withoutQuestion(DartType type, TypeSystem typeSystem) =>
    type is TypeParameterType
    ? type.element.instantiate(nullabilitySuffix: NullabilitySuffix.none)
    : typeSystem.promoteToNonNull(type);

bool? _checkRightSpecialSubtype(
  _SubstType sub,
  _SubstType sup,
  _SubtypeEnv env,
) {
  final subType = sub.type;
  final supType = sup.type;
  final typeProvider = env.library.typeProvider;
  if (subType is InterfaceType && subType.isDartAsyncFutureOr) {
    final arg = subType.typeArguments[0];
    return _isSubstSubtype((type: arg, subst: sub.subst), sup, env) &&
        _isSubstSubtype(
          (type: typeProvider.futureType(arg), subst: sub.subst),
          sup,
          env,
        );
  }
  if (supType.nullabilitySuffix == NullabilitySuffix.question) {
    final nonNullSup = _withoutQuestion(supType, env.library.typeSystem);
    return _isSubstSubtype(sub, (type: nonNullSup, subst: sup.subst), env);
  }
  if (supType is InterfaceType && supType.isDartAsyncFutureOr) {
    final arg = supType.typeArguments[0];
    return _isSubstSubtype(sub, (
          type: typeProvider.futureType(arg),
          subst: sup.subst,
        ), env) ||
        _isSubstSubtype(sub, (type: arg, subst: sup.subst), env);
  }
  if (supType.isDartCoreObject) {
    if (subType is InterfaceType && subType.element is ExtensionTypeElement) {
      return subType.interfaces.any(
        (i) => _isSubstSubtype((type: i, subst: sub.subst), sup, env),
      );
    }
    return true;
  }
  if (supType.isDartCoreFunction) return subType is FunctionType;
  if (supType.isDartCoreRecord) return subType is RecordType;
  return null;
}

bool _checkCompoundSubstSubtype(
  _SubstType sub,
  _SubstType sup,
  _SubtypeEnv env,
) => switch ((sub.type, sup.type)) {
  (final InterfaceType subType, final InterfaceType supType) =>
    _isInterfaceSubstSubtype(
      (type: subType, subst: sub.subst),
      (type: supType, subst: sup.subst),
      env,
    ),
  (final RecordType subType, final RecordType supType) => _isRecordSubstSubtype(
    (type: subType, subst: sub.subst),
    (type: supType, subst: sup.subst),
    env,
  ),
  (final FunctionType subType, final FunctionType supType) =>
    _isFunctionSubstSubtype(
      (fn: subType, subst: sub.subst),
      (fn: supType, subst: sup.subst),
      env,
    ),
  _ => false,
};

bool _isInterfaceSubstSubtype(
  ({InterfaceType type, Map<TypeParameterElement, DartType> subst}) sub,
  ({InterfaceType type, Map<TypeParameterElement, DartType> subst}) sup,
  _SubtypeEnv env,
) {
  final asSup = sub.type.asInstanceOf(sup.type.element);
  if (asSup == null ||
      asSup.typeArguments.length != sup.type.typeArguments.length) {
    return false;
  }
  for (var i = 0; i < sup.type.typeArguments.length; i++) {
    if (!_isSubstSubtype(
      (type: asSup.typeArguments[i], subst: sub.subst),
      (type: sup.type.typeArguments[i], subst: sup.subst),
      env,
    )) {
      return false;
    }
  }
  return true;
}

bool _isRecordSubstSubtype(
  ({RecordType type, Map<TypeParameterElement, DartType> subst}) sub,
  ({RecordType type, Map<TypeParameterElement, DartType> subst}) sup,
  _SubtypeEnv env,
) {
  final subPos = sub.type.positionalFields;
  final supPos = sup.type.positionalFields;
  final subNamed = sub.type.namedFields;
  final supNamed = sup.type.namedFields;
  if (subPos.length != supPos.length || subNamed.length != supNamed.length) {
    return false;
  }
  for (var i = 0; i < subPos.length; i++) {
    if (!_isSubstSubtype(
      (type: subPos[i].type, subst: sub.subst),
      (type: supPos[i].type, subst: sup.subst),
      env,
    )) {
      return false;
    }
  }
  for (var i = 0; i < subNamed.length; i++) {
    if (subNamed[i].name != supNamed[i].name ||
        !_isSubstSubtype(
          (type: subNamed[i].type, subst: sub.subst),
          (type: supNamed[i].type, subst: sup.subst),
          env,
        )) {
      return false;
    }
  }
  return true;
}

bool _isFunctionSubstSubtype(
  _FuncSubstType rawSub,
  _FuncSubstType rawSup,
  _SubtypeEnv env,
) {
  final subParams = rawSub.fn.typeParameters;
  final supParams = rawSup.fn.typeParameters;
  if (subParams.length != supParams.length) return false;

  var subFn = rawSub.fn;
  var supFn = rawSup.fn;
  if (subParams.isNotEmpty) {
    if (!_areGenericFunctionBoundsEqual(rawSub, rawSup, env)) return false;
    final freshArgs = [
      for (final p in subParams)
        p.instantiate(nullabilitySuffix: NullabilitySuffix.none),
    ];
    subFn = subFn.instantiate(freshArgs);
    supFn = supFn.instantiate(freshArgs);
  }
  final sub = (fn: subFn, subst: rawSub.subst);
  final sup = (fn: supFn, subst: rawSup.subst);
  return _isSubstSubtype(
        (type: sub.fn.returnType, subst: sub.subst),
        (type: sup.fn.returnType, subst: sup.subst),
        env,
      ) &&
      _arePositionalParamsCompatible(sub, sup, env) &&
      _areNamedParamsCompatible(sub, sup, env);
}

bool _areGenericFunctionBoundsEqual(
  _FuncSubstType sub,
  _FuncSubstType sup,
  _SubtypeEnv env,
) {
  final subParams = sub.fn.typeParameters;
  final supParams = sup.fn.typeParameters;
  final freshArgs = [
    for (final p in subParams)
      p.instantiate(nullabilitySuffix: NullabilitySuffix.none),
  ];
  final supBoundSubst = <TypeParameterElement, DartType>{
    ...sup.subst,
    for (var i = 0; i < supParams.length; i++) supParams[i]: freshArgs[i],
  };
  final objectQ = env.library.typeProvider.objectQuestionType;
  for (var i = 0; i < subParams.length; i++) {
    final subBound = (type: subParams[i].bound ?? objectQ, subst: sub.subst);
    final supBound = (
      type: supParams[i].bound ?? objectQ,
      subst: supBoundSubst,
    );
    if (!_isSubstSubtype(subBound, supBound, env) ||
        !_isSubstSubtype(supBound, subBound, env)) {
      return false;
    }
  }
  return true;
}

bool _arePositionalParamsCompatible(
  _FuncSubstType sub,
  _FuncSubstType sup,
  _SubtypeEnv env,
) {
  final subReq = sub.fn.normalParameterTypes;
  final supReq = sup.fn.normalParameterTypes;
  final subPos = [...subReq, ...sub.fn.optionalParameterTypes];
  final supPos = [...supReq, ...sup.fn.optionalParameterTypes];
  if (subReq.length > supReq.length || subPos.length < supPos.length) {
    return false;
  }
  for (var i = 0; i < supPos.length; i++) {
    if (!_isSubstSubtype(
      (type: supPos[i], subst: sup.subst),
      (type: subPos[i], subst: sub.subst),
      env,
    )) {
      return false;
    }
  }
  return true;
}

bool _areNamedParamsCompatible(
  _FuncSubstType sub,
  _FuncSubstType sup,
  _SubtypeEnv env,
) {
  if (!_requiredNamedNames(sup.fn).containsAll(_requiredNamedNames(sub.fn))) {
    return false;
  }
  final subNamed = sub.fn.namedParameterTypes;
  for (final MapEntry(:key, :value) in sup.fn.namedParameterTypes.entries) {
    final subParamType = subNamed[key];
    if (subParamType == null ||
        !_isSubstSubtype(
          (type: value, subst: sup.subst),
          (type: subParamType, subst: sub.subst),
          env,
        )) {
      return false;
    }
  }
  return true;
}

Set<String> _requiredNamedNames(FunctionType fn) => {
  for (final p in fn.formalParameters)
    if (p.isRequiredNamed && p.name != null) p.name!,
};
