// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'dart:io';

import 'package:boring/src/hook_helpers/library.dart';
import 'package:prebuilt_code_assets/tools.dart';

/// Builds the dynamic and the static library for a release.
///
/// hook/build.dart bundles the dynamic library when linking is disabled, and
/// hook/link.dart links the static library into a dynamic library with only
/// the functions an application uses when linking is enabled.
Future<void> main(List<String> args) async {
  await runPrecompileBinariesCli(
    args,
    library: boringLibrary,
    packageRoot: Platform.script.resolve('../'),
  );
}
