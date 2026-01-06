// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'media_types.g.dart';

/// The default file extension for a given MIME type.
///
/// If [mimeType] has multiple associated extensions, the returned string is one
/// of those, chosen as the default extension for that MIME type.
///
/// Returns `null` if [mimeType] is not a recognized and supported MIME type.
String? extensionFromMime(String mimeType) {
  final exts = mediaToExtensions[mimeType.toLowerCase()];
  return exts?.first;
}
