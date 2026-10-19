// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pubspec_parse/pubspec_parse.dart';

void main() {
  const yaml = '''
name: my_package
version: 1.2.3
environment:
  sdk: ^3.8.0
dependencies:
  collection: ^1.19.0
  path:
    path: ../path
''';

  final pubspec = Pubspec.parse(yaml);
  print(pubspec.name); // my_package
  print(pubspec.version); // 1.2.3

  final collection = pubspec.dependencies['collection'];
  if (collection is HostedDependency) {
    print(collection.version); // ^1.19.0
  }

  final path = pubspec.dependencies['path'];
  if (path is PathDependency) {
    print(path.path); // ../path
  }

  final fromFile = File('pubspec.yaml').readAsStringSync();
  final parsedFile = Pubspec.parse(
    fromFile,
    sourceUrl: Uri.file('pubspec.yaml'),
  );
  print('${parsedFile.name} ${parsedFile.version}');
}
