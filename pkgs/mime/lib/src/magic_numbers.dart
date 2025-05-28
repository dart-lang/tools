// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

const int initialMagicNumbersMaxLength = 12;

class MagicNumber {
  final String mimeType;
  final List<int> numbers;
  final List<int>? mask;

  const MagicNumber(this.mimeType, this.numbers, {this.mask});

  bool matches(List<int> header) {
    if (header.length < numbers.length) return false;

    for (var i = 0; i < numbers.length; i++) {
      if (mask != null) {
        if ((mask![i] & numbers[i]) != (mask![i] & header[i])) return false;
      } else {
        if (numbers[i] != header[i]) return false;
      }
    }

    return true;
  }
}

final List<MagicNumber> initialMagicNumbers = [
  MagicNumber('application/pdf', hex('25504446')),
  MagicNumber('application/postscript', hex('2551')),

  /// AIFF is based on the EA IFF 85 Standard for Interchange Format Files.
  /// -> 4 bytes have the ASCII characters 'F' 'O' 'R' 'M'.
  /// -> 4 bytes indicating the size of the file
  /// -> 4 bytes have the ASCII characters 'A' 'I' 'F' 'F'.
  /// http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/AIFF/Docs/AIFF-1.3.pdf
  MagicNumber(
    'audio/x-aiff',
    hex('464F524D0000000041494646'),
    mask: hex('FFFFFFFF00000000FFFFFFFF'),
  ),

  /// -> 4 bytes have the ASCII characters 'f' 'L' 'a' 'C'.
  /// https://xiph.org/flac/format.html
  MagicNumber('audio/x-flac', hex('664C6143')),

  /// The WAVE file format is based on the RIFF document format.
  /// -> 4 bytes have the ASCII characters 'R' 'I' 'F' 'F'.
  /// -> 4 bytes indicating the size of the file
  /// -> 4 bytes have the ASCII characters 'W' 'A' 'V' 'E'.
  /// http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/Docs/riffmci.pdf
  MagicNumber(
    'audio/x-wav',
    hex('524946460000000057415645'),
    mask: hex('FFFFFFFF00000000FFFFFFFF'),
  ),
  MagicNumber('image/gif', hex('474946383761')),
  MagicNumber('image/gif', hex('474946383961')),
  MagicNumber('image/jpeg', hex('FFD8')),
  MagicNumber('image/png', hex('89504E470D0A1A0A')),
  MagicNumber('image/tiff', hex('49492A00')),
  MagicNumber('image/tiff', hex('4D4D002A')),
  MagicNumber('audio/aac', hex('FFF1')),
  MagicNumber('audio/aac', hex('FFF9')),
  MagicNumber('audio/weba', hex('1A45DFA3')),
  MagicNumber('audio/mpeg', hex('494433')),
  MagicNumber('audio/mpeg', hex('FFFB')),
  MagicNumber('audio/ogg', hex('4F7075')),
  MagicNumber(
    'video/3gpp',
    hex('000000006674797033677035'),
    mask: hex('FFFFFF00FFFFFFFFFFFFFFFF'),
  ),
  MagicNumber(
    'video/mp4',
    hex('000000006674797061766331'),
    mask: hex('00000000FFFFFFFFFFFFFFFF'),
  ),
  MagicNumber(
    'video/mp4',
    hex('000000006674797069736F32'),
    mask: hex('00000000FFFFFFFFFFFFFFFF'),
  ),
  MagicNumber(
    'video/mp4',
    hex('000000006674797069736F6D'),
    mask: hex('00000000FFFFFFFFFFFFFFFF'),
  ),
  MagicNumber(
    'video/mp4',
    hex('00000000667479706D703431'),
    mask: hex('00000000FFFFFFFFFFFFFFFF'),
  ),
  MagicNumber(
    'video/mp4',
    hex('00000000667479706D703432'),
    mask: hex('00000000FFFFFFFFFFFFFFFF'),
  ),
  MagicNumber('model/gltf-binary', hex('46546C67')),

  /// The WebP file format is based on the RIFF document format.
  /// -> 4 bytes have the ASCII characters 'R' 'I' 'F' 'F'.
  /// -> 4 bytes indicating the size of the file
  /// -> 4 bytes have the ASCII characters 'W' 'E' 'B' 'P'.
  /// https://developers.google.com/speed/webp/docs/riff_container
  MagicNumber(
    'image/webp',
    hex('524946460000000057454250'),
    mask: hex('FFFFFFFF00000000FFFFFFFF'),
  ),

  MagicNumber('font/woff2', hex('774f4632')),

  /// High Efficiency Image File Format (ISO/IEC 23008-12).
  /// -> 4 bytes indicating the ftyp box length.
  /// -> 4 bytes have the ASCII characters 'f' 't' 'y' 'p'.
  /// -> 4 bytes have the ASCII characters 'h' 'e' 'i' 'c'.
  /// https://www.iana.org/assignments/media-types/image/heic
  MagicNumber(
    'image/heic',
    hex('000000006674797068656963'),
    mask: hex('00000000FFFFFFFFFFFFFFFF'),
  ),

  /// -> 4 bytes indicating the ftyp box length.
  /// -> 4 bytes have the ASCII characters 'f' 't' 'y' 'p'.
  /// -> 4 bytes have the ASCII characters 'h' 'e' 'i' 'x'.
  MagicNumber(
    'image/heic',
    hex('000000006674797068656978'),
    mask: hex('00000000FFFFFFFFFFFFFFFF'),
  ),

  /// -> 4 bytes indicating the ftyp box length.
  /// -> 4 bytes have the ASCII characters 'f' 't' 'y' 'p'.
  /// -> 4 bytes have the ASCII characters 'm' 'i' 'f' '1'.
  MagicNumber(
    'image/heif',
    hex('00000000667479706D696631'),
    mask: hex('00000000FFFFFFFFFFFFFFFF'),
  ),
];

Uint8List hex(String encoded) {
  final result = Uint8List(encoded.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    final offset = i * 2;
    result[i] = int.parse(encoded.substring(offset, offset + 2), radix: 16);
  }
  return result;
}
