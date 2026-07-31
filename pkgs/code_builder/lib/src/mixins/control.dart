// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file

part of '../specs/control.dart';

@internal
@immutable
mixin ControlBody {
  /// The body of this block.
  ///
  /// *Note: will always be wrapped in `{`braces`}`*.
  Code? get body;
}

@internal
@immutable
mixin ControlLabel on ControlBody {
  /// An (optional) label for this block.
  ///
  /// ```dart
  /// label: {block}
  /// ```
  ///
  /// https://dart.dev/language/loops#labels
  String? get label;
}
