// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/element/element.dart';

/// Contextual state provided to [ApiSummaryCustomizer] during an API summary
/// scan.
final class ApiSummaryContext {
  /// The name of the package whose API is being summarized.
  final String packageName;

  /// The analysis context for the package being summarized.
  final AnalysisContext analysisContext;

  /// The libraries that comprise the package's public API.
  ///
  /// This is empty during [ApiSummaryCustomizer.setupComplete], and populated
  /// before [ApiSummaryCustomizer.initialScanComplete] is called.
  final List<LibraryElement> publicApiLibraries;

  /// The top level elements exported by the libraries in [publicApiLibraries].
  ///
  /// This is empty during [ApiSummaryCustomizer.setupComplete], and populated
  /// before [ApiSummaryCustomizer.initialScanComplete] is called.
  final Set<Element> topLevelPublicElements;

  ApiSummaryContext({
    required this.packageName,
    required this.analysisContext,
    List<LibraryElement>? publicApiLibraries,
    Set<Element>? topLevelPublicElements,
  }) : publicApiLibraries = publicApiLibraries ?? [],
       topLevelPublicElements = topLevelPublicElements ?? {};
}

/// Clients of the API summary tool may extend this class to customize its
/// behavior.
///
/// Clients should not *implement* this class, however, because additional
/// methods may be added in the future.
base class ApiSummaryCustomizer {
  const ApiSummaryCustomizer();

  /// Called after [ApiSummaryContext.packageName] and
  /// [ApiSummaryContext.analysisContext] have been set, but before any analysis
  /// has been performed.
  ///
  /// The initial scan won't be performed until the returned Future completes.
  Future<void> setupComplete(ApiSummaryContext context) async {}

  /// Called after [ApiSummaryContext.publicApiLibraries] and
  /// [ApiSummaryContext.topLevelPublicElements] have been populated, but before
  /// declaration details are built.
  ///
  /// Further analysis won't be performed until the returned Future completes.
  Future<void> initialScanComplete(ApiSummaryContext context) async {}

  /// Whether to include full member signatures (constructors, methods) for
  /// non-public declarations that are implicitly exposed via public signatures.
  bool get includeImplicitNonPublicMembers => false;

  /// Called after [initialScanComplete] to determine if details about an
  /// element should be shown in the API summary.
  ///
  /// The default behavior is to show details about elements in
  /// [ApiSummaryContext.topLevelPublicElements], or non-public package elements
  /// when [includeImplicitNonPublicMembers] is true.
  bool shouldShowDetails(Element element, ApiSummaryContext context) {
    if (context.topLevelPublicElements.contains(element)) {
      return true;
    }
    if (includeImplicitNonPublicMembers && element.library != null) {
      final uri = element.library!.uri;
      if (uri.scheme == 'package' &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments[0] == context.packageName) {
        return true;
      }
    }
    return false;
  }
}
