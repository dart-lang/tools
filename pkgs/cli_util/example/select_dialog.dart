// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:math';

import 'package:cli_util/cli_components.dart';
import 'package:cli_util/windows_compatibility.dart';

Future<void> main() async {
  final stdin = io.Platform.isWindows ? Win32AnsiStdin() : io.stdin;

  // These streams are single subscription, but need to be listenable from
  // multiple places, so we convert them to broadcast streams.
  //
  // In a real app, you would probably have your own stdin listener, which
  // should ignore events while the dialogs are open.
  final inputStream = stdin.asBroadcastStream(
    // Cancel stdin subscription once we have no listeners.
    onCancel: (subscription) => subscription.cancel(),
  );

  // Hacky way to keep open the stream until we reach the finally block.
  final subscription = inputStream.listen((_) {});

  try {
    print('How many items do you want in the multiselect dialog?');
    final counts = List.generate(9, (i) => '${(i + 1) * 5}');
    final countResult = await showSingleSelectDialog(
      counts,
      inputStream,
    );
    if (countResult == null) {
      print('No count selected, exiting.');
      io.exitCode = 1;
      return;
    }
    final count = int.parse(counts[countResult]);
    print('Got result $count');

    final random = Random();
    final allOptions = List.generate(count, (i) {
      final lineCount = random.nextInt(8); // 0 to 7 lines
      final description =
          lineCount == 0
              ? null
              : List.generate(
                lineCount,
                (line) =>
                    '\x1b[2mDescription line ${line + 1} for item #$i with '
                    'some extra words to demonstrate word wrapping\x1b[0m',
              ).join('\n');
      return SelectOption('Item #$i', description: description);
    });
    print('Select multiple items:');
    final selectedOptions = await showMultiSelectDialog(
      allOptions,
      inputStream,
      initialSelected: {1, 2},
    );
    if (selectedOptions == null) {
      print('Selection cancelled, exiting.');
      io.exitCode = 1;
      return;
    }

    print('Selection complete, selected ${selectedOptions.length} item(s):');
    for (final index in selectedOptions) {
      print(' - ${allOptions[index].label}');
    }
  } finally {
    await subscription.cancel();
  }
}
