// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// These libraries don't expose *exactly* the same API, but they overlap in all
// the cases we care about.
export 'dart:io' if (dart.library.js) 'package:node_io/node_io.dart';
