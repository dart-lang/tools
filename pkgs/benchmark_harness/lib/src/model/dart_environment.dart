// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Central directory of compile-time environment configurations (-D defines).
library;

const _prefix = 'benchmark_harness';

final class DartEnvironment<T> {
  /// Special cases to enable const evaluate tree-shaking and default params
  static const validateValue = bool.fromEnvironment('$_prefix.validate');
  static const forceRunValue = bool.fromEnvironment('$_prefix.force_run');

  static const validate = DartEnvironment<bool>._(
    'validate',
    bool.fromEnvironment('$_prefix.validate'),
  );

  static const forceRun = DartEnvironment<bool>._(
    'force_run',
    bool.fromEnvironment('$_prefix.force_run'),
  );

  static const json = DartEnvironment<bool>._(
    'json',
    bool.fromEnvironment('$_prefix.json'),
  );

  static const platform = DartEnvironment<String>._(
    'platform',
    String.fromEnvironment('$_prefix.platform', defaultValue: 'jit'),
  );

  static const os = DartEnvironment<String>._(
    'os',
    String.fromEnvironment('$_prefix.os', defaultValue: 'unknown'),
  );

  static const dartSdkVersion = DartEnvironment<String>._(
    'dart_sdk_version',
    String.fromEnvironment(
      '$_prefix.dart_sdk_version',
      defaultValue: 'unknown',
    ),
  );

  final String key;
  final T value;

  const DartEnvironment._(this.key, this.value);

  String argsValue(T value) => '-D$_prefix.$key=$value';
}
