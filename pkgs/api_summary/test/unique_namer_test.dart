// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'package:api_summary/src/unique_namer.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'test_utils.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UniqueNamerTest);
  });
}

@reflectiveTest
class UniqueNamerTest extends ApiSummaryTest {
  Future<void> test_collidingNamesAreDisambiguated() async {
    final f1 = (await analyzeLibrary(
      pathWithinLib: 'file1.dart',
      'f() {}',
    )).getTopLevelFunction('f')!;
    final f2 = (await analyzeLibrary(
      pathWithinLib: 'file2.dart',
      'f() {}',
    )).getTopLevelFunction('f')!;
    final uniqueNamer = UniqueNamer();
    final f1Name = uniqueNamer.name(f1);
    final f2Name = uniqueNamer.name(f2);
    expect(f1Name.toString(), 'f@1');
    expect(f2Name.toString(), 'f@2');
  }

  Future<void> test_name_returnsSameNameOnSuccessiveCalls() async {
    final f = (await analyzeLibrary('f() {}')).getTopLevelFunction('f')!;
    final uniqueNamer = UniqueNamer();
    final name1 = uniqueNamer.name(f);
    final name2 = uniqueNamer.name(f);
    expect(name1, same(name2));
  }

  Future<void> test_nonCollidingNamesAreNotDisambiguated() async {
    final f = (await analyzeLibrary(
      pathWithinLib: 'file1.dart',
      'f() {}',
    )).getTopLevelFunction('f')!;
    final g = (await analyzeLibrary(
      pathWithinLib: 'file2.dart',
      'g() {}',
    )).getTopLevelFunction('g')!;
    final uniqueNamer = UniqueNamer();
    final fName = uniqueNamer.name(f);
    final gName = uniqueNamer.name(g);
    expect(fName.toString(), 'f');
    expect(gName.toString(), 'g');
  }

  Future<void> test_three_collisions() async {
    final f1 = (await analyzeLibrary(
      pathWithinLib: 'file1.dart',
      'f() {}',
    )).getTopLevelFunction('f')!;
    final f2 = (await analyzeLibrary(
      pathWithinLib: 'file2.dart',
      'f() {}',
    )).getTopLevelFunction('f')!;
    final f3 = (await analyzeLibrary(
      pathWithinLib: 'file3.dart',
      'f() {}',
    )).getTopLevelFunction('f')!;
    final uniqueNamer = UniqueNamer();
    final f1Name = uniqueNamer.name(f1);
    final f2Name = uniqueNamer.name(f2);
    final f3Name = uniqueNamer.name(f3);
    expect(f1Name.toString(), 'f@1');
    expect(f2Name.toString(), 'f@2');
    expect(f3Name.toString(), 'f@3');
  }
}
