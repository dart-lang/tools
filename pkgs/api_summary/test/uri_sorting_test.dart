// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'package:api_summary/src/uri_sorting.dart';
import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UriTest);
  });
}

@reflectiveTest
class UriTest {
  void test_sortOrder_inOrOutOfPackageBeforeName() {
    _checkSorting(
      uris: [
        (Uri.parse('package:a/a.dart'), false),
        (Uri.parse('package:b/b.dart'), false),
        (Uri.parse('package:c/c.dart'), false),
      ],
      expectedOrder: [
        'package:b/b.dart',
        'package:a/a.dart',
        'package:c/c.dart',
      ],
      packageName: 'b',
    );
  }

  void test_sortOrder_categoriesWithinPackage() {
    _checkSorting(
      uris: [
        (Uri.parse('dart:core'), false),
        (Uri.parse('package:a/a.dart'), false),
        (Uri.parse('package:b/src/a.dart'), false),
        (Uri.parse('package:b/a_experimental.dart'), true),
        (Uri.parse('package:b/z_experimental.dart'), true),
        (Uri.parse('package:b/a_stable.dart'), false),
        (Uri.parse('package:b/z_stable.dart'), false),
        (Uri.parse('package:b/b.dart'), false),
      ],
      expectedOrder: [
        'package:b/b.dart',
        'package:b/a_stable.dart',
        'package:b/z_stable.dart',
        'package:b/a_experimental.dart',
        'package:b/z_experimental.dart',
        'package:b/src/a.dart',
        'dart:core',
        'package:a/a.dart',
      ],
      packageName: 'b',
    );
  }

  void _checkSorting({
    required List<(Uri, bool)> uris,
    required List<String> expectedOrder,
    required String packageName,
  }) {
    expect(
      uris
          .sortedBy((e) => UriSortKey(e.$1, packageName, isExperimental: e.$2))
          .map((e) => e.$1.toString())
          .toList(),
      expectedOrder,
    );
    expect(
      uris.reversed
          .sortedBy((e) => UriSortKey(e.$1, packageName, isExperimental: e.$2))
          .map((e) => e.$1.toString())
          .toList(),
      expectedOrder,
    );
  }
}
