// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: comment_references

/// A file system operation used by the [MemoryFileSytem] to allow
/// tests to insert errors for certain operations.
///
/// This is not implemented as an enum to allow new values to be added in a
/// backwards compatible manner.
class FileSystemOp {
  const FileSystemOp._(this._value);

  // This field added to ensure const values can be different.
  // ignore: unused_field
  final int _value;

  /// A file system operation used for all read methods.
  ///
  /// * [FileSystemEntity.readAsString]
  /// * [FileSystemEntity.readAsStringSync]
  /// * [FileSystemEntity.readAsBytes]
  /// * [FileSystemEntity.readAsBytesSync]
  static const FileSystemOp read = FileSystemOp._(0);

  /// A file system operation used for all write methods.
  ///
  /// * [FileSystemEntity.writeAsString]
  /// * [FileSystemEntity.writeAsStringSync]
  /// * [FileSystemEntity.writeAsBytes]
  /// * [FileSystemEntity.writeAsBytesSync]
  static const FileSystemOp write = FileSystemOp._(1);

  /// A file system operation used for all delete methods.
  ///
  /// * [FileSystemEntity.delete]
  /// * [FileSystemEntity.deleteSync]
  static const FileSystemOp delete = FileSystemOp._(2);

  /// A file system operation used for all create methods.
  ///
  /// * [FileSystemEntity.create]
  /// * [FileSystemEntity.createSync]
  static const FileSystemOp create = FileSystemOp._(3);

  /// A file operation used for all open methods.
  ///
  /// * [File.open]
  /// * [File.openSync]
  /// * [File.openRead]
  /// * [File.openWrite]
  static const FileSystemOp open = FileSystemOp._(4);

  /// A file operation used for all copy methods.
  ///
  /// * [File.copy]
  /// * [File.copySync]
  static const FileSystemOp copy = FileSystemOp._(5);

  /// A file system operation used for all exists methods.
  ///
  /// * [FileSystemEntity.exists]
  /// * [FileSystemEntity.existsSync]
  static const FileSystemOp exists = FileSystemOp._(6);

  @override
  String toString() {
    return switch (_value) {
      0 => 'FileSystemOp.read',
      1 => 'FileSystemOp.write',
      2 => 'FileSystemOp.delete',
      3 => 'FileSystemOp.create',
      4 => 'FileSystemOp.open',
      5 => 'FileSystemOp.copy',
      6 => 'FileSystemOp.exists',
      _ => throw StateError('Invalid FileSytemOp type: $this')
    };
  }
}
