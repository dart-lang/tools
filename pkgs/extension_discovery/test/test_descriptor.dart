// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show JsonEncoder;
import 'dart:io' show Platform, Process;

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
export 'package:test_descriptor/test_descriptor.dart';

d.FileDescriptor json(String fileName, Object? json) =>
    d.file(fileName, JsonEncoder.withIndent('  ').convert(json));

d.FileDescriptor pubspec(Map<String, Object?> pubspec) =>
    json('pubspec.yaml', pubspec);

Uri fileUri(String path) => Uri.file(d.path(path));
Uri directoryUri(String path) => Uri.directory(d.path(path));

Future<String> dart([
  String? arg1,
  String? arg2,
  String? arg3,
  String? arg4,
  String? arg5,
  String? arg6,
  String? arg7,
  String? arg8,
]) async {
  final arguments = [
    if (arg1 != null) arg1,
    if (arg2 != null) arg2,
    if (arg3 != null) arg3,
    if (arg4 != null) arg4,
    if (arg5 != null) arg5,
    if (arg6 != null) arg6,
    if (arg7 != null) arg7,
    if (arg8 != null) arg8,
  ];
  final result = await Process.run(
    Platform.executable,
    arguments,
    workingDirectory: d.sandbox,
  );
  if (result.exitCode != 0) {
    print(result.stderr);
    print(result.stdout);
  }
  expect(result.exitCode, 0,
      reason: 'failed executing "dart ${arguments.join(' ')}"');
  return result.stdout as String;
}

Future<String> dartPubGet(String folder) async =>
    await dart('pub', 'get', '-C', d.path('myapp'));
