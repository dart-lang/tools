// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Exit code constants.
///
/// [Source](https://www.freebsd.org/cgi/man.cgi?query=sysexits).
enum ExitCode {
  /// Command completed successfully.
  success(0),

  /// Command was used incorrectly.
  ///
  /// This may occur if the wrong number of arguments was used, a bad flag, or
  /// bad syntax in a parameter.
  usage(64),

  /// Input data was used incorrectly.
  ///
  /// This should occur only for user data (not system files).
  data(65),

  /// An input file (not a system file) did not exist or was not readable.
  noInput(66),

  /// User specified did not exist.
  noUser(67),

  /// Host specified did not exist.
  noHost(68),

  /// A service is unavailable.
  ///
  /// This may occur if a support program or file does not exist. This may also
  /// be used as a catch-all error when something you wanted to do does not
  /// work, but you do not know why.
  unavailable(69),

  /// An internal software error has been detected.
  ///
  /// This should be limited to non-operating system related errors as possible.
  software(70),

  /// An operating system error has been detected.
  ///
  /// This intended to be used for such thing as `cannot fork` or `cannot pipe`.
  osError(71),

  /// Some system file (e.g. `/etc/passwd`) does not exist or could not be read.
  osFile(72),

  /// A (user specified) output file cannot be created.
  cantCreate(73),

  /// An error occurred doing I/O on some file.
  ioError(74),

  /// Temporary failure, indicating something is not really an error.
  ///
  /// In some cases, this can be re-attempted and will succeed later.
  tempFail(75),

  /// You did not have sufficient permissions to perform the operation.
  ///
  /// This is not intended for file system problems, which should use [noInput]
  /// or [cantCreate], but rather for higher-level permissions.
  noPerm(77),

  /// Something was found in an unconfigured or misconfigured state.
  config(78);

  /// Exit code value.
  final int code;

  const ExitCode(this.code);

  @override
  String toString() => '$name: $code';
}
