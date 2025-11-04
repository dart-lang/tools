// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// General superclass of most errors and exceptions thrown by this package.
///
/// Only covers errors thrown while parsing package configuration files.
/// Programming errors and I/O exceptions are not covered.
abstract interface class PackageConfigError {}

class PackageConfigArgumentError extends ArgumentError
  implements PackageConfigError {
 
  new( // Cannot be primary, `.from` cannot redirect to these types.
    Object? super.value,
    String super.name,
    String super.message,
  ) : super.value(); 
    
  new from(ArgumentError error)
    : super.value(error.invalidValue, error.name, error.message);
}

class PackageConfigFormatException(
    super.message,
    Object? super.source, [
    super.offset,
  ]) extends FormatException
     implements PackageConfigError {

  new from(FormatException exception)
    : this(exception.message, exception.source, exception.offset);
}

/// The default `onError` handler.
// ignore: only_throw_errors
Never throwError(Object error) => throw error;
