// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
// TODO(paulberry): move pub_package_resolution.dart out of src
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart';
import 'package:api_summary/src/api_declaration.dart';
import 'package:api_summary/src/text_renderer.dart';
import 'package:test/test.dart';

class ApiSummaryTest extends PubPackageResolutionTest {
  @override
  void setUp() {
    apiSummaryRenderer = renderTextSummary;
    super.setUp();
  }

  Future<LibraryElement> analyzeLibrary(
    String content, {
    String pathWithinLib = 'test.dart',
  }) async {
    final file = newFile('$testPackageLibPath/$pathWithinLib', content);
    final resolvedUnitResult = await resolveFile(file.path);
    expect(
      resolvedUnitResult.diagnostics.where(
        (diagnostic) => diagnostic.severity == Severity.error,
      ),
      isEmpty,
    );
    return resolvedUnitResult.libraryElement;
  }
}
