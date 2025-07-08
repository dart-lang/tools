// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:coverage/coverage.dart' show Resolver;
import 'package:coverage/src/hitmap.dart';
import 'package:test/test.dart';

String fileUri(String relativePath) =>
    Uri.file(File(relativePath).absolute.path).toString();

void main() {
  test('filter ignored', () async {
    // The ignored lines come from the comments in the test dart files. But the
    // hitmaps are fake, and don't have to correspond to real coverage data.
    final hitmaps = {
      fileUri('nonexistent_file.dart'): HitMap(
        {1: 1, 2: 2, 3: 3},
        {1: 1, 2: 2, 3: 3},
        {1: 'abc', 2: 'def'},
        {1: 1, 2: 2, 3: 3},
      ),
      fileUri('another_nonexistent_file.dart'): HitMap(
        {1: 1, 2: 2, 3: 3},
      ),
      fileUri('test/test_files/test_app.dart'): HitMap(
        {1: 1, 2: 2, 3: 3},
        {1: 1, 2: 2, 3: 3},
        {1: 'abc', 2: 'def'},
        {1: 1, 2: 2, 3: 3},
      ),
      fileUri('test/test_files/test_app_isolate.dart'): HitMap(
        {for (var i = 50; i < 100; ++i) i: i},
        {for (var i = 50; i < 100; ++i) i: i},
        {for (var i = 50; i < 100; ++i) i: '$i'},
        {for (var i = 50; i < 100; ++i) i: i},
      ),
    };

    // Lines ignored in test/test_files/test_app_isolate.dart.
    const ignores = [
      52,
      54,
      55,
      56,
      57,
      58,
      63,
      64,
      65,
      66,
      67,
      68,
      69,
      70,
      71,
      72,
      73,
    ];

    final expected = {
      fileUri('nonexistent_file.dart'): HitMap(
        {1: 1, 2: 2, 3: 3},
        {1: 1, 2: 2, 3: 3},
        {1: 'abc', 2: 'def'},
        {1: 1, 2: 2, 3: 3},
      ),
      fileUri('another_nonexistent_file.dart'): HitMap(
        {1: 1, 2: 2, 3: 3},
      ),
      fileUri('test/test_files/test_app_isolate.dart'): HitMap(
        {
          for (var i = 50; i < 100; ++i)
            if (!ignores.contains(i)) i: i
        },
        {
          for (var i = 50; i < 100; ++i)
            if (!ignores.contains(i)) i: i
        },
        {for (var i = 50; i < 100; ++i) i: '$i'},
        {
          for (var i = 50; i < 100; ++i)
            if (!ignores.contains(i)) i: i
        },
      ),
    };

    final resolver = await Resolver.create(packagePath: '.');

    final actual =
        hitmaps.filterIgnored(ignoredLinesInFilesCache: {}, resolver: resolver);

    expect(actual.keys.toList(), expected.keys.toList());
    for (final source in expected.keys) {
      expect(actual[source]!.lineHits, expected[source]!.lineHits);
      expect(actual[source]!.funcHits, expected[source]!.funcHits);
      expect(actual[source]!.funcNames, expected[source]!.funcNames);
      expect(actual[source]!.branchHits, expected[source]!.branchHits);
    }
  });
}
