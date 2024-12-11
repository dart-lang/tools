// Copyright (c) 2023, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show json;

import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final jsonString = r'''
{
  "key": "value",
  "list": [
    "first",
    "second",
    "last entry in the list"
  ],
  "map": {
    "multiline": "this is a fairly long string with\nline breaks..."
  }
}
''';
  final jsonValue = json.decode(jsonString);

  final yamlEditor = YamlEditor('');
  yamlEditor.update([], jsonValue);
  print(yamlEditor.toString());
}
