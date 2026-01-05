// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class Screenshot {
  final String description;
  final String path;

  Screenshot(this.description, this.path);
}

List<Screenshot> parseScreenshots(List? input) => [
  if (input != null)
    for (final e in input)
      if (e is Map)
        Screenshot(_readString(e, 'description'), _readString(e, 'path')),
];

String _readString(Map input, String entryName) => switch (input[entryName]) {
  final String value => value,
  final value => throw CheckedFromJsonException(
    input,
    entryName,
    'Screenshot',
    value == null ? 'Missing required key `$entryName`' : '`$value` is not a String', 
  ),
};
