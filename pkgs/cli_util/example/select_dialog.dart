// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cli_util/cli_components.dart';

Future<void> main() async {
  final inputStream = stdin.asBroadcastStream(
    // Cancel stdin subscription once we have no listeners.
    onCancel: (subscription) => subscription.cancel(),
  );

  // Hacky way to keep open the stream until we reach the finally block.
  final subscription = inputStream.listen((_) {});

  try {
    print('How many items do you want in the multiselect dialog?');
    final counts = List.generate(9, (i) => '${(i + 1) * 5}');
    final countResult = await showSingleSelectDialog(counts, inputStream);
    if (countResult == null) {
      print('No count selected, exiting.');
      exitCode = 1;
      return;
    }
    final count = int.parse(countResult);
    print('Got result $count');

    final allOptions = List.generate(count, (i) => 'Item #$i');
    print('Select multiple items:');
    final selectedOptions =
        await showMultiSelectDialog(allOptions, inputStream);
    if (selectedOptions == null) {
      print('Selection cancelled, exiting.');
      exitCode = 1;
      return;
    }

    print(
      'Selection complete, selected ${selectedOptions.length} item(s):',
    );
    for (final option in selectedOptions) {
      print(' - $option');
    }
  } finally {
    await subscription.cancel();
  }
}
