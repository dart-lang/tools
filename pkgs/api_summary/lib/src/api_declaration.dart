// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'api_type.dart';
import 'json_utils.dart';
import 'text_renderer.dart';

/// The exposure status of an API declaration within the summarized package.
enum ApiDeclarationStatus {
  /// The declaration is part of the public API of the package.
  public,

  /// The declaration is from an external package or SDK library referenced
  /// by the public API.
  referenced,

  /// The declaration is internal (non-public) but reachable through public
  /// API signatures.
  nonPublic,
}

/// The specific kind of executable member declaration.
enum ApiExecutableKind { getter, setter, method, constructor, function }

/// Modifiers that define the inheritance, implementation, or instantiation
/// capabilities of a class or mixin.
enum ApiClassModifier {
  isSealed('sealed'),
  isAbstract('abstract'),
  isBase('base'),
  isMixin('mixin'),
  isInterface('interface'),
  isFinal('final');

  final String jsonName;
  const ApiClassModifier(this.jsonName);

  static ApiClassModifier parse(String value) =>
      values.firstWhere((e) => e.jsonName == value);
}

/// A canonical summary of the public API of a package.
///
/// This serves as the root model object containing the [name] of the package
/// and the collection of [libraries] that make up its public API surface.
final class ApiSummary {
  final String name;

  final List<ApiLibrary> libraries;

  ApiSummary({required this.name, required this.libraries});

  factory ApiSummary.fromJson(Map<String, dynamic> json) => ApiSummary(
    name: json['name'] as String,
    libraries: parseList(json, 'libraries', ApiLibrary.fromJson),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'libraries': libraries.map((e) => e.toJson()).toList(),
  };

  @override
  String toString() => renderTextSummary(this);
}

/// A summary of the declarations exposed by a single library within a package.
final class ApiLibrary {
  final String uri;
  final bool isPublicEntryPoint;
  final List<ApiClass> classes;
  final List<ApiClass> enums;
  final List<ApiClass> mixins;
  final List<ApiExtension> extensions;
  final List<ApiExtensionType> extensionTypes;
  final List<ApiExecutable> functions;
  final List<ApiTypeAlias> typeAliases;

  ApiLibrary({
    required this.uri,
    required this.isPublicEntryPoint,
    required this.classes,
    required this.enums,
    required this.mixins,
    required this.extensions,
    required this.extensionTypes,
    required this.functions,
    required this.typeAliases,
  });

  factory ApiLibrary.fromJson(Map<String, dynamic> json) => ApiLibrary(
    uri: json['uri'] as String,
    isPublicEntryPoint: json['isPublicEntryPoint'] as bool,
    classes: parseList(json, 'classes', ApiClass.fromJson),
    enums: parseList(json, 'enums', ApiClass.fromJson),
    mixins: parseList(json, 'mixins', ApiClass.fromJson),
    extensions: parseList(json, 'extensions', ApiExtension.fromJson),
    extensionTypes: parseList(
      json,
      'extensionTypes',
      ApiExtensionType.fromJson,
    ),
    functions: parseList(json, 'functions', ApiExecutable.fromJson),
    typeAliases: parseList(json, 'typeAliases', ApiTypeAlias.fromJson),
  );

  Map<String, dynamic> toJson() => {
    'uri': uri,
    'isPublicEntryPoint': isPublicEntryPoint,
    if (classes.isNotEmpty) 'classes': classes.map((e) => e.toJson()).toList(),
    if (enums.isNotEmpty) 'enums': enums.map((e) => e.toJson()).toList(),
    if (mixins.isNotEmpty) 'mixins': mixins.map((e) => e.toJson()).toList(),
    if (extensions.isNotEmpty)
      'extensions': extensions.map((e) => e.toJson()).toList(),
    if (extensionTypes.isNotEmpty)
      'extensionTypes': extensionTypes.map((e) => e.toJson()).toList(),
    if (functions.isNotEmpty)
      'functions': functions.map((e) => e.toJson()).toList(),
    if (typeAliases.isNotEmpty)
      'typeAliases': typeAliases.map((e) => e.toJson()).toList(),
  };
}

/// The base class for all API declarations (classes, extensions, methods,
/// aliases) modeled in a package summary.
sealed class ApiDeclaration {
  final String name;
  final String? locationUri;
  final ApiDeclarationStatus status;
  final bool isDeprecated;
  final bool isExperimental;
  final bool isVisibleForTesting;

  const ApiDeclaration({
    required this.name,
    this.locationUri,
    this.status = ApiDeclarationStatus.public,
    this.isDeprecated = false,
    this.isExperimental = false,
    this.isVisibleForTesting = false,
  });
}

/// A summary of a Dart class, mixin, or enum declaration.
///
/// Models class modifiers, constructors, methods, type parameters, hierarchy
/// relationships, deprecation status, and other element metadata.
final class ApiClass extends ApiDeclaration {
  final Map<String, ApiType?> typeParameters;
  final ApiType? supertype;
  final List<ApiType> interfaces;
  final List<ApiType> mixins;
  final List<ApiType> superclassConstraints;
  final List<ApiClassModifier> modifiers;
  final List<String> immediateSubtypes;
  final List<ApiExecutable> constructors;
  final List<ApiExecutable> methods;

  ApiClass({
    required super.name,
    super.locationUri,
    super.status,
    required this.typeParameters,
    this.supertype,
    required this.interfaces,
    required this.mixins,
    this.superclassConstraints = const [],
    required this.modifiers,
    required this.immediateSubtypes,
    required this.constructors,
    required this.methods,
    super.isDeprecated,
    super.isExperimental,
    super.isVisibleForTesting,
  });

  factory ApiClass.fromJson(Map<String, dynamic> json) => ApiClass(
    name: json['name'] as String,
    locationUri: json['locationUri'] as String?,
    status: _parseStatus(json),
    typeParameters: parseTypeParameters(json, 'typeParameters'),
    supertype: json['supertype'] != null
        ? ApiType.fromJson(json['supertype'] as Map<String, dynamic>)
        : null,
    interfaces: parseList(json, 'interfaces', ApiType.fromJson),
    mixins: parseList(json, 'mixins', ApiType.fromJson),
    superclassConstraints: parseList(
      json,
      'superclassConstraints',
      ApiType.fromJson,
    ),
    modifiers: parseStringList(
      json,
      'modifiers',
    ).map(ApiClassModifier.parse).toList(),
    immediateSubtypes: parseStringList(json, 'immediateSubtypes'),
    constructors: parseList(json, 'constructors', ApiExecutable.fromJson),
    methods: parseList(json, 'methods', ApiExecutable.fromJson),
    isDeprecated: json['isDeprecated'] as bool? ?? false,
    isExperimental: json['isExperimental'] as bool? ?? false,
    isVisibleForTesting: json['isVisibleForTesting'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (locationUri != null) 'locationUri': locationUri,
    if (status != ApiDeclarationStatus.public) 'status': status.name,
    if (typeParameters.isNotEmpty)
      'typeParameters': {
        for (final entry in typeParameters.entries)
          entry.key: entry.value?.toJson(),
      },
    if (supertype != null) 'supertype': supertype!.toJson(),
    if (interfaces.isNotEmpty)
      'interfaces': interfaces.map((e) => e.toJson()).toList(),
    if (mixins.isNotEmpty) 'mixins': mixins.map((e) => e.toJson()).toList(),
    if (superclassConstraints.isNotEmpty)
      'superclassConstraints': superclassConstraints
          .map((e) => e.toJson())
          .toList(),
    if (modifiers.isNotEmpty)
      'modifiers': modifiers.map((e) => e.jsonName).toList(),
    if (immediateSubtypes.isNotEmpty) 'immediateSubtypes': immediateSubtypes,
    if (constructors.isNotEmpty)
      'constructors': constructors.map((e) => e.toJson()).toList(),
    if (methods.isNotEmpty) 'methods': methods.map((e) => e.toJson()).toList(),
    if (isDeprecated) 'isDeprecated': isDeprecated,
    if (isExperimental) 'isExperimental': isExperimental,
    if (isVisibleForTesting) 'isVisibleForTesting': isVisibleForTesting,
  };
}

/// A summary of a Dart extension declaration.
///
/// Models type parameters, the extended type, and extension methods.
final class ApiExtension extends ApiDeclaration {
  final Map<String, ApiType?> typeParameters;
  final ApiType extendedType;
  final List<ApiExecutable> methods;

  ApiExtension({
    required super.name,
    super.locationUri,
    super.status,
    required this.typeParameters,
    required this.extendedType,
    required this.methods,
    super.isDeprecated,
    super.isExperimental,
    super.isVisibleForTesting,
  });

  factory ApiExtension.fromJson(Map<String, dynamic> json) => ApiExtension(
    name: json['name'] as String,
    locationUri: json['locationUri'] as String?,
    status: _parseStatus(json),
    typeParameters: parseTypeParameters(json, 'typeParameters'),
    extendedType: ApiType.fromJson(
      json['extendedType'] as Map<String, dynamic>,
    ),
    methods: parseList(json, 'methods', ApiExecutable.fromJson),
    isDeprecated: json['isDeprecated'] as bool? ?? false,
    isExperimental: json['isExperimental'] as bool? ?? false,
    isVisibleForTesting: json['isVisibleForTesting'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (locationUri != null) 'locationUri': locationUri,
    if (status != ApiDeclarationStatus.public) 'status': status.name,
    if (typeParameters.isNotEmpty)
      'typeParameters': {
        for (final entry in typeParameters.entries)
          entry.key: entry.value?.toJson(),
      },
    'extendedType': extendedType.toJson(),
    if (methods.isNotEmpty) 'methods': methods.map((e) => e.toJson()).toList(),
    if (isDeprecated) 'isDeprecated': isDeprecated,
    if (isExperimental) 'isExperimental': isExperimental,
    if (isVisibleForTesting) 'isVisibleForTesting': isVisibleForTesting,
  };
}

/// A summary of a Dart extension type declaration.
///
/// Models the representation type, implemented interfaces, and defined constructors/methods.
final class ApiExtensionType extends ApiDeclaration {
  final Map<String, ApiType?> typeParameters;
  final ApiType representationType;
  final List<ApiType> interfaces;
  final List<ApiExecutable> constructors;
  final List<ApiExecutable> methods;

  ApiExtensionType({
    required super.name,
    super.locationUri,
    super.status,
    required this.typeParameters,
    required this.representationType,
    required this.interfaces,
    required this.constructors,
    required this.methods,
    super.isDeprecated,
    super.isExperimental,
    super.isVisibleForTesting,
  });

  factory ApiExtensionType.fromJson(Map<String, dynamic> json) =>
      ApiExtensionType(
        name: json['name'] as String,
        locationUri: json['locationUri'] as String?,
        status: _parseStatus(json),
        typeParameters: parseTypeParameters(json, 'typeParameters'),
        representationType: ApiType.fromJson(
          json['representationType'] as Map<String, dynamic>,
        ),
        interfaces: parseList(json, 'interfaces', ApiType.fromJson),
        constructors: parseList(json, 'constructors', ApiExecutable.fromJson),
        methods: parseList(json, 'methods', ApiExecutable.fromJson),
        isDeprecated: json['isDeprecated'] as bool? ?? false,
        isExperimental: json['isExperimental'] as bool? ?? false,
        isVisibleForTesting: json['isVisibleForTesting'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (locationUri != null) 'locationUri': locationUri,
    if (status != ApiDeclarationStatus.public) 'status': status.name,
    if (typeParameters.isNotEmpty)
      'typeParameters': {
        for (final entry in typeParameters.entries)
          entry.key: entry.value?.toJson(),
      },
    'representationType': representationType.toJson(),
    if (interfaces.isNotEmpty)
      'interfaces': interfaces.map((e) => e.toJson()).toList(),
    if (constructors.isNotEmpty)
      'constructors': constructors.map((e) => e.toJson()).toList(),
    if (methods.isNotEmpty) 'methods': methods.map((e) => e.toJson()).toList(),
    if (isDeprecated) 'isDeprecated': isDeprecated,
    if (isExperimental) 'isExperimental': isExperimental,
    if (isVisibleForTesting) 'isVisibleForTesting': isVisibleForTesting,
  };
}

/// A summary of an executable member (function, method, constructor, getter,
/// or setter).
///
/// Models signature details such as parameters, return type, type parameters,
/// and modifiers.
final class ApiExecutable extends ApiDeclaration {
  final ApiExecutableKind kind;
  final Map<String, ApiType?> typeParameters;
  final ApiType returnType;
  final List<ApiParameter> parameters;
  final bool isStatic;

  ApiExecutable({
    required super.name,
    super.locationUri,
    super.status,
    required this.kind,
    required this.typeParameters,
    required this.returnType,
    required this.parameters,
    required this.isStatic,
    super.isDeprecated,
    super.isExperimental,
    super.isVisibleForTesting,
  });

  factory ApiExecutable.fromJson(Map<String, dynamic> json) => ApiExecutable(
    name: json['name'] as String,
    locationUri: json['locationUri'] as String?,
    status: _parseStatus(json),
    kind: ApiExecutableKind.values.byName(
      json['kind'] as String? ?? 'function',
    ),
    typeParameters: parseTypeParameters(json, 'typeParameters'),
    returnType: ApiType.fromJson(json['returnType'] as Map<String, dynamic>),
    parameters: parseList(json, 'parameters', ApiParameter.fromJson),
    isStatic: json['isStatic'] as bool? ?? false,
    isDeprecated: json['isDeprecated'] as bool? ?? false,
    isExperimental: json['isExperimental'] as bool? ?? false,
    isVisibleForTesting: json['isVisibleForTesting'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (locationUri != null) 'locationUri': locationUri,
    if (status != ApiDeclarationStatus.public) 'status': status.name,
    'kind': kind.name,
    if (typeParameters.isNotEmpty)
      'typeParameters': {
        for (final entry in typeParameters.entries)
          entry.key: entry.value?.toJson(),
      },
    'returnType': returnType.toJson(),
    if (parameters.isNotEmpty)
      'parameters': parameters.map((e) => e.toJson()).toList(),
    if (isStatic) 'isStatic': isStatic,
    if (isDeprecated) 'isDeprecated': isDeprecated,
    if (isExperimental) 'isExperimental': isExperimental,
    if (isVisibleForTesting) 'isVisibleForTesting': isVisibleForTesting,
  };
}

/// A summary of a Dart typedef type alias declaration.
///
/// Models type parameters and the aliased target type.
final class ApiTypeAlias extends ApiDeclaration {
  final Map<String, ApiType?> typeParameters;
  final ApiType aliasedType;

  ApiTypeAlias({
    required super.name,
    super.locationUri,
    super.status,
    required this.typeParameters,
    required this.aliasedType,
    super.isDeprecated,
    super.isExperimental,
    super.isVisibleForTesting,
  });

  factory ApiTypeAlias.fromJson(Map<String, dynamic> json) => ApiTypeAlias(
    name: json['name'] as String,
    locationUri: json['locationUri'] as String?,
    status: _parseStatus(json),
    typeParameters: parseTypeParameters(json, 'typeParameters'),
    aliasedType: ApiType.fromJson(json['aliasedType'] as Map<String, dynamic>),
    isDeprecated: json['isDeprecated'] as bool? ?? false,
    isExperimental: json['isExperimental'] as bool? ?? false,
    isVisibleForTesting: json['isVisibleForTesting'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (locationUri != null) 'locationUri': locationUri,
    if (status != ApiDeclarationStatus.public) 'status': status.name,
    if (typeParameters.isNotEmpty)
      'typeParameters': {
        for (final entry in typeParameters.entries)
          entry.key: entry.value?.toJson(),
      },
    'aliasedType': aliasedType.toJson(),
    if (isDeprecated) 'isDeprecated': isDeprecated,
    if (isExperimental) 'isExperimental': isExperimental,
    if (isVisibleForTesting) 'isVisibleForTesting': isVisibleForTesting,
  };
}

ApiDeclarationStatus _parseStatus(Map<String, dynamic> json) =>
    ApiDeclarationStatus.values.byName(json['status'] as String? ?? 'public');
