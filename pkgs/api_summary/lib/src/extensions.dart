// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';

import 'api_declaration.dart';
import 'meta_facet.dart';

extension ApiLibraryExtension on ApiLibrary {
  bool get isExperimental => facets.any(
    (f) =>
        f is MetaContractFacet &&
        f.contracts.contains(MetaContract.experimental),
  );
}

extension ElementExtension on Element {
  /// Returns the appropriate name for describing the element in `api.txt`.
  ///
  /// The name is the same as [name], but with `=` appended for setters.
  String get apiName {
    var apiName = name!;
    if (this is SetterElement) {
      apiName += '=';
    }
    return apiName;
  }
}

extension FormalParameterElementExtension on FormalParameterElement {
  bool get isDeprecated =>
      // TODO(paulberry): add this to the analyzer public API
      metadata.hasDeprecated;
}

extension IterableIterableExtension on Iterable<Iterable<Object?>> {
  /// Forms a list containing [prefix], followed by the elements of `this`
  /// (separated by [separator]), followed by [suffix].
  ///
  /// Each element of `this` is also an iterable; these elements are added to
  /// the resulting list using `.addAll`, so one level of iterable nesting is
  /// removed.
  List<Object?> separatedBy({
    String separator = ', ',
    String prefix = '',
    String suffix = '',
  }) {
    final result = <Object?>[prefix];
    var first = true;
    for (final item in this) {
      if (first) {
        first = false;
      } else {
        result.add(separator);
      }
      result.addAll(item);
    }
    result.add(suffix);
    return result;
  }
}

extension UriExtension on Uri {
  bool isIn(String packageName) => switch (this) {
    Uri(scheme: 'package', pathSegments: [final pkg, ...]) =>
      pkg == packageName,
    _ => false,
  };

  bool isInPublicLibOf(String packageName) => switch (this) {
    Uri(scheme: 'package', pathSegments: [final pkg, final topDir, ...]) =>
      pkg == packageName && topDir != 'src',
    _ => false,
  };

  bool isPrimaryPublicLibOf(String packageName) => switch (this) {
    Uri(scheme: 'package', pathSegments: [final pkg, final file]) =>
      pkg == packageName && file == '$packageName.dart',
    _ => false,
  };
}
