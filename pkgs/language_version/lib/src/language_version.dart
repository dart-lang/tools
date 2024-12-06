// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'concrete.dart';

/// A representation of a Dart language version.
///
/// Instances of [LanguageVersion] are not guaranteed
/// to implement equality based on just [major] and [minor].
///
/// To learn more about Dart language versions, check out
/// [Dart language versioning](https://dart.dev/guides/language/evolution#language-versioning).
abstract interface class LanguageVersion {
  /// The major version number (x.0) of this language version.
  int get major;

  /// The minor version number (0.x) of this language version.
  int get minor;

  /// Create a representation of a Dart language version with the
  /// specified [major] and [minor] versions.
  ///
  /// Both [major] and [minor] should be 0 or greater.
  const factory LanguageVersion.of(int major, int minor) =
      ConcreteLanguageVersion;
}
