// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// NOTE: Upgrading to Dart 3.12+
//
// When the package's minimum supported SDK version is bumped to Dart 3.12
// or higher (which fully supports `@pragma('external-effect')` natively), this
// class can be simplified to a pure zero-cost external function invocation:
//
// ```dart
// @pragma('vm:prefer-inline')
// @pragma('dart2js:prefer-inline')
// @pragma('wasm:prefer-inline')
// void blackhole(Object? value) {
//   _BlackholeSink._reach(value);
// }
//
// class _BlackholeSink {
//   @pragma('external-effect')
//   external static void _reach(Object? value);
// }
// ```
//
// Until then, we use a highly optimized static dynamic sink with an opaque
// read guard that is fully compatible with Dart 3.10 and 3.11.

/// A compiler-recognized zero-cost live sink to prevent dead-code elimination.
///
/// Passing a value to [blackhole] ensures that the compiler treats the value's
/// computation as live, preventing tree-shaking and dead-code elimination,
/// while introducing zero runtime execution overhead.
class Blackhole {
  static Object? _sink;

  /// An opaque guard that convinces compiler static analyses (such as TFA)
  /// that [_sink] is read, preventing it from being tree-shaken as write-only.
  ///
  /// Automatically invoked inside benchmark measurement loops.
  @pragma('vm:never-inline')
  @pragma('dart2js:never-inline')
  @pragma('wasm:never-inline')
  static void preventDCE() {
    // Opaque condition that is always false at runtime but unresolvable
    // at compile-time.
    if (int.tryParse('0') == 1) {
      print(_sink);
    }
  }
}

/// A zero-cost compiler-safe live sink to prevent dead-code elimination.
@pragma('vm:prefer-inline')
@pragma('dart2js:prefer-inline')
@pragma('wasm:prefer-inline')
void blackhole(Object? value) {
  Blackhole._sink = value;
}
