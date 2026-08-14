// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Constants for all used JSON keys to prevent mis-typing.
library;

extension type const JsonKey(String value) implements String {}

const JsonKey configVersion = JsonKey('configVersion');

// Update these values when changing version.
const _minConfigVersion = 2;
const _maxConfigVersion = 2;

const _versionOverrideEnvironmentKey = 'pkg_package_config_test_override';

const minConfigVersion = int.fromEnvironment(
  '$_versionOverrideEnvironmentKey.minVersion',
  defaultValue: _minConfigVersion,
);

const maxConfigVersion = int.fromEnvironment(
  '$_versionOverrideEnvironmentKey.maxVersion',
  defaultValue: _maxConfigVersion,
);
