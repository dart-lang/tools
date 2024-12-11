// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: comment_references

import 'dart:io';

import 'package:test/test.dart';

import 'internal.dart';

/// Matcher that successfully matches against any instance of [Directory].
const isDirectory = TypeMatcher<Directory>();

/// Matcher that successfully matches against any instance of [File].
const isFile = TypeMatcher<File>();

/// Matcher that successfully matches against any instance of [Link].
const isLink = TypeMatcher<Link>();

/// Matcher that successfully matches against any instance of
/// [FileSystemEntity].
const isFileSystemEntity = TypeMatcher<FileSystemEntity>();

/// Matcher that successfully matches against any instance of [FileStat].
const isFileStat = TypeMatcher<FileStat>();

/// Returns a [Matcher] that matches [path] against an entity's path.
///
/// [path] may be a String, a predicate function, or a [Matcher]. If it is
/// a String, it will be wrapped in an equality matcher.
TypeMatcher<FileSystemEntity> hasPath(dynamic path) =>
    isFileSystemEntity.having((e) => e.path, 'path', path);

/// Returns a [Matcher] that successfully matches against an instance of
/// [FileSystemException].
///
/// If [osErrorCode] is specified, matches will be limited to exceptions whose
/// `osError.errorCode` also match the specified matcher.
///
/// [osErrorCode] may be an `int`, a predicate function, or a [Matcher]. If it
/// is an `int`, it will be wrapped in an equality matcher.
Matcher isFileSystemException([dynamic osErrorCode]) =>
    const TypeMatcher<FileSystemException>().having(
        (e) => e.osError, 'orError', _fileExceptionWrapMatcher(osErrorCode));

/// Returns a matcher that successfully matches against a future or function
/// that throws a [FileSystemException].
///
/// If [osErrorCode] is specified, matches will be limited to exceptions whose
/// `osError.errorCode` also match the specified matcher.
///
/// [osErrorCode] may be an `int`, a predicate function, or a [Matcher]. If it
/// is an `int`, it will be wrapped in an equality matcher.
Matcher throwsFileSystemException([dynamic osErrorCode]) =>
    throwsA(isFileSystemException(osErrorCode));

/// Expects the specified [callback] to throw a [FileSystemException] with the
/// specified [osErrorCode] (matched against the exception's
/// `osError.errorCode`).
///
/// [osErrorCode] may be an `int`, a predicate function, or a [Matcher]. If it
/// is an `int`, it will be wrapped in an equality matcher.
///
/// See also:
///   - [ErrorCodes]
void expectFileSystemException(dynamic osErrorCode, void Function() callback) {
  expect(callback, throwsFileSystemException(osErrorCode));
}

/// Matcher that successfully matches against a [FileSystemEntity] that
/// exists ([FileSystemEntity.existsSync] returns true).
final TypeMatcher exists =
    isFileSystemEntity.having((e) => e.existsSync(), 'existsSync', true);

Matcher? _fileExceptionWrapMatcher(dynamic osErrorCode) =>
    (osErrorCode == null || ignoreOsErrorCodes)
        ? anything
        : wrapMatcher(osErrorCode);
