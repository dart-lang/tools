// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stack_trace/stack_trace.dart';

void main() {
  Chain.capture(_scheduleAsync);
}

void _scheduleAsync() {
  Future<void>.delayed(const Duration(seconds: 1)).then((_) => _runAsync());
}

void _runAsync() {
  throw StateError('oh no!');
}
