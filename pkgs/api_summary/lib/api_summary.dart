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
export 'src/api_summary_customizer.dart'
    show ApiSummaryContext, ApiSummaryCustomizer;
export 'src/api_type.dart';

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
    final parsed = loadYaml(content, sourceUrl: pubspecFile.uri);
    if (parsed case final YamlMap map) {
      yaml = map;
    } else {
      throw Exception('Expected pubspec to be a YAML map.');
    }
  } on Exception catch (e) {
    throw ArgumentError(
      'Failed to parse pubspec.yaml at ${pubspecFile.path}: $e',
    );
  }

  final String name;
  if (yaml['name'] case final String parsedName) {
    name = parsedName;
  } else {
    throw ArgumentError(
      'Failed to parse pubspec.yaml at ${pubspecFile.path}: '
      'Expected pubspec to contain a "name" string.',
    );
  }

  final Map<String, String> environment;
  if (yaml['environment'] case final Map<dynamic, dynamic> envMap) {
    environment = {
      for (final MapEntry(:key, :value) in envMap.entries)
        if (key case final String k when value != null) k: value.toString(),
    };
  } else if (yaml['environment'] == null) {
    environment = const {};
  } else {
    throw ArgumentError(
      'Failed to parse pubspec.yaml at ${pubspecFile.path}: '
      'Expected "environment" to be a YAML map.',
    );
  }

  final Map<String, String?> executables;
  if (yaml['executables'] case final Map<dynamic, dynamic> execMap) {
    executables = {
      for (final MapEntry(:key, :value) in execMap.entries)
        if (key case final String k)
          k: switch (value) {
            final String s => s,
            null => null,
            _ => throw ArgumentError(
              'Failed to parse pubspec.yaml at ${pubspecFile.path}: '
              'Expected executable target for "$k" to be a string or null.',
            ),
          },
    };
  } else if (yaml['executables'] == null) {
    executables = const {};
  } else {
    throw ArgumentError(
      'Failed to parse pubspec.yaml at ${pubspecFile.path}: '
      'Expected "executables" to be a YAML map.',
    );
  }

  return (name: name, environment: environment, executables: executables);
}
