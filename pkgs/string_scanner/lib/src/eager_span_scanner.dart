// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'line_scanner.dart';
import 'span_scanner.dart';

/// A [SpanScanner] that tracks the line and column eagerly, like [LineScanner].
class EagerSpanScanner extends SpanScanner with LineScannerMixin {
  EagerSpanScanner(super.string, {super.sourceUrl, super.position});
}
