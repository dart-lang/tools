// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'src/api_builder.dart';
import 'src/api_declaration.dart';
import 'src/api_summary_customizer.dart';
export 'src/api_declaration.dart';
export 'src/api_facet.dart';
export 'src/api_summary_customizer.dart'
    show ApiSummaryContext, ApiSummaryCustomizer;
export 'src/api_type.dart';
export 'src/meta_facet.dart';

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
  final pubspec = _extractPubspecDetails(packagePath);
  final resolvedPackageName = packageName ?? pubspec.name;
  final provider = PhysicalResourceProvider.INSTANCE;
  final libPath = provider.pathContext.join(packagePath, 'lib');
  if (!provider.getFolder(libPath).exists) {
    throw ArgumentError('No "lib" directory found for "$packagePath".');
  }
  final collection = AnalysisContextCollection(
    resourceProvider: provider,
    includedPaths: [libPath],
  );
  final context = collection.contextFor(libPath);
  return buildApiPackage(
    resolvedPackageName,
    context,
    customizer ?? const ApiSummaryCustomizer(),
    environment: pubspec.environment,
    executables: pubspec.executables,
  );
}

typedef _PubspecDetails = ({
  String name,
  Map<String, String> environment,
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

  final environment = switch (yaml['environment']) {
    final Map<dynamic, dynamic> envMap => {
      for (final MapEntry(:key, :value) in envMap.entries)
        if (key is String && value != null)
          key: switch (value) {
            final String s => s,
            final num n => n.toString(),
            final bool b => b.toString(),
            _ => throw FormatException(
              'Failed to parse pubspec.yaml at ${pubspecFile.path}: '
              'Expected environment constraint for "$key" to be a string or '
              'scalar.',
              content,
            ),
          },
    },
    null => const <String, String>{},
    _ => throw FormatException(
      'Failed to parse pubspec.yaml at ${pubspecFile.path}: '
      'Expected "environment" to be a YAML map.',
      content,
    ),
  };

  final executables = switch (yaml['executables']) {
    final Map<dynamic, dynamic> execMap => {
      for (final MapEntry(:key, :value) in execMap.entries)
        if (key is String)
          key: switch (value) {
            final String? s => s,
            _ => throw FormatException(
              'Failed to parse pubspec.yaml at ${pubspecFile.path}: '
              'Expected executable target for "$key" to be a string or null.',
              content,
            ),
          },
    },
    null => const <String, String?>{},
    _ => throw FormatException(
      'Failed to parse pubspec.yaml at ${pubspecFile.path}: '
      'Expected "executables" to be a YAML map.',
      content,
    ),
  };

  return (name: name, environment: environment, executables: executables);
}
