// Copyright (c) 2026, the Dart project authors.
// Copyright (c) 2006, Kirill Simonov.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';
import 'package:yaml/src/equality.dart';
import 'package:yaml/yaml.dart';

/// A YAML source using references to create map keys
/// with exponential unfolded size.
const bigYaml = r'''
a: &a ["x","x","x","x","x","x","x","x","x"]
b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a]
c: &c [*b,*b,*b,*b,*b,*b,*b,*b,*b]
d: &d [*c,*c,*c,*c,*c,*c,*c,*c,*c]
e: &e [*d,*d,*d,*d,*d,*d,*d,*d,*d]
f: &f [*e,*e,*e,*e,*e,*e,*e,*e,*e]
g: &g [*f,*f,*f,*f,*f,*f,*f,*f,*f]
h: &h [*g,*g,*g,*g,*g,*g,*g,*g,*g]
i: &i [*h,*h,*h,*h,*h,*h,*h,*h,*h]
? [*i,*i,*i,*i,*i,*i,*i,*i,*i]
''';

void main() {
  test('hash and equality on big yaml', () {
    // Should not run excessively long.
    var value = loadYaml(bigYaml);
    // Equal to itself.
    expect(deepEquals(value, value), true);
    // Is consistent.
    var hashCode1 = deepHashCode(value);
    var hashCode2 = deepHashCode(value);
    expect(hashCode1, hashCode2);
  });
}
