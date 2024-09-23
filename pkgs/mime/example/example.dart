// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mime/mime.dart';

void main() {
  print(lookupMimeType('test.html'));
  // text/html

  print(lookupMimeType('test', headerBytes: [0xFF, 0xD8]));
  // image/jpeg

  print(lookupMimeType('test.html', headerBytes: [0xFF, 0xD8]));
  // image/jpeg
}
