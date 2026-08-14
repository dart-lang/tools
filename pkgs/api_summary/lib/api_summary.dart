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
    if (parsed is! YamlMap) {
      throw Exception('Expected pubspec to be a YAML map.');
    }
    yaml = parsed;
  } on Exception catch (e) {
    throw ArgumentError(
      'Failed to parse pubspec.yaml at ${pubspecFile.path}: $e',
    );
  }

  final name = yaml['name'];
  if (name is! String) {
    throw ArgumentError(
      'Failed to parse pubspec.yaml at ${pubspecFile.path}: '
      'Expected pubspec to contain a "name" string.',
    );
  }

  final environment = <String, String>{};
  final environmentNode = yaml['environment'];
  if (environmentNode is YamlMap) {
    for (final entry in environmentNode.entries) {
      if (entry.value != null) {
        environment[entry.key as String] = entry.value.toString();
      }
    }
  }

  final executables = <String, String?>{};
  final executablesNode = yaml['executables'];
  if (executablesNode is YamlMap) {
    for (final entry in executablesNode.entries) {
      final value = entry.value;
      executables[entry.key as String] = value is String ? value : null;
    }
  }

  return (name: name, environment: environment, executables: executables);
}
