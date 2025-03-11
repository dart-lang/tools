// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// dart:io dependent functionality for reading and writing configuration files.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'errors.dart';
import 'package_config.dart';
import 'package_config_json.dart';
import 'util_io.dart';

/// Name of directory where Dart tools store their configuration.
///
/// Directory is created in the package root directory.
const dartToolDirName = '.dart_tool';

/// Name of file containing new package configuration data.
///
/// File is stored in the dart tool directory.
const packageConfigFileName = 'package_config.json';

/// Reads a package configuration file.
///
/// The file must exist and be a normal file.
Future<PackageConfig> readConfigFile(
  File file,
  void Function(Object error) onError,
) async {
  Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (e) {
    onError(e);
    return const SimplePackageConfig.empty();
  }
  return parsePackageConfigBytes(bytes, file.uri, onError);
}

/// Like [readConfigFile] but uses a URI and an optional loader.
Future<PackageConfig> readConfigFileUri(
  Uri file,
  Future<Uint8List?> Function(Uri uri)? loader,
  void Function(Object error) onError,
) async {
  if (file.isScheme('package')) {
    throw PackageConfigArgumentError(
      file,
      'file',
      'Must not be a package: URI',
    );
  }
  if (loader == null) {
    if (file.isScheme('file')) {
      return await readConfigFile(File.fromUri(file), onError);
    }
    loader = defaultLoader;
  }

  Uint8List? bytes;
  try {
    bytes = await loader(file);
  } catch (e) {
    onError(e);
    return const SimplePackageConfig.empty();
  }
  if (bytes == null) {
    onError(
      PackageConfigArgumentError(
        file.toString(),
        'file',
        'File cannot be read',
      ),
    );
    return const SimplePackageConfig.empty();
  }
  return parsePackageConfigBytes(bytes, file, onError);
}

Future<PackageConfig> readPackageConfigJsonFile(
  File file,
  void Function(Object error) onError,
) async {
  Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (error) {
    onError(error);
    return const SimplePackageConfig.empty();
  }
  return parsePackageConfigBytes(bytes, file.uri, onError);
}

Future<void> writePackageConfigJsonFile(
  PackageConfig config,
  Directory targetDirectory,
) async {
  // Write .dart_tool/package_config.json first.
  var dartToolDir = Directory(pathJoin(targetDirectory.path, dartToolDirName));
  await dartToolDir.create(recursive: true);
  var file = File(pathJoin(dartToolDir.path, packageConfigFileName));
  var baseUri = file.uri;

  var sink = file.openWrite(encoding: utf8);
  writePackageConfigJsonUtf8(config, baseUri, sink);
  await sink.close();
}
