// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

Future<String> downloadText(String uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(uri));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to download $uri (${response.statusCode})',
        uri: Uri.parse(uri),
      );
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}

Future<Object?> downloadJson(String uri) async =>
    jsonDecode(await downloadText(uri));
