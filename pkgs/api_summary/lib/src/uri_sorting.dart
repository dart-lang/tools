// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'extensions.dart';

/// URI categorization used by [UriSortKey].
enum UriCategory {
  primaryPublicEntryPoint,
  stablePublicEntryPoint,
  experimentalPublicEntryPoint,
  nonPublicInPackage,
  notInPackage,
}

/// Sort key used to sort libraries in the output.
///
/// Libraries in the specified package will be output first:
/// 1. The primary public entry point (`package:<pkg>/<pkg>.dart`, when not
///    `@experimental`)
/// 2. Other stable public entry points (`package:<pkg>/...` outside `src/`)
/// 3. Experimental public entry points (`@experimental`)
/// 4. Non-public libraries in the package (`package:<pkg>/src/...`)
/// 5. Libraries not in the package (`dart:*` and external `package:*`)
final class UriSortKey implements Comparable<UriSortKey> {
  final UriCategory _category;
  final String _uriString;

  UriSortKey(Uri uri, String pkgName, {bool isExperimental = false})
    : _category = _categorize(uri, pkgName, isExperimental: isExperimental),
      _uriString = uri.toString();

  static UriCategory _categorize(
    Uri uri,
    String pkgName, {
    required bool isExperimental,
  }) {
    if (!uri.isIn(pkgName)) {
      return UriCategory.notInPackage;
    }
    if (!uri.isInPublicLibOf(pkgName)) {
      return UriCategory.nonPublicInPackage;
    }
    if (isExperimental) {
      return UriCategory.experimentalPublicEntryPoint;
    }
    if (uri.isPrimaryPublicLibOf(pkgName)) {
      return UriCategory.primaryPublicEntryPoint;
    }
    return UriCategory.stablePublicEntryPoint;
  }

  @override
  int compareTo(UriSortKey other) {
    if (_category.index.compareTo(other._category.index) case final value
        when value != 0) {
      return value;
    }
    return _uriString.compareTo(other._uriString);
  }
}
