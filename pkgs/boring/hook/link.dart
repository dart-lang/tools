// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:boring/src/hook_helpers/library.dart';
import 'package:hooks/hooks.dart';

/// Links the static library from hook/build.dart into a dynamic library with
/// only the BoringSSL functions that the application uses.
///
/// If linking fails in the default `fetch` build mode, falls back to the
/// pre-built dynamic library.
Future<void> main(List<String> args) async {
  await link(args, (input, output) async {
    await boringLibrary.link(input: input, output: output);
  });
}
