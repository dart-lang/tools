// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cli_config/cli_config.dart';

Future<void> main(List<String> args) async {
  final config = await Config.fromArguments(arguments: args);
  final myPath =
      config.optionalPath('my_path', resolveUri: true, mustExist: false);
  print(myPath?.toFilePath());
}
