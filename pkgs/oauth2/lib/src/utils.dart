// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

/// Adds additional query parameters to [url], overwriting the original
/// parameters if a name conflict occurs.
Uri addQueryParameters(Uri url, Map<String, dynamic> parameters) {
  final queryParams = <String, dynamic>{...url.queryParametersAll};
  parameters.forEach((key, value) {
    if (value is Iterable) {
      queryParams[key] = value.map((e) => e.toString()).toList();
    } else {
      queryParams[key] = value.toString();
    }
  });
  return url.replace(queryParameters: queryParams);
}

String basicAuthHeader(String identifier, String secret) {
  var userPass = '${Uri.encodeFull(identifier)}:${Uri.encodeFull(secret)}';
  return 'Basic ${base64Encode(ascii.encode(userPass))}';
}
