// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final doc = YamlEditor('''
- 0 # comment 0
- 1 # comment 1
- 2 # comment 2
''');
  doc.remove([1]);

  print(doc);
}
