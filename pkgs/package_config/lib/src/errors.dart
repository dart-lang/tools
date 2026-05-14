// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../package_config.dart';

/// General superclass of most errors and exceptions thrown by this package.
///
/// Only covers errors thrown while parsing package configuration files.
/// Programming errors and I/O exceptions are not covered.
abstract class PackageConfigError {
  PackageConfigError._();
}

class PackageConfigArgumentError extends ArgumentError
    implements PackageConfigError {
  PackageConfigArgumentError(
    Object? super.value,
    String super.name,
    String super.message,
  ) : super.value();

  PackageConfigArgumentError.from(ArgumentError error)
    : super.value(error.invalidValue, error.name, error.message);
}

class PackageConfigFormatException extends FormatException
    implements PackageConfigError {
  PackageConfigFormatException(
    super.message,
    Object? super.source, [
    super.offset,
  ]);

  PackageConfigFormatException.from(FormatException exception)
    : super(exception.message, exception.source, exception.offset);
}

/// Exception reported when finding a configuration with an unaccepted version.
///
/// Used by [findPackageConfig] and similar functions if specifying a
/// `minVersion`, or by parsing if finding a package configuration file
/// with a version that is not in the range
/// [PackageConfig.minVersion]..[PackageConfig.maxVersion].
abstract class PackageConfigVersionException {
  abstract final int actualVersion;
  abstract final int? minVersion;
  abstract final int? maxVersion;

  factory PackageConfigVersionException.clientLimit(
    int actualVersion,
    int? minVersion,
    int? maxVersion,
  ) = _PackageConfigVersionFormatException;

  factory PackageConfigVersionException.supportedLimit(
    int actualVersion,
    String keyName,
  ) = _PackageConfigVersionArgumentError;

  static String _rangeMessage(int actual, int? minVersion, int? maxVersion) {
    String errorMessage;
    if (minVersion != null) {
      if (maxVersion != null) {
        errorMessage =
            minVersion == maxVersion
                ? 'Must be $minVersion'
                : 'Must be in the range $minVersion..$maxVersion';
      } else {
        errorMessage = 'Must be at least $minVersion';
      }
    } else if (maxVersion != null) {
      errorMessage = 'Must be at most $maxVersion';
    } else {
      errorMessage = 'Not accepted';
    }
    return 'Configuration version $actual: $errorMessage';
  }
}

/// Error when configuration specifies an unsupported configuration version.
class _PackageConfigVersionArgumentError extends PackageConfigArgumentError
    implements PackageConfigVersionException {
  _PackageConfigVersionArgumentError(int actualVersion, String name)
    : super(
        actualVersion,
        name,
        PackageConfigVersionException._rangeMessage(
          actualVersion,
          PackageConfig.minVersion,
          PackageConfig.maxVersion,
        ),
      );
  @override
  int get actualVersion => super.invalidValue as int;
  @override
  int get minVersion => PackageConfig.minVersion;
  @override
  int get maxVersion => PackageConfig.maxVersion;
}

/// Exception when found configuration doesn't match client's set limits.
class _PackageConfigVersionFormatException extends PackageConfigFormatException
    implements PackageConfigVersionException {
  @override
  final int actualVersion;
  @override
  final int? minVersion;
  @override
  final int? maxVersion;
  _PackageConfigVersionFormatException(
    this.actualVersion,
    this.minVersion,
    this.maxVersion,
  ) : super(
        PackageConfigVersionException._rangeMessage(
          actualVersion,
          minVersion,
          maxVersion,
        ),
        null,
      );
}

/// The default `onError` handler.
// ignore: only_throw_errors
Never throwError(Object error, [Object? _]) => throw error;
