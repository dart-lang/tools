// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'src/api_description.dart';
import 'src/api_summary_customizer.dart';
import 'src/node.dart';

export 'src/api_summary_customizer.dart' show ApiSummaryCustomizer;

/// Creates a human-readable text summary of the public API of a package, in a
/// format suitable for auditing with a `diff` tool.
///
/// [packagePath] is the path to the directory containing the package's
/// `pubspec.yaml` file.
///
/// [packageName] is the name of the package.
///
/// If [createCustomizer] is provided, it will be called to create an instance
/// of [ApiSummaryCustomizer] which will be used to customize the behavior of
/// the tool.
Future<String> summarizePackage(
  String packagePath,
  String packageName, {
  ApiSummaryCustomizer Function()? createCustomizer,
}) async {
  final provider = PhysicalResourceProvider.INSTANCE;
  final libPath = provider.pathContext.join(packagePath, 'lib');
  final collection = AnalysisContextCollection(
    resourceProvider: provider,
    includedPaths: [libPath],
  );
  if (collection.contexts.isEmpty) {
    throw ArgumentError('No analysis context found for "$packagePath".');
  }
  if (collection.contexts.length > 1) {
    throw ArgumentError(
      'Multiple analysis contexts found for "$packagePath". '
      'Only a single package is supported.',
    );
  }
  final context = collection.contexts.single;
  final publicApi = ApiDescription(
    packageName,
    createCustomizer?.call() ?? ApiSummaryCustomizer(),
  );
  final stringBuffer = StringBuffer();
  printNodes(stringBuffer, await publicApi.build(context));
  return stringBuffer.toString();
}
