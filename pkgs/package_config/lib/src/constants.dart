// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Constants for all used JSON keys to prevent mis-typing.
library;

extension type const JsonKey(String value) implements String {}

const JsonKey configVersion = JsonKey('configVersion');
const JsonKey path = JsonKey('path');
const JsonKey configPath = JsonKey('configPath');
const JsonKey package = JsonKey('package');
const JsonKey name = JsonKey('name');
const JsonKey root = JsonKey('root');
const JsonKey packageUri = JsonKey('packageUri');
const JsonKey lib = JsonKey('lib');
const JsonKey languageVersion = JsonKey('languageVersion');
const JsonKey languageVersionOverride = JsonKey('languageVersionOverride');

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
