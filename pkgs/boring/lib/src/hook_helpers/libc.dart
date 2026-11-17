// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi';

/// The oldest glibc that the prebuilt Linux libraries run on.
///
/// Keep in sync with `max-glibc` of the Linux targets in
/// `.github/workflows/boring_binaries.yaml`, which checks the libraries.
const prebuiltLinuxGlibc = (2, 28);

/// The version of the GNU C library (glibc) of this process, or `null` if the
/// process doesn't use glibc, for example on Alpine Linux, which uses musl.
(int, int)? currentGlibcVersion() {
  final process = DynamicLibrary.process();
  if (!process.providesSymbol('gnu_get_libc_version')) {
    return null;
  }
  final gnuGetLibcVersion = process
      .lookupFunction<Pointer<Uint8> Function(), Pointer<Uint8> Function()>(
        'gnu_get_libc_version',
      );
  final version = gnuGetLibcVersion();
  final bytes = <int>[];
  for (var i = 0; version[i] != 0; i++) {
    bytes.add(version[i]);
  }
  return parseGlibcVersion(String.fromCharCodes(bytes));
}

/// Parses the major and minor version from a glibc version string, such as
/// `2.35` or `2.39.9000`.
(int, int)? parseGlibcVersion(String version) {
  final match = RegExp(r'^(\d+)\.(\d+)').firstMatch(version);
  if (match == null) {
    return null;
  }
  return (int.parse(match[1]!), int.parse(match[2]!));
}

/// Why the prebuilt Linux libraries can't run with the C library
/// [glibcVersion] (see [currentGlibcVersion]), or `null` if they can.
String? unsupportedLinuxLibcReason((int, int)? glibcVersion) {
  final (minMajor, minMinor) = prebuiltLinuxGlibc;
  if (glibcVersion == null) {
    return 'The prebuilt Linux libraries require glibc, but this system uses '
        'another C library, such as musl on Alpine Linux.';
  }
  final (major, minor) = glibcVersion;
  if (major < minMajor || (major == minMajor && minor < minMinor)) {
    return 'The prebuilt Linux libraries require glibc $minMajor.$minMinor or '
        'newer, but this system has glibc $major.$minor.';
  }
  return null;
}
