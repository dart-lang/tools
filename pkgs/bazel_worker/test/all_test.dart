// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'message_grouper_test.dart' as message_grouper;
import 'worker_loop_test.dart' as worker_loop;

void main() {
  message_grouper.main();
  worker_loop.main();
}
