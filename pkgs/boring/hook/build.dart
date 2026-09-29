// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:boring/src/hook_helpers/library.dart';
import 'package:hooks/hooks.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    await boringLibrary.build(
      input: input,
      output: output,
      additionalDependencies: [
        input.packageRoot.resolve('lib/src/hook_helpers/hashes.dart'),
      ],
    );
  });
}
