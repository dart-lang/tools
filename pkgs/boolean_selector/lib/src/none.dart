// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../boolean_selector.dart';

/// A selector that matches no inputs.
class None implements BooleanSelector {
  // TODO(nweiz): Stop explicitly providing a type argument when sdk#32412 is
  // fixed.
  final variables = const <String>[];

  const None();

  bool evaluate(semantics) => false;

  BooleanSelector intersection(BooleanSelector other) => this;

  BooleanSelector union(BooleanSelector other) => other;

  void validate(bool isDefined(String variable)) {}

  String toString() => "<none>";
}
