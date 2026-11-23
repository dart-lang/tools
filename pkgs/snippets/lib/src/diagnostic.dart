// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

/// An error in an example reference, region marker, or markdown code block.
final class ExampleFormatException extends SourceSpanFormatException {
  ExampleFormatException(super.message, [super.span, super.source]);
}

/// Callback that collects [ExampleFormatException]s without aborting on the
/// first one.
typedef ErrorSink = void Function(ExampleFormatException error);
