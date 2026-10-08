// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:cli_util/cli_util.dart' show sdkPath;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'src/api_builder.dart';
import 'src/api_declaration.dart';
import 'src/api_summary_customizer.dart';
export 'src/api_declaration.dart';
export 'src/api_facet.dart';
export 'src/api_summary_customizer.dart'
    show ApiSummaryContext, ApiSummaryCustomizer;
export 'src/api_type.dart';
export 'src/js_facet.dart';
export 'src/meta_facet.dart';
export 'src/verify.dart'
    show
        ApiSummaryFormat,
        ApiSummaryVerificationException,
        expectApiSummaryClean;

/// Creates a canonical [ApiSummary] model of the public API of a package.
///
/// [packagePath] is the path to the directory containing the package's
/// `pubspec.yaml` file.
///
/// [packageName] is the name of the package, or extracted from `pubspec.yaml`
/// if omitted.
///
/// If [customizer] is provided, it will be used to customize the behavior of
/// the tool.
Future<ApiSummary> apiSummary(
  String packagePath, {
  String? packageName,
  ApiSummaryCustomizer? customizer,
}) async {
  final resolvedPackagePath = p.normalize(p.absolute(packagePath));
  final pubspec = _extractPubspecDetails(resolvedPackagePath);
  final resolvedPackageName = packageName ?? pubspec.name;
  final provider = PhysicalResourceProvider.INSTANCE;
  final libPath = provider.pathContext.join(resolvedPackagePath, 'lib');
  if (!provider.getFolder(libPath).exists) {
    throw ArgumentError('No "lib" directory found for "$packagePath".');
  }
  final collection = AnalysisContextCollection(
    resourceProvider: provider,
    includedPaths: [libPath],
    sdkPath: sdkPath,
  );
  final context = collection.contextFor(libPath);
  return buildApiPackage(
    resolvedPackageName,
    context,
    customizer ?? const ApiSummaryCustomizer(),
    environment: pubspec.environment,
    dependencies: pubspec.dependencies,
    executables: pubspec.executables,
  );
}

typedef _PubspecDetails = ({
  String name,
  Map<String, String> environment,
  Map<String, String> dependencies,
  Map<String, String?> executables,
});

_PubspecDetails _extractPubspecDetails(String packagePath) {
  final pubspecFile = File(p.join(packagePath, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    throw ArgumentError('No pubspec.yaml found at "$packagePath".');
  }
  final content = pubspecFile.readAsStringSync();
  final YamlMap yaml;
  try {
    yaml = switch (loadYaml(content, sourceUrl: pubspecFile.uri)) {
      final YamlMap map => map,
      _ => throw FormatException('Expected pubspec to be a YAML map.', content),
    };
  } on FormatException catch (e) {
    throw FormatException(
      'Failed to parse pubspec.yaml at ${pubspecFile.path}: ${e.message}',
      content,
      e.offset,
    );
  }

  final name = switch (yaml['name']) {
    final String name => name,
    _ => throw FormatException(
      'Failed to parse pubspec.yaml at ${pubspecFile.path}: '
      'Expected pubspec to contain a "name" string.',
      content,
    ),
  };

  return (
    name: name,
    environment: _parseEnvironment(
      yaml['environment'],
      pubspecFile.path,
      content,
    ),
    dependencies: _parseDependencies(
      yaml['dependencies'],
      pubspecFile.path,
      content,
    ),
    executables: _parseExecutables(
      yaml['executables'],
      pubspecFile.path,
      content,
    ),
  );
}

String _normalizeVersionConstraint(String raw) {
  try {
    final constraint = VersionConstraint.parse(raw);
    if (constraint case VersionRange(
      :final min?,
      includeMin: true,
    ) when constraint == VersionConstraint.compatibleWith(min)) {
      return '^$min';
    }
    return constraint.toString();
  } on FormatException {
    return raw.trim();
  }
}

Map<String, String> _parseEnvironment(
  Object? raw,
  String pubspecPath,
  String content,
) => switch (raw) {
  final Map<dynamic, dynamic> envMap => {
    for (final MapEntry(:key, :value) in envMap.entries)
      if (key is String && value != null)
        key: switch (value) {
          final String s => _normalizeVersionConstraint(s),
          final num n => n.toString(),
          final bool b => b.toString(),
          _ => throw FormatException(
            'Failed to parse pubspec.yaml at $pubspecPath: '
            'Expected environment constraint for "$key" to be a string or '
            'scalar.',
            content,
          ),
        },
  },
  null => const <String, String>{},
  _ => throw FormatException(
    'Failed to parse pubspec.yaml at $pubspecPath: '
    'Expected "environment" to be a YAML map.',
    content,
  ),
};

Map<String, String> _parseDependencies(
  Object? raw,
  String pubspecPath,
  String content,
) => switch (raw) {
  final Map<dynamic, dynamic> depMap => {
    for (final MapEntry(:key, :value) in depMap.entries)
      if (key is String)
        key: _formatDependencyValue(key, value, pubspecPath, content),
  },
  null => const <String, String>{},
  _ => throw FormatException(
    'Failed to parse pubspec.yaml at $pubspecPath: '
    'Expected "dependencies" to be a YAML map.',
    content,
  ),
};

String _formatDependencyValue(
  String key,
  Object? value,
  String pubspecPath,
  String content,
) => switch (value) {
  null => 'any',
  final String s => _normalizeVersionConstraint(s),
  final num n => n.toString(),
  final bool b => b.toString(),
  final Map<dynamic, dynamic> map => _formatYamlMap(
    map,
    key,
    pubspecPath,
    content,
  ),
  _ => throw FormatException(
    'Failed to parse pubspec.yaml at $pubspecPath: '
    'Expected dependency constraint for "$key" to be a string, null, or map.',
    content,
  ),
};

String _formatYamlMap(
  Map<dynamic, dynamic> map,
  String depKey,
  String pubspecPath,
  String content,
) {
  final entries = <MapEntry<String, String>>[];
  for (final MapEntry(:key, :value) in map.entries) {
    if (key is! String) continue;
    final formattedValue = switch (value) {
      null => 'null',
      final String s => key == 'version' ? _normalizeVersionConstraint(s) : s,
      final num n => n.toString(),
      final bool b => b.toString(),
      final Map<dynamic, dynamic> nested => _formatYamlMap(
        nested,
        depKey,
        pubspecPath,
        content,
      ),
      _ => throw FormatException(
        'Failed to parse pubspec.yaml at $pubspecPath: '
        'Unsupported nested value in dependency "$depKey".',
        content,
      ),
    };
    entries.add(MapEntry(key, formattedValue));
  }
  entries.sort((a, b) => a.key.compareTo(b.key));
  final inner = entries.map((e) => '${e.key}: ${e.value}').join(', ');
  return '{$inner}';
}

Map<String, String?> _parseExecutables(
  Object? raw,
  String pubspecPath,
  String content,
) => switch (raw) {
  final Map<dynamic, dynamic> execMap => {
    for (final MapEntry(:key, :value) in execMap.entries)
      if (key is String)
        key: switch (value) {
          final String? s => s,
          _ => throw FormatException(
            'Failed to parse pubspec.yaml at $pubspecPath: '
            'Expected executable target for "$key" to be a string or null.',
            content,
          ),
        },
  },
  null => const <String, String?>{},
  _ => throw FormatException(
    'Failed to parse pubspec.yaml at $pubspecPath: '
    'Expected "executables" to be a YAML map.',
    content,
  ),
};
