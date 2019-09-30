// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// These libraries don't expose *exactly* the same API, but they overlap in all
// the cases we care about.
export 'io_export.dart'
    // We don't actually support the web - exporting dart:io gives a reasonably
    // clear signal to users about that since it doesn't exist.
    if (dart.library.html) 'io_export.dart'
    if (dart.library.js) 'package:node_io/node_io.dart';
