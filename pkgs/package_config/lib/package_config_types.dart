// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A package configuration is a way to assign file paths to package URIs,
/// and vice-versa,
library package_config.package_config;

export "src/package_config.dart"
    show PackageConfig, Package, LanguageVersion, InvalidLanguageVersion;
export "src/errors.dart" show PackageConfigError;
