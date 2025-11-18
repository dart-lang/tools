// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  // https://github.com/apache/httpd/blob/trunk/docs/conf/mime.types
  const mimeTypesUrl = 'https://raw.githubusercontent.com/'
      'apache/httpd/refs/heads/trunk/docs/conf/mime.types';

  print('Reading from $mimeTypesUrl ...');
  final response = await http.get(Uri.parse(mimeTypesUrl));

  final outFile = File(path.join('third_party', 'httpd', 'mime.types'));
  outFile.writeAsStringSync(response.body);
  print('Wrote ${outFile.path}.');
}
