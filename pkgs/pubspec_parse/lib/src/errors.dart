// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

ParsedYamlException parsedYamlException(String message, YamlNode yamlNode) =>
    ParsedYamlException._(message, yamlNode);

ParsedYamlException parsedYamlExceptionFromError(
    CheckedFromJsonException error, StackTrace stack) {
  final innerError = error.innerError;
  if (innerError is UnrecognizedKeysException) {
    final map = innerError.map;
    if (map is YamlMap) {
      // if the associated key exists, use that as the error node,
      // otherwise use the map itself
      final node = map.nodes.keys.cast<YamlNode>().firstWhere((key) {
        return innerError.unrecognizedKeys.contains(key.value);
      }, orElse: () => map);

      return ParsedYamlException._(innerError.message, node,
          innerError: error, innerStack: stack);
    }
  } else if (innerError is ParsedYamlException) {
    return innerError;
  }

  final yamlMap = error.map as YamlMap;
  var yamlNode = yamlMap.nodes[error.key];

  String message;
  if (yamlNode == null) {
    assert(error.message != null);
    message = error.message;
    yamlNode = yamlMap;
  } else {
    if (error.message == null) {
      message = 'Unsupported value for `${error.key}`.';
    } else {
      message = error.message.toString();
    }
  }

  return ParsedYamlException._(message, yamlNode,
      innerError: error, innerStack: stack);
}

/// Thrown when parsing a YAML document fails.
class ParsedYamlException implements Exception {
  /// Describes the nature of the parse failure.
  final String message;

  final YamlNode yamlNode;

  /// If this exception was thrown as a result of another error,
  /// contains the source error object.
  final Object innerError;

  /// If this exception was thrown as a result of another error,
  /// contains the corresponding [StackTrace].
  final StackTrace innerStack;

  ParsedYamlException._(this.message, this.yamlNode,
      {this.innerError, this.innerStack});

  /// Returns [message] formatted with source information provided by
  /// [yamlNode].
  String get formattedMessage => yamlNode.span.message(message);

  @override
  String toString() => message;
}
