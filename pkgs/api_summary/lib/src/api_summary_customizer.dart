// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/element/element.dart';

/// Clients of the API summary tool may extend this class to customize its
/// behavior.
///
/// Clients should not *implement* this class, however, because additional
/// methods may be added in the future.
base class ApiSummaryCustomizer {
  /// The top level elements exported by the libraries in [publicApiLibraries].
  ///
  /// This value is set by the tool before [initialScanComplete] is called.
  late final Set<Element> topLevelPublicElements;

  /// The analysis context for the package being summarized.
  ///
  /// This value is set by the tool before [setupComplete] is called.
  late final AnalysisContext analysisContext;

  /// The name of the package whose API is being summarized.
  ///
  /// This value is set by the tool before [setupComplete] is called.
  late final String packageName;

  /// The libraries that comprise the package's public API.
  ///
  /// This value is set by the tool before [initialScanComplete] is called.
  late final Iterable<LibraryElement> publicApiLibraries;

  /// Called after [publicApiLibraries] and [topLevelPublicElements] have been
  /// set, but before any analysis has been performed.
  ///
  /// Further analysis won't be performed until the returned Future completes.
  Future<void> initialScanComplete() async {}

  /// Called after [packageName] and [analysisContext] have been set, but before
  /// any analysis has been performed.
  ///
  /// The initial scan won't be performed until the returned Future completes.
  Future<void> setupComplete() async {}

  /// Whether to include full member signatures (constructors, methods) for
  /// non-public declarations that are implicitly exposed via public signatures.
  bool get includeImplicitNonPublicMembers => false;

  /// Called after [initialScanComplete] to determine if details about an
  /// element should be shown in the API summary.
  ///
  /// The default behavior is to show details about elements in
  /// [topLevelPublicElements], or non-public package elements when
  /// [includeImplicitNonPublicMembers] is true.
  bool shouldShowDetails(Element element) {
    if (topLevelPublicElements.contains(element)) {
      return true;
    }
    if (includeImplicitNonPublicMembers && element.library != null) {
      final uri = element.library!.uri;
      if (uri.scheme == 'package' &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments[0] == packageName) {
        return true;
      }
    }
    return false;
  }
}
