// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:mime/mime.dart';
import 'package:mime/src/magic_numbers.dart';
import 'package:test/test.dart';

void _expectMimeType(String path, String? expectedMimeType,
    {List<int>? headerBytes, MimeTypeResolver? resolver}) {
  String? mimeType;
  if (resolver == null) {
    mimeType = lookupMimeType(path, headerBytes: headerBytes);
  } else {
    mimeType = resolver.lookup(path, headerBytes: headerBytes);
  }

  expect(mimeType, expectedMimeType);
}

void main() {
  group('global-lookup', () {
    test('by-path', () {
      _expectMimeType('file.dart', 'text/x-dart');
      // Test mixed-case
      _expectMimeType('file.DaRT', 'text/x-dart');
      _expectMimeType('file.html', 'text/html');
      _expectMimeType('file.xhtml', 'application/xhtml+xml');
      _expectMimeType('file.jpeg', 'image/jpeg');
      _expectMimeType('file.jpg', 'image/jpeg');
      _expectMimeType('file.png', 'image/png');
      _expectMimeType('file.gif', 'image/gif');
      _expectMimeType('file.cc', 'text/x-c');
      _expectMimeType('file.c', 'text/x-c');
      _expectMimeType('file.css', 'text/css');
      _expectMimeType('file.js', 'text/javascript');
      _expectMimeType('file.mjs', 'text/javascript');
      _expectMimeType('file.ps', 'application/postscript');
      _expectMimeType('file.pdf', 'application/pdf');
      _expectMimeType('file.tiff', 'image/tiff');
      _expectMimeType('file.tif', 'image/tiff');
      _expectMimeType('file.webp', 'image/webp');
      _expectMimeType('file.mp3', 'audio/mpeg');
      _expectMimeType('file.aac', 'audio/x-aac');
      _expectMimeType('file.ogg', 'audio/ogg');
      _expectMimeType('file.aiff', 'audio/x-aiff');
      _expectMimeType('file.m4a', 'audio/mp4');
      _expectMimeType('file.md', 'text/markdown');
      _expectMimeType('file.markdown', 'text/markdown');
    });

    test('unknown-mime-type', () {
      _expectMimeType('file.unsupported-extension', null);
    });

    test('by-header-bytes', () {
      _expectMimeType('file.jpg', 'image/png',
          headerBytes: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      _expectMimeType('file.jpg', 'image/gif', headerBytes: [
        0x47,
        0x49,
        0x46,
        0x38,
        0x39,
        0x61,
        0x0D,
        0x0A,
        0x1A,
        0x0A
      ]);
      _expectMimeType('file.gif', 'image/jpeg', headerBytes: [
        0xFF,
        0xD8,
        0x46,
        0x38,
        0x39,
        0x61,
        0x0D,
        0x0A,
        0x1A,
        0x0A
      ]);
      _expectMimeType('file', 'video/3gpp', headerBytes: [
        0x00,
        0x00,
        0x00,
        0x04,
        0x66,
        0x74,
        0x79,
        0x70,
        0x33,
        0x67,
        0x70,
        0x35
      ]);
      _expectMimeType('file.mp4', 'video/mp4', headerBytes: [
        0x00,
        0x00,
        0x00,
        0x04,
        0x66,
        0x74,
        0x79,
        0x70,
        0xFF,
        0xFF,
        0xFF,
        0xFF
      ]);
      _expectMimeType('file', 'video/mp4', headerBytes: [
        0x00,
        0xF0,
        0xF0,
        0xF0,
        0x66,
        0x74,
        0x79,
        0x70,
        0x61,
        0x76,
        0x63,
        0x31
      ]);
      _expectMimeType('file', 'video/mp4', headerBytes: [
        0x00,
        0xF0,
        0xF0,
        0xF0,
        0x66,
        0x74,
        0x79,
        0x70,
        0x69,
        0x73,
        0x6F,
        0x32
      ]);
      _expectMimeType('file', 'video/mp4', headerBytes: [
        0x00,
        0xF0,
        0xF0,
        0xF0,
        0x66,
        0x74,
        0x79,
        0x70,
        0x69,
        0x73,
        0x6F,
        0x6D
      ]);
      _expectMimeType('file', 'video/mp4', headerBytes: [
        0x00,
        0xF0,
        0xF0,
        0xF0,
        0x66,
        0x74,
        0x79,
        0x70,
        0x6D,
        0x70,
        0x34,
        0x31
      ]);
      _expectMimeType('file', 'video/mp4', headerBytes: [
        0x00,
        0xF0,
        0xF0,
        0xF0,
        0x66,
        0x74,
        0x79,
        0x70,
        0x6D,
        0x70,
        0x34,
        0x32
      ]);
      _expectMimeType('file', 'image/webp', headerBytes: [
        0x52,
        0x49,
        0x46,
        0x46,
        0xE2,
        0x4A,
        0x01,
        0x00,
        0x57,
        0x45,
        0x42,
        0x50
      ]);
      _expectMimeType('file', 'audio/mpeg',
          headerBytes: [0x49, 0x44, 0x33, 0x0D, 0x0A, 0x1A, 0x0A]);
      _expectMimeType('file', 'audio/aac',
          headerBytes: [0xFF, 0xF1, 0x0D, 0x0A, 0x1A, 0x0A]);
      _expectMimeType('file', 'audio/ogg',
          headerBytes: [0x4F, 0x70, 0x75, 0x0D, 0x0A, 0x1A, 0x0A]);
      _expectMimeType('file', 'audio/x-aiff', headerBytes: [
        0x46,
        0x4F,
        0x52,
        0x4D,
        0x04,
        0x0B,
        0xEF,
        0xF4,
        0x41,
        0x49,
        0x46,
        0x46
      ]);
      _expectMimeType('file', 'audio/x-flac',
          headerBytes: [0x66, 0x4C, 0x61, 0x43]);
      _expectMimeType('file', 'audio/x-wav', headerBytes: [
        0x52,
        0x49,
        0x46,
        0x46,
        0xA6,
        0x4E,
        0x70,
        0x03,
        0x57,
        0x41,
        0x56,
        0x45
      ]);
      _expectMimeType('file', 'image/heic', headerBytes: [
        0x00,
        0x00,
        0x00,
        0x18,
        0x66,
        0x74,
        0x79,
        0x70,
        0x68,
        0x65,
        0x69,
        0x63,
        0x00
      ]);
      _expectMimeType('file', 'image/heic', headerBytes: [
        0x00,
        0x00,
        0x00,
        0x18,
        0x66,
        0x74,
        0x79,
        0x70,
        0x68,
        0x65,
        0x69,
        0x78,
        0x00
      ]);
      _expectMimeType('file', 'image/heif', headerBytes: [
        0x00,
        0x00,
        0x00,
        0x18,
        0x66,
        0x74,
        0x79,
        0x70,
        0x6D,
        0x69,
        0x66,
        0x31,
        0x00
      ]);
    });
  });

  group('custom-resolver', () {
    test('override-extension', () {
      final resolver = MimeTypeResolver();
      resolver.addExtension('jpg', 'my-mime-type');
      _expectMimeType('file.jpg', 'my-mime-type', resolver: resolver);
    });

    test('fallthrough-extension', () {
      final resolver = MimeTypeResolver();
      resolver.addExtension('jpg2', 'my-mime-type');
      _expectMimeType('file.jpg', 'image/jpeg', resolver: resolver);
    });

    test('with-mask', () {
      final resolver = MimeTypeResolver.empty();
      resolver.addMagicNumber([0x01, 0x02, 0x03], 'my-mime-type',
          mask: [0x01, 0xFF, 0xFE]);
      _expectMimeType('file', 'my-mime-type',
          headerBytes: [0x01, 0x02, 0x03], resolver: resolver);
      _expectMimeType('file', null,
          headerBytes: [0x01, 0x03, 0x03], resolver: resolver);
      _expectMimeType('file', 'my-mime-type',
          headerBytes: [0xFF, 0x02, 0x02], resolver: resolver);
    });
  });

  test('default magic number', () {
    final actualMaxBytes = initialMagicNumbers.fold<int>(
      0,
      (previous, magic) => math.max(previous, magic.numbers.length),
    );

    expect(initialMagicNumbersMaxLength, actualMaxBytes);
  });
}
