// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'default_extension_map.dart';

/// Default extension for recognized MIME types.
///
/// Is the inverse of [defaultExtensionMap], and where that
/// map has multiple extensions which map to the same
/// MIME type, this map maps that MIME type to a *default*
/// extension.
///
/// Used by [extensionFromMime].
final Map<String, String> _defaultMimeTypeMap = {
  for (var entry in defaultExtensionMap.entries) entry.value: entry.key,
  'application/vnd.ms-excel': 'xls',
  'application/vnd.ms-powerpoint': 'ppt',
  'image/jpeg': 'jpg',
  'image/tiff': 'tif',
  'image/svg+xml': 'svg',
  'text/calendar': 'ics',
  'text/javascript': 'js',
  'text/plain': 'txt',
  'text/sgml': 'sgml',
  'text/x-pascal': 'pas',
  'video/mp4': 'mp4',
  'video/mpeg': 'mpg',
  'video/quicktime': 'mov',
  'video/x-matroska': 'mkv',
};

/// The default file extension for a given MIME type.
///
/// If [mimeType] has multiple associated extensions,
/// the returned string is one of those, chosen as the default
/// extension for that MIME type.
///
/// Returns `null` if [mimeType] is not a recognized and
/// supported MIME type.
String? extensionFromMime(String mimeType) =>
    _defaultMimeTypeMap[mimeType.toLowerCase()];
