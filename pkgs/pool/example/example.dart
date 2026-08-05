// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pool/pool.dart';

void main() async {
  // Create a pool that allows at most 3 concurrent resources.
  final pool = Pool(3);

  try {
    print('Starting tasks with pool size of 3...');

    // Use pool.forEach to process a list of items concurrently.
    // This is useful for limiting concurrent network requests or file I/O.
    final items = List.generate(10, (i) => i);

    await for (final result in pool.forEach(items, (item) async {
      print('  [Start] Processing item $item');
      // Simulate some async work like a network request.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      print('  [Done]  Processing item $item');
      return 'Result for $item';
    })) {
      print('Processed: $result');
    }

    print('All tasks completed!');
  } finally {
    // Close the pool.
    await pool.close();
  }
}
