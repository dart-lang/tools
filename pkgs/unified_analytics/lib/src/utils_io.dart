// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'enums.dart';

extension DevicePlatformIO on DevicePlatform {
  static DevicePlatform fromOs() {
    return switch (Platform.operatingSystem) {
      'linux' => DevicePlatform.linux,
      'macos' => DevicePlatform.macos,
      _ => DevicePlatform.windows,
    };
  }
}
