import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart _jsonl_bulk_parser.dart <file.jsonl.gz>');
    exit(1);
  }

  final file = File(args[0]);
  if (!file.existsSync()) {
    stderr.writeln('File not found: ${args[0]}');
    exit(1);
  }

  final lines = file
      .openRead()
      .transform(gzip.decoder)
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (final line in lines) {
    if (line.trim().isEmpty) continue;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(line) as Map<String, dynamic>;
    } catch (e) {
      stderr.writeln('Failed to decode line: $e');
      continue;
    }

    final yamlString = data['contents'] as String?;
    if (yamlString == null) continue;

    Object? parsedJson;
    String? exception;

    try {
      // Parse YAML. We convert to JSON-compatible structures
      // so it can be serialized back to JSON.
      final doc = loadYamlNode(yamlString);
      parsedJson = _toJson(doc);
    } catch (e) {
      exception = e.toString();
    }

    final result = {
      'package': data['package'],
      'version': data['version'],
      'file': data['file'],
      'yaml': yamlString,
      'json': parsedJson,
      'exception': exception,
    };

    stdout.writeln(jsonEncode(result));
  }
}

Object? _toJson(YamlNode node) {
  if (node is YamlMap) {
    final map = <String, Object?>{};
    for (final entry in node.nodes.entries) {
      final keyNode = entry.key;
      final key = keyNode is YamlNode ? _toJson(keyNode) : keyNode;
      final keyStr = key is String ? key : jsonEncode(key);
      map[keyStr] = _toJson(entry.value);
    }
    return map;
  } else if (node is YamlList) {
    return node.nodes.map(_toJson).toList();
  } else if (node is YamlScalar) {
    final val = node.value;
    if (val is double) {
      if (val.isNaN) return '.nan';
      if (val.isInfinite) return val < 0 ? '-.inf' : '.inf';
    }
    if (val is String || val is num || val is bool || val == null) {
      return val;
    }
    return val.toString();
  }
  return null;
}
