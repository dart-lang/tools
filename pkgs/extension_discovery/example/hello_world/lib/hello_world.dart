// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:extension_discovery/extension_discovery.dart';

Future<void> sayHello(String language) async {
  // Find extensions for the "hello_world" package.
  // WARNING: This only works when running in JIT-mode, if running in AOT-mode
  //          you must supply the `packageConfig` argument, and have a local
  //          `.dart_tool/package_config.json` and `$PUB_CACHE`.
  final extensions = await findExtensions('hello_world');

  // Search extensions to see if one provides a message for language
  for (final ext in extensions) {
    final config = ext.config;
    if (config['language'] == language) {
      print(config['message']);
      return; // Don't print more messages!
    }
  }

  if (language == 'danish') {
    print('Hej verden');
  } else {
    print('Hello world!');
  }
}
