// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mime/mime.dart';
import 'package:mime/src/default_extension_map.dart';
import 'package:test/test.dart';

void main() {
  test('valid-mime-type', () {
    expect(extensionFromMime('text/x-dart'), equals('dart'));
    expect(extensionFromMime('text/javascript'), equals('js'));
    expect(extensionFromMime('application/java-archive'), equals('jar'));
    expect(extensionFromMime('application/json'), equals('json'));
    expect(extensionFromMime('application/pdf'), equals('pdf'));
    expect(extensionFromMime('application/vnd.ms-excel'), equals('xls'));
    expect(extensionFromMime('application/xhtml+xml'), equals('xhtml'));
    expect(extensionFromMime('image/jpeg'), equals('jpg'));
    expect(extensionFromMime('image/png'), equals('png'));
    expect(extensionFromMime('text/css'), equals('css'));
    expect(extensionFromMime('text/html'), equals('html'));
    expect(extensionFromMime('text/plain'), equals('txt'));
    expect(extensionFromMime('text/x-c'), equals('c'));
    expect(extensionFromMime('audio/mpeg'), equals('mp3'));
  });

  test('invalid-mime-type', () {
    expect(extensionFromMime('invalid-mime-type'), isNull);
    expect(extensionFromMime('invalid/mime/type'), isNull);
  });

  test('unknown-mime-type', () {
    expect(extensionFromMime('application/to-be-invented'), isNull);
  });

  test('fallback-mime-type-missing-implementations', () {
    final mimeTypesUsedCounter = <String, int>{};
    for (final mimeType in defaultExtensionMap.values) {
      final current = mimeTypesUsedCounter[mimeType];
      if (current == null) {
        mimeTypesUsedCounter[mimeType] = 1;
      } else {
        mimeTypesUsedCounter[mimeType] = current + 1;
      }
    }
    final requiresOverride = mimeTypesUsedCounter.entries
        .where((e) => e.value > 1)
        .map((e) => e.key);
    final missingOverrides = requiresOverride
        .where((e) => !defaultMimeTypeFallbackMap.containsKey(e));
    expect(missingOverrides, isEmpty,
        reason: 'missing overrides of mime types for $missingOverrides');
  });

  test('overridden-type-not-in-map', () {
    for (final mimeType in defaultMimeTypeFallbackMap.entries) {
      expect(defaultExtensionMap[mimeType.value], mimeType.key,
          reason: 'override is missing in original map');
    }
  });
}
