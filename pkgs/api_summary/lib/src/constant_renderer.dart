// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';

/// Extracts the canonical string representation of [parameter]'s default value,
/// or returns `null` if [parameter] has no default value, its default value is
/// `null`, or its default value references non-public implementation details.
String? extractParameterDefaultValue(FormalParameterElement parameter) {
  if (parameter.isRequired) return null;
  FormalParameterElement? current = parameter;
  while (current != null && !current.hasDefaultValue) {
    current = switch (current) {
      SuperFormalParameterElement(:final superConstructorParameter) =>
        superConstructorParameter,
      _ => null,
    };
  }
  if (current == null) return null;
  final value =
      current.computeConstantValue() ??
      current.baseElement.computeConstantValue();
  if (value == null || value.isNull) return null;
  return formatConstantObject(value);
}

/// Extracts the canonical string representation of a `const` getter's value,
/// or returns `null` if [element] is not a user-declared `const` variable/field
/// getter, is an enum constant or synthetic enum `values` getter, or its value
/// references non-public implementation details.
String? extractGetterConstantValue(ExecutableElement element) {
  if (element is! GetterElement) return null;
  final variable = element.variable;
  if (!variable.isConst || !variable.isOriginDeclaration) return null;
  if (variable is FieldElement && variable.isEnumConstant) return null;
  final value = variable.computeConstantValue();
  if (value == null) return null;
  return formatConstantObject(value);
}

/// Formats a compile-time constant [object] into a canonical single-line Dart
/// expression, or returns `null` if any part of [object] is unknown or
/// references library-private (`_`) types, constructors, or members.
String? formatConstantObject(DartObject object) {
  if (!object.hasKnownValue) return null;
  if (object.isNull) return 'null';
  if (object.toBoolValue() case final b?) return b.toString();
  if (object.toIntValue() case final i?) return i.toString();
  if (object.toDoubleValue() case final d?) return d.toString();
  if (object.toStringValue() case final s?) return _formatStringLiteral(s);
  if (object.toSymbolValue() case final sym?) {
    return sym.startsWith('_') ? null : '#$sym';
  }
  if (object.toTypeValue() case final type?) return _formatTypeLiteral(type);
  if (object.toListValue() case final list?) {
    return _formatCollection(object.type, list, '[', ']');
  }
  if (object.toSetValue() case final set?) {
    return _formatCollection(object.type, set, '{', '}');
  }
  if (object.toMapValue() case final map?) {
    return _formatMap(object.type, map);
  }
  if (object.toRecordValue() case final record?) {
    return _formatRecord(record.positional, record.named);
  }
  return _formatComplexObject(object);
}

String? _formatComplexObject(DartObject object) {
  if (object.type case InterfaceType(:final EnumElement element)) {
    final enumName = element.name;
    final constantName = object.getField('_name')?.toStringValue();
    if (enumName == null ||
        enumName.startsWith('_') ||
        constantName == null ||
        constantName.startsWith('_')) {
      return null;
    }
    return '$enumName.$constantName';
  }
  if (object.toFunctionValue() case final func?) {
    return _formatFunctionTearOff(func);
  }
  if (object.constructorInvocation case final invocation?) {
    return _formatConstructorInvocation(invocation);
  }
  return null;
}

String _formatStringLiteral(String value) {
  final buffer = StringBuffer("'");
  for (final codeUnit in value.codeUnits) {
    final escaped = switch (codeUnit) {
      0x5C => r'\\',
      0x27 => r"\'",
      0x24 => r'\$',
      0x0A => r'\n',
      0x0D => r'\r',
      0x09 => r'\t',
      0x08 => r'\b',
      0x0C => r'\f',
      0x0B => r'\v',
      < 0x20 || 0x7F => '\\u{${codeUnit.toRadixString(16)}}',
      _ => String.fromCharCode(codeUnit),
    };
    buffer.write(escaped);
  }
  buffer.write("'");
  return buffer.toString();
}

String? _formatTypeLiteral(DartType type) {
  final suffix = type.nullabilitySuffix == NullabilitySuffix.question
      ? '?'
      : '';
  switch (type) {
    case DynamicType():
      return 'dynamic';
    case VoidType():
      return 'void';
    case NeverType():
      return 'Never$suffix';
    case TypeParameterType(:final element):
      final name = element.name;
      return (name == null || name.startsWith('_')) ? null : '$name$suffix';
    case InterfaceType():
      return _formatInterfaceTypeLiteral(type, suffix);
    case RecordType():
      return _formatRecordTypeLiteral(type, suffix);
    case FunctionType():
      return _formatFunctionTypeLiteral(type, suffix);
    default:
      return null;
  }
}

String? _formatInterfaceTypeLiteral(InterfaceType type, String suffix) {
  final name = type.element.name;
  if (name == null || name.startsWith('_')) return null;
  if (type.typeArguments.isEmpty) return '$name$suffix';
  final formattedArgs = <String>[];
  for (final arg in type.typeArguments) {
    final formatted = _formatTypeLiteral(arg);
    if (formatted == null) return null;
    formattedArgs.add(formatted);
  }
  return '$name<${formattedArgs.join(', ')}>$suffix';
}

String? _formatRecordTypeLiteral(RecordType type, String suffix) {
  final parts = <String>[];
  for (final field in type.positionalFields) {
    final formatted = _formatTypeLiteral(field.type);
    if (formatted == null) return null;
    parts.add(formatted);
  }
  final namedParts = <String>[];
  for (final field in type.namedFields.sortedBy((f) => f.name)) {
    if (field.name.startsWith('_')) return null;
    final formatted = _formatTypeLiteral(field.type);
    if (formatted == null) return null;
    namedParts.add('$formatted ${field.name}');
  }
  if (namedParts.isNotEmpty) {
    parts.add('{${namedParts.join(', ')}}');
  }
  if (type.positionalFields.length == 1 && type.namedFields.isEmpty) {
    return '(${parts.single},)$suffix';
  }
  return '(${parts.join(', ')})$suffix';
}

String? _formatFunctionTypeLiteral(FunctionType type, String suffix) {
  final returnTypeStr = _formatTypeLiteral(type.returnType);
  if (returnTypeStr == null) return null;
  final typeParamsStr = _formatTypeParameters(type.typeParameters);
  if (typeParamsStr == null) return null;
  final paramsStr = _formatFunctionParameters(type.formalParameters);
  if (paramsStr == null) return null;
  return '$returnTypeStr Function$typeParamsStr($paramsStr)$suffix';
}

String? _formatTypeParameters(List<TypeParameterElement> typeParameters) {
  if (typeParameters.isEmpty) return '';
  final parts = <String>[];
  for (final param in typeParameters) {
    final name = param.name;
    if (name == null || name.startsWith('_')) return null;
    final bound = param.bound;
    if (bound == null) {
      parts.add(name);
    } else {
      final formattedBound = _formatTypeLiteral(bound);
      if (formattedBound == null) return null;
      parts.add('$name extends $formattedBound');
    }
  }
  return '<${parts.join(', ')}>';
}

String? _formatFunctionParameters(List<FormalParameterElement> parameters) {
  final requiredPos = <String>[];
  final optionalPos = <String>[];
  final named = <MapEntry<String, String>>[];
  for (final param in parameters) {
    final formattedType = _formatTypeLiteral(param.type);
    final name = param.name ?? '';
    if (formattedType == null || (param.isNamed && name.startsWith('_'))) {
      return null;
    }
    if (param.isRequiredPositional) {
      requiredPos.add(formattedType);
    } else if (param.isOptionalPositional) {
      optionalPos.add(formattedType);
    } else if (param.isRequiredNamed) {
      named.add(MapEntry(name, 'required $formattedType $name'));
    } else {
      named.add(MapEntry(name, '$formattedType $name'));
    }
  }
  final groups = <String>[
    ...requiredPos,
    if (optionalPos.isNotEmpty) '[${optionalPos.join(', ')}]',
    if (named.isNotEmpty)
      '{${named.sortedBy((e) => e.key).map((e) => e.value).join(', ')}}',
  ];
  return groups.join(', ');
}

bool _containsPrivateType(DartType? type) => switch (type) {
  InterfaceType(:final element, :final typeArguments) =>
    (element.name?.startsWith('_') ?? false) ||
        typeArguments.any(_containsPrivateType),
  RecordType(:final positionalFields, :final namedFields) =>
    positionalFields.any((f) => _containsPrivateType(f.type)) ||
        namedFields.any((f) => _containsPrivateType(f.type)),
  FunctionType(:final returnType, :final formalParameters) =>
    _containsPrivateType(returnType) ||
        formalParameters.any((p) => _containsPrivateType(p.type)),
  _ => false,
};

String? _formatCollection(
  DartType? type,
  Iterable<DartObject> elements,
  String prefix,
  String suffix,
) {
  if (type is InterfaceType && type.typeArguments.any(_containsPrivateType)) {
    return null;
  }
  final parts = <String>[];
  for (final element in elements) {
    final formatted = formatConstantObject(element);
    if (formatted == null) return null;
    parts.add(formatted);
  }
  return '$prefix${parts.join(', ')}$suffix';
}

String? _formatMap(DartType? type, Map<DartObject?, DartObject?> map) {
  if (type is InterfaceType && type.typeArguments.any(_containsPrivateType)) {
    return null;
  }
  final entries = <String>[];
  for (final MapEntry(:key, :value) in map.entries) {
    if (key == null || value == null) return null;
    final formattedKey = formatConstantObject(key);
    final formattedValue = formatConstantObject(value);
    if (formattedKey == null || formattedValue == null) return null;
    entries.add('$formattedKey: $formattedValue');
  }
  return '{${entries.join(', ')}}';
}

String? _formatRecord(
  List<DartObject> positional,
  Map<String, DartObject> named,
) {
  final parts = <String>[];
  for (final field in positional) {
    final formatted = formatConstantObject(field);
    if (formatted == null) return null;
    parts.add(formatted);
  }
  for (final entry in named.entries.sortedBy((e) => e.key)) {
    if (entry.key.startsWith('_')) return null;
    final formatted = formatConstantObject(entry.value);
    if (formatted == null) return null;
    parts.add('${entry.key}: $formatted');
  }
  if (positional.length == 1 && named.isEmpty) {
    return '(${parts.single},)';
  }
  return '(${parts.join(', ')})';
}

String? _formatFunctionTearOff(ExecutableElement element) {
  switch (element) {
    case TopLevelFunctionElement(:final name?):
      return name.startsWith('_') ? null : name;
    case MethodElement(:final name?, :final enclosingElement)
        when element.isStatic:
      final enclosingName = enclosingElement?.name;
      if (name.startsWith('_') ||
          enclosingName == null ||
          enclosingName.startsWith('_')) {
        return null;
      }
      return '$enclosingName.$name';
    case ConstructorElement(:final name, :final enclosingElement):
      final enclosingName = enclosingElement.name;
      final ctorName = (name == null || name.isEmpty) ? 'new' : name;
      if (ctorName.startsWith('_') ||
          enclosingName == null ||
          enclosingName.startsWith('_')) {
        return null;
      }
      return '$enclosingName.$ctorName';
    default:
      return null;
  }
}

String? _formatConstructorInvocation(ConstructorInvocation invocation) {
  final constructor = invocation.constructor;
  final enclosingName = constructor.enclosingElement.name;
  final ctorName = constructor.name;
  if (enclosingName == null ||
      enclosingName.startsWith('_') ||
      (ctorName != null && ctorName.startsWith('_')) ||
      constructor.returnType.typeArguments.any(_containsPrivateType)) {
    return null;
  }

  final args = <String>[];
  for (final arg in invocation.positionalArguments) {
    final formatted = formatConstantObject(arg);
    if (formatted == null) return null;
    args.add(formatted);
  }
  for (final entry in invocation.namedArguments.entries.sortedBy(
    (e) => e.key,
  )) {
    if (entry.key.startsWith('_')) return null;
    final formatted = formatConstantObject(entry.value);
    if (formatted == null) return null;
    args.add('${entry.key}: $formatted');
  }

  final isUnnamed = ctorName == null || ctorName.isEmpty || ctorName == 'new';
  final target = isUnnamed ? enclosingName : '$enclosingName.$ctorName';
  return '$target(${args.join(', ')})';
}
