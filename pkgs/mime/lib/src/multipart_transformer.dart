// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'bound_multipart_stream.dart';
import 'char_code.dart' as char_code;
import 'mime_shared.dart';

Uint8List _getBoundary(String boundary) {
  final charCodes = boundary.codeUnits;

  final boundaryList = Uint8List(4 + charCodes.length);
  // Set-up the matching boundary preceding it with CRLF and two
  // dashes.
  boundaryList[0] = char_code.cr;
  boundaryList[1] = char_code.lf;
  boundaryList[2] = char_code.dash;
  boundaryList[3] = char_code.dash;
  boundaryList.setRange(4, 4 + charCodes.length, charCodes);
  return boundaryList;
}

/// Parser for MIME multipart types of data as described in RFC 2046
/// section 5.1.1. The data is transformed into [MimeMultipart] objects, each
/// of them streaming the multipart data.
class MimeMultipartTransformer
    extends StreamTransformerBase<List<int>, MimeMultipart> {
  /// Default byte limit on the headers of each multipart part.
  static const int defaultHeaderSizeLimit = 64 * 1024;

  final List<int> _boundary;
  final int _headerSizeLimit;

  /// Construct a new MIME multipart parser with the boundary [boundary].
  ///
  /// The boundary should be as specified in the content
  /// type parameter, that is without the -- prefix.
  ///
  /// If [headerSizeLimit] is provided, that is the limit
  /// on the total byte-size of the header of a multi-part part.
  /// The [headerSizeLimit] must be non-negative.
  /// If it is zero (or very low), no headers can be accepted.
  /// Default is 64K, the same default as the platform HTTP headers
  /// parser.
  MimeMultipartTransformer(String boundary, {int? headerSizeLimit})
      : _headerSizeLimit = headerSizeLimit == null
            ? defaultHeaderSizeLimit
            : RangeError.checkNotNegative(headerSizeLimit, 'headerSizeLimit'),
        _boundary = _getBoundary(boundary);

  @override
  Stream<MimeMultipart> bind(Stream<List<int>> stream) =>
      BoundMultipartStream(_boundary, stream, headerSizeLimit: _headerSizeLimit)
          .stream;
}
