// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

enum _Kind {
  isDynamic('dynamic', ApiDynamicType.fromJson),
  isVoid('void', ApiVoidType.fromJson),
  typeParameter('typeParameter', ApiTypeParameterType.fromJson),
  interface('interface', ApiInterfaceType.fromJson),
  record('record', ApiRecordType.fromJson),
  function('function', ApiFunctionType.fromJson);

  final String jsonName;
  final ApiType Function(Map<String, dynamic>) fromJson;
  const _Kind(this.jsonName, this.fromJson);

  static _Kind parse(String value) => values.firstWhere(
    (e) => e.jsonName == value,
    orElse: () => throw ArgumentError('Unknown ApiType kind: $value'),
  );
}

/// The base class for all types represented in an API summary.
///
/// This sealed hierarchy models the various Dart types (dynamic, void,
/// function, interface, record, and type parameter) encountered in package
/// public APIs.
sealed class ApiType {
  Map<String, dynamic> toJson();
  factory ApiType.fromJson(Map<String, dynamic> json) =>
      _Kind.parse(json['kind'] as String).fromJson(json);
}

/// Represents the `dynamic` type in Dart.
final class ApiDynamicType implements ApiType {
  const ApiDynamicType();
  factory ApiDynamicType.fromJson(Map<String, dynamic> _) =>
      const ApiDynamicType();
  @override
  Map<String, dynamic> toJson() => {'kind': _Kind.isDynamic.jsonName};
}

/// Represents the `void` type in Dart.
final class ApiVoidType implements ApiType {
  const ApiVoidType();
  factory ApiVoidType.fromJson(Map<String, dynamic> _) => const ApiVoidType();
  @override
  Map<String, dynamic> toJson() => {'kind': _Kind.isVoid.jsonName};
}

/// Represents a type parameter type (e.g. `T`) in Dart.
final class ApiTypeParameterType implements ApiType {
  final String name;
  final bool isNullable;

  ApiTypeParameterType({required this.name, required this.isNullable});

  factory ApiTypeParameterType.fromJson(Map<String, dynamic> json) =>
      ApiTypeParameterType(
        name: json['name'] as String,
        isNullable: json['isNullable'] as bool? ?? false,
      );

  @override
  Map<String, dynamic> toJson() => {
    'kind': _Kind.typeParameter.jsonName,
    'name': name,
    if (isNullable) 'isNullable': true,
  };
}

/// Represents an interface type (a class, mixin, or enum type) in Dart.
///
/// Models name, defining library URI, and type arguments.
final class ApiInterfaceType implements ApiType {
  final String name;
  final String? libraryUri;
  final List<ApiType> typeArguments;
  final bool isNullable;

  ApiInterfaceType({
    required this.name,
    this.libraryUri,
    required this.typeArguments,
    required this.isNullable,
  });

  factory ApiInterfaceType.fromJson(Map<String, dynamic> json) =>
      ApiInterfaceType(
        name: json['name'] as String,
        libraryUri: json['libraryUri'] as String?,
        typeArguments: _parseList(json, 'typeArguments', ApiType.fromJson),
        isNullable: json['isNullable'] as bool? ?? false,
      );

  @override
  Map<String, dynamic> toJson() => {
    'kind': _Kind.interface.jsonName,
    'name': name,
    if (libraryUri != null) 'libraryUri': libraryUri,
    if (typeArguments.isNotEmpty)
      'typeArguments': typeArguments.map((e) => e.toJson()).toList(),
    if (isNullable) 'isNullable': true,
  };
}

/// Represents a named field within a record type (e.g. `foo` in `({int foo})`).
final class ApiRecordNamedField {
  final String name;
  final ApiType type;

  ApiRecordNamedField({required this.name, required this.type});

  factory ApiRecordNamedField.fromJson(Map<String, dynamic> json) =>
      ApiRecordNamedField(
        name: json['name'] as String,
        type: ApiType.fromJson(json['type'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {'name': name, 'type': type.toJson()};
}

/// Represents a record type in Dart (e.g. `(int, {String foo})`).
final class ApiRecordType implements ApiType {
  final List<ApiType> positionalFields;
  final List<ApiRecordNamedField> namedFields;
  final bool isNullable;

  ApiRecordType({
    required this.positionalFields,
    required this.namedFields,
    required this.isNullable,
  });

  factory ApiRecordType.fromJson(Map<String, dynamic> json) => ApiRecordType(
    positionalFields: _parseList(json, 'positionalFields', ApiType.fromJson),
    namedFields: _parseList(json, 'namedFields', ApiRecordNamedField.fromJson),
    isNullable: json['isNullable'] as bool? ?? false,
  );

  @override
  Map<String, dynamic> toJson() => {
    'kind': _Kind.record.jsonName,
    if (positionalFields.isNotEmpty)
      'positionalFields': positionalFields.map((e) => e.toJson()).toList(),
    if (namedFields.isNotEmpty)
      'namedFields': namedFields.map((e) => e.toJson()).toList(),
    if (isNullable) 'isNullable': true,
  };
}

/// Represents a function type in Dart (e.g. `void Function(int)`).
final class ApiFunctionType implements ApiType {
  final ApiType returnType;
  final List<String> typeParameters;
  final List<ApiType> typeParameterBounds;
  final List<ApiParameter> parameters;
  final bool isNullable;

  ApiFunctionType({
    required this.returnType,
    required this.typeParameters,
    this.typeParameterBounds = const [],
    required this.parameters,
    required this.isNullable,
  });

  factory ApiFunctionType.fromJson(Map<String, dynamic> json) =>
      ApiFunctionType(
        returnType: ApiType.fromJson(
          json['returnType'] as Map<String, dynamic>,
        ),
        typeParameters: _parseStringList(json, 'typeParameters'),
        typeParameterBounds: _parseList(
          json,
          'typeParameterBounds',
          ApiType.fromJson,
        ),
        parameters: _parseList(json, 'parameters', ApiParameter.fromJson),
        isNullable: json['isNullable'] as bool? ?? false,
      );

  @override
  Map<String, dynamic> toJson() => {
    'kind': _Kind.function.jsonName,
    'returnType': returnType.toJson(),
    if (typeParameters.isNotEmpty) 'typeParameters': typeParameters,
    if (typeParameterBounds.isNotEmpty)
      'typeParameterBounds': typeParameterBounds
          .map((e) => e.toJson())
          .toList(),
    if (parameters.isNotEmpty)
      'parameters': parameters.map((e) => e.toJson()).toList(),
    if (isNullable) 'isNullable': true,
  };
}

List<T> _parseList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) =>
    (json[key] as List<dynamic>?)
        ?.map((e) => fromJson(e as Map<String, dynamic>))
        .toList() ??
    [];

List<String> _parseStringList(Map<String, dynamic> json, String key) =>
    (json[key] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];

/// Represents a parameter in a function or method signature.
///
/// Models parameter name, type, and optional/required/named status.
final class ApiParameter {
  final String name;
  final ApiType type;
  final bool isRequired;
  final bool isNamed;
  final bool isOptionalPositional;
  final bool isDeprecated;

  ApiParameter({
    required this.name,
    required this.type,
    required this.isRequired,
    required this.isNamed,
    required this.isOptionalPositional,
    required this.isDeprecated,
  });

  factory ApiParameter.fromJson(Map<String, dynamic> json) => ApiParameter(
    name: json['name'] as String,
    type: ApiType.fromJson(json['type'] as Map<String, dynamic>),
    isRequired: json['isRequired'] as bool? ?? false,
    isNamed: json['isNamed'] as bool? ?? false,
    isOptionalPositional: json['isOptionalPositional'] as bool? ?? false,
    isDeprecated: json['isDeprecated'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.toJson(),
    if (isRequired) 'isRequired': isRequired,
    if (isNamed) 'isNamed': isNamed,
    if (isOptionalPositional) 'isOptionalPositional': isOptionalPositional,
    if (isDeprecated) 'isDeprecated': isDeprecated,
  };
}
