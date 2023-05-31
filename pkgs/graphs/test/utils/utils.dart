// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:graphs/graphs.dart';
import 'package:test/test.dart';

bool xEquals(X a, X b) => a.value == b.value;

int xHashCode(X a) => a.value.hashCode;

/// Returns a matcher that verifies that a function throws a [CycleException<T>]
/// with the given [cycle].
Matcher throwsCycleException<T>(List<T> cycle) => throwsA(
      allOf([
        isA<CycleException<T>>(),
        predicate((exception) {
          expect((exception as CycleException<T>).cycle, equals(cycle));
          return true;
        })
      ]),
    );

class X {
  final String value;

  X(this.value);

  @override
  bool operator ==(Object other) => throw UnimplementedError();

  @override
  int get hashCode => 42;

  @override
  String toString() => '($value)';
}
