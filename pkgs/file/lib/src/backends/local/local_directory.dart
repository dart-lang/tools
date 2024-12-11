// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../../file.dart';
import '../../common.dart' as common;
import '../../io.dart' as io;

import 'local_file_system_entity.dart';

/// [Directory] implementation that forwards all calls to `dart:io`.
class LocalDirectory extends LocalFileSystemEntity<LocalDirectory, io.Directory>
    with ForwardingDirectory<LocalDirectory>, common.DirectoryAddOnsMixin {
  /// Instantiates a new [LocalDirectory] tied to the specified file system
  /// and delegating to the specified [delegate].
  LocalDirectory(super.fs, super.delegate);

  @override
  String toString() => "LocalDirectory: '$path'";
}
