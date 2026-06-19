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
import 'src/text_renderer.dart';

export 'src/api_declaration.dart' hide apiSummaryRenderer;
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
  apiSummaryRenderer ??= renderTextSummary;
  final resolvedPackageName = packageName ?? _extractPackageName(packagePath);
  final provider = PhysicalResourceProvider.INSTANCE;
  final libPath = provider.pathContext.join(packagePath, 'lib');
  final collection = AnalysisContextCollection(
    resourceProvider: provider,
    includedPaths: [libPath],
  );
  final context = collection.contextFor(libPath);
  return buildApiPackage(
    resolvedPackageName,
    context,
    customizer ?? const ApiSummaryCustomizer(),
  );
}

String _extractPackageName(String packagePath) {
  final pubspecFile = File(p.join(packagePath, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    throw ArgumentError('No pubspec.yaml found at "$packagePath".');
  }
  final content = pubspecFile.readAsStringSync();
  final yaml = loadYaml(content);
  if (yaml case {'name': final String name}) {
    return name;
  }
  if (yaml is! Map) {
    throw ArgumentError(
      'Expected pubspec.yaml at ${pubspecFile.path} to be a YAML map.',
    );
  }
  if (yaml['name'] == null) {
    throw ArgumentError(
      'Could not find a "name" field in pubspec.yaml at ${pubspecFile.path}.',
    );
  }
  throw ArgumentError(
    'The "name" field in pubspec.yaml at ${pubspecFile.path} must be a '
    'string.',
  );
}
