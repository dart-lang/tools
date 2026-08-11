// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
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

/// Canonicalizes a version constraint string.
///
/// If [rawConstraint] represents a range equivalent to `^version` (such as
/// `>=1.2.3 <2.0.0`, `>=1.2.3 <2.0.0-0`, or `>=0.1.2 <0.2.0`), it is formatted
/// in canonical `^` syntax.
String canonicalizeConstraint(String rawConstraint) {
  final VersionConstraint constraint;
  try {
    constraint = VersionConstraint.parse(rawConstraint);
  } on FormatException catch (e) {
    throw ArgumentError(
      'Invalid version constraint "$rawConstraint": ${e.message}',
    );
  }

  if (constraint is VersionRange) {
    final min = constraint.min;
    final max = constraint.max;
    if (constraint.includeMin &&
        !constraint.includeMax &&
        min != null &&
        max != null) {
      if (max == min.nextBreaking || max == min.nextBreaking.firstPreRelease) {
        return '^$min';
      }
    }
  }
  return constraint.toString();
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
  final yaml = loadYaml(content);
  if (yaml is! Map) {
    throw ArgumentError(
      'Expected pubspec.yaml at ${pubspecFile.path} to be a YAML map.',
    );
  }
  final name = yaml['name'];
  if (name == null) {
    throw ArgumentError(
      'Could not find a "name" field in pubspec.yaml at ${pubspecFile.path}.',
    );
  }
  if (name is! String) {
    throw ArgumentError(
      'The "name" field in pubspec.yaml at ${pubspecFile.path} must be a '
      'string.',
    );
  }

  final environment = <String, String>{};
  if (yaml.containsKey('environment')) {
    final envNode = yaml['environment'];
    if (envNode is! Map) {
      throw ArgumentError(
        'The "environment" field in pubspec.yaml at ${pubspecFile.path} must '
        'be a map.',
      );
    }
    for (final entry in envNode.entries) {
      final key = entry.key;
      final val = entry.value;
      if (key is! String) {
        throw ArgumentError(
          'Keys in "environment" field in pubspec.yaml at ${pubspecFile.path} '
          'must be strings.',
        );
      }
      if (val is! String) {
        throw ArgumentError(
          'Constraint value for "$key" in "environment" field in pubspec.yaml '
          'at ${pubspecFile.path} must be a string.',
        );
      }
      environment[key] = canonicalizeConstraint(val);
    }
  }

  final executables = <String, String?>{};
  if (yaml.containsKey('executables')) {
    final execNode = yaml['executables'];
    if (execNode is! Map) {
      throw ArgumentError(
        'The "executables" field in pubspec.yaml at ${pubspecFile.path} must '
        'be a map.',
      );
    }
    for (final entry in execNode.entries) {
      final key = entry.key;
      final val = entry.value;
      if (key is! String) {
        throw ArgumentError(
          'Keys in "executables" field in pubspec.yaml at ${pubspecFile.path} '
          'must be strings.',
        );
      }
      if (val != null && val is! String) {
        throw ArgumentError(
          'Target value for executable "$key" in pubspec.yaml at '
          '${pubspecFile.path} must be a string or null.',
        );
      }
      executables[key] = val as String?;
    }
  }

  return (name: name, environment: environment, executables: executables);
}
