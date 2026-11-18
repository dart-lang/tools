// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Runs an [SseClient] inside a dedicated Web Worker, where there is no
// `window`. This mirrors contexts like the service worker of a Manifest V3
// Chrome extension.

import 'package:sse/client/sse_client.dart';

void main() {
  var channel = SseClient('/test');

  channel.stream.listen((s) {
    if (s.startsWith('send ')) {
      var count = int.parse(s.split(' ').last);
      for (var i = 0; i < count; i++) {
        channel.sink.add('$i');
      }
    } else {
      channel.sink.add(s);
    }
  });
}
