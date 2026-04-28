// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

extension Keys on Stream<List<int>> {
  /// Listens for terminal byte sequences and maps them to key commands.
  Stream<Key> get keys {
    // Note that we cannot use async* here because the returned stream will not
    // actually complete when cancelled if the user hits ctrl+c.
    final streamController = StreamController<Key>();
    final subscription = listen((bytes) {
      for (var b = 0; b < bytes.length; b++) {
        final key = switch (bytes[b]) {
          65 => Key.up,
          66 => Key.down,
          49 || 72 => Key.home, // 1, H
          52 || 70 => Key.end, // 4, F
          53 => Key.pageUp, // 5
          54 => Key.pageDown, // 6
          10 || 13 => Key.enter, // newline/carraige return
          32 => Key.space,
          // End of text/end of transmission
          3 || 4 => Key.quit,
          // Escape key but not escape sequence
          27 when b + 1 >= bytes.length || bytes[b + 1] != 91 => Key.quit,
          _ => null,
        };
        if (key != null) {
          streamController.add(key);
        }
      }
    });
    streamController.onCancel = subscription.cancel;
    return streamController.stream;
  }
}

enum Key { up, down, pageUp, pageDown, home, end, space, enter, quit }
