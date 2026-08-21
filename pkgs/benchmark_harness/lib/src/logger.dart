// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

/// Logs a warning message to stderr on the VM.
void logWarning(String message) {
  try {
    stderr.writeln(message);
  } catch (_) {
    print(message);
  }
}
