// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:api_summary/api_summary.dart';
import 'package:path/path.dart' as p;

void main() async {
  // Locate this package's root directory (current working directory)
  final packagePath = p.normalize(p.absolute(Directory.current.path));

  print('Generating API summary for the api_summary package...\n');

  // Call summarizePackage to get the public API footprints
  final summary = await summarizePackage(packagePath, 'api_summary');

  // Output the generated summary to stdout
  print(summary);
}
