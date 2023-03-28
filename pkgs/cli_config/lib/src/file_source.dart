// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'source.dart';

class FileSource extends Source {
  /// Configuration options passed in via a JSON or YAML configuration file.
  ///
  /// Stored as a partial hierarchical data structure. The values can be maps
  /// in which subsequent parts of a key after a `.` can be resolved.
  final Map<String, dynamic> _file;

  /// If provided, used to resolve paths within [_file].
  @override
  final Uri? baseUri;

  FileSource(this._file, this.baseUri);

  @override
  String? getOptionalString(String key) => getOptionalValueOf<String>(key);

  @override
  List<String>? getOptionalStringList(
    String key, {
    String? splitPattern,
  }) {
    assert(splitPattern == null);
    return getOptionalValueOf<List<dynamic>>(key)?.cast<String>();
  }

  @override
  bool? getOptionalBool(String key) => getOptionalValueOf<bool>(key);

  @override
  T? getOptionalValueOf<T>(String key) {
    Object? cursor = _file;
    var current = '';
    for (final keyPart in key.split('.')) {
      if (cursor == null) {
        return null;
      }
      if (cursor is! Map) {
        throw FormatException(
            "Unexpected value '$cursor' for key '$current' in config file. "
            'Expected a Map.');
      } else {
        cursor = cursor[keyPart];
      }
      current += '.$keyPart';
    }
    if (cursor is! T?) {
      throw FormatException(
          "Unexpected value '$cursor' for key '$current' in config file. "
          'Expected a $T.');
    }
    return cursor;
  }

  @override
  String toString() => 'FileSource(file: $_file, fileUri: $baseUri)';
}
