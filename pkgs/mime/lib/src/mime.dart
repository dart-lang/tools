// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'mime_tables.g.dart' show mimeToExtensions;
import 'mime_type.dart';

final MimeTypeResolver _globalResolver = MimeTypeResolver();

/// The maximum number of bytes needed, to match all default magic-numbers.
int get defaultMagicNumbersMaxLength => _globalResolver.magicNumbersMaxLength;

/// The default file extension for a given MIME type.
///
/// If [mimeType] has multiple associated extensions, the returned string is one
/// of those, chosen as the default extension for that MIME type.
///
/// Returns `null` if [mimeType] is not a recognized and supported MIME type.
String? extensionFromMime(String mimeType) {
  return mimeToExtensions[mimeType.toLowerCase()]?.first;
}

/// Extract the extension from [path] and use that for MIME-type lookup, using
/// the default extension map.
///
/// If no matching MIME-type was found, `null` is returned.
///
/// If [headerBytes] is present, a match for known magic-numbers will be
/// performed first. This allows the correct mime-type to be found, even though
/// a file have been saved using the wrong file-name extension. If less than
/// [defaultMagicNumbersMaxLength] bytes was provided, some magic-numbers won't
/// be matched against.
String? lookupMimeType(String path, {List<int>? headerBytes}) {
  return _globalResolver.lookup(path, headerBytes: headerBytes);
}
