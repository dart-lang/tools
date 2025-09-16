// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

const int initialMagicNumbersMaxLength = 12;

class MagicNumber {
  final String mimeType;
  final String numbers;
  final String? masks;

  const MagicNumber(this.mimeType, this.numbers, [this.masks]);

  bool matches(List<int> header) {
    if (header.length < numbers.length) return false;

    for (var i = 0; i < numbers.length; i++) {
      final number = numbers.codeUnitAt(i);
      if (masks != null) {
        final mask = masks!.codeUnitAt(i);
        if ((mask & number) != (mask & header[i])) return false;
      } else {
        if (number != header[i]) return false;
      }
    }

    return true;
  }
}

const List<MagicNumber> initialMagicNumbers = [
  MagicNumber('application/pdf', '\x25\x50\x44\x46'),
  MagicNumber('application/postscript', '\x25\x51'),

  /// AIFF is based on the EA IFF 85 Standard for Interchange Format Files.
  /// -> 4 bytes have the ASCII characters 'F' 'O' 'R' 'M'.
  /// -> 4 bytes indicating the size of the file
  /// -> 4 bytes have the ASCII characters 'A' 'I' 'F' 'F'.
  /// http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/AIFF/Docs/AIFF-1.3.pdf
  MagicNumber(
    'audio/x-aiff',
    '\x46\x4F\x52\x4D\x00\x00\x00\x00\x41\x49\x46\x46',
    '\xFF\xFF\xFF\xFF\x00\x00\x00\x00\xFF\xFF\xFF\xFF',
  ),

  /// -> 4 bytes have the ASCII characters 'f' 'L' 'a' 'C'.
  /// https://xiph.org/flac/format.html
  MagicNumber('audio/x-flac', '\x66\x4C\x61\x43'),

  /// The WAVE file format is based on the RIFF document format.
  /// -> 4 bytes have the ASCII characters 'R' 'I' 'F' 'F'.
  /// -> 4 bytes indicating the size of the file
  /// -> 4 bytes have the ASCII characters 'W' 'A' 'V' 'E'.
  /// http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/Docs/riffmci.pdf
  MagicNumber(
    'audio/x-wav',
    '\x52\x49\x46\x46\x00\x00\x00\x00\x57\x41\x56\x45',
    '\xFF\xFF\xFF\xFF\x00\x00\x00\x00\xFF\xFF\xFF\xFF',
  ),
  MagicNumber('image/gif', '\x47\x49\x46\x38\x37\x61'),
  MagicNumber('image/gif', '\x47\x49\x46\x38\x39\x61'),
  MagicNumber('image/jpeg', '\xFF\xD8'),
  MagicNumber('image/png', '\x89\x50\x4E\x47\x0D\x0A\x1A\x0A'),
  MagicNumber('image/tiff', '\x49\x49\x2A\x00'),
  MagicNumber('image/tiff', '\x4D\x4D\x00\x2A'),
  MagicNumber('audio/aac', '\xFF\xF1'),
  MagicNumber('audio/aac', '\xFF\xF9'),
  MagicNumber('audio/weba', '\x1A\x45\xDF\xA3'),
  MagicNumber('audio/mpeg', '\x49\x44\x33'),
  MagicNumber('audio/mpeg', '\xFF\xFB'),
  MagicNumber('audio/ogg', '\x4F\x70\x75'),
  MagicNumber(
    'video/3gpp',
    '\x00\x00\x00\x00\x66\x74\x79\x70\x33\x67\x70\x35',
    '\xFF\xFF\xFF\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF',
  ),
  MagicNumber(
    'video/mp4',
    '\x00\x00\x00\x00\x66\x74\x79\x70\x61\x76\x63\x31',
    '\x00\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF',
  ),
  MagicNumber(
    'video/mp4',
    '\x00\x00\x00\x00\x66\x74\x79\x70\x69\x73\x6F\x32',
    '\x00\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF',
  ),
  MagicNumber(
    'video/mp4',
    '\x00\x00\x00\x00\x66\x74\x79\x70\x69\x73\x6F\x6D',
    '\x00\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF',
  ),
  MagicNumber(
    'video/mp4',
    '\x00\x00\x00\x00\x66\x74\x79\x70\x6D\x70\x34\x31',
    '\x00\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF',
  ),
  MagicNumber(
    'video/mp4',
    '\x00\x00\x00\x00\x66\x74\x79\x70\x6D\x70\x34\x32',
    '\x00\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF',
  ),
  MagicNumber('model/gltf-binary', '\x46\x54\x6C\x67'),

  /// The WebP file format is based on the RIFF document format.
  /// -> 4 bytes have the ASCII characters 'R' 'I' 'F' 'F'.
  /// -> 4 bytes indicating the size of the file
  /// -> 4 bytes have the ASCII characters 'W' 'E' 'B' 'P'.
  /// https://developers.google.com/speed/webp/docs/riff_container
  MagicNumber(
    'image/webp',
    '\x52\x49\x46\x46\x00\x00\x00\x00\x57\x45\x42\x50',
    '\xFF\xFF\xFF\xFF\x00\x00\x00\x00\xFF\xFF\xFF\xFF',
  ),

  MagicNumber('font/woff2', '\x77\x4f\x46\x32'),

  /// High Efficiency Image File Format (ISO/IEC 23008-12).
  /// -> 4 bytes indicating the ftyp box length.
  /// -> 4 bytes have the ASCII characters 'f' 't' 'y' 'p'.
  /// -> 4 bytes have the ASCII characters 'h' 'e' 'i' 'c'.
  /// https://www.iana.org/assignments/media-types/image/heic
  MagicNumber(
    'image/heic',
    '\x00\x00\x00\x00\x66\x74\x79\x70\x68\x65\x69\x63',
    '\x00\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF',
  ),

  /// -> 4 bytes indicating the ftyp box length.
  /// -> 4 bytes have the ASCII characters 'f' 't' 'y' 'p'.
  /// -> 4 bytes have the ASCII characters 'h' 'e' 'i' 'x'.
  MagicNumber(
    'image/heic',
    '\x00\x00\x00\x00\x66\x74\x79\x70\x68\x65\x69\x78',
    '\x00\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF',
  ),

  /// -> 4 bytes indicating the ftyp box length.
  /// -> 4 bytes have the ASCII characters 'f' 't' 'y' 'p'.
  /// -> 4 bytes have the ASCII characters 'm' 'i' 'f' '1'.
  MagicNumber(
    'image/heif',
    '\x00\x00\x00\x00\x66\x74\x79\x70\x6D\x69\x66\x31',
    '\x00\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF',
  ),
];
