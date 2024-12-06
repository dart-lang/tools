// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'language_version.dart';

/// A default implementation of [LanguageVersion].
///
/// Should not be exported, but rather created with [LanguageVersion.of].
final class ConcreteLanguageVersion implements LanguageVersion {
  @override
  final int major;

  @override
  final int minor;

  const ConcreteLanguageVersion(this.major, this.minor)
      : assert(major >= 0),
        assert(minor >= 0);

  @override
  String toString() => '$major.$minor';
}
