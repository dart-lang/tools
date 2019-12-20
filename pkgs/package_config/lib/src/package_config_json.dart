// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "dart:convert";
import "dart:io";
import "dart:typed_data";

import 'package:charcode/ascii.dart';
import "package:path/path.dart" as path;

import "discovery.dart" show packageConfigJsonPath;
import "errors.dart";
import "package_config_impl.dart";
import "packages_file.dart" as packages_file;
import "util.dart";

const String _configVersionKey = "configVersion";
const String _packagesKey = "packages";
const List<String> _topNames = [_configVersionKey, _packagesKey];
const String _nameKey = "name";
const String _rootUriKey = "rootUri";
const String _packageUriKey = "packageUri";
const String _languageVersionKey = "languageVersion";
const List<String> _packageNames = [
  _nameKey,
  _rootUriKey,
  _packageUriKey,
  _languageVersionKey
];

const String _generatedKey = "generated";
const String _generatorKey = "generator";
const String _generatorVersionKey = "generatorVersion";

/// Reads a package configuration file.
///
/// Detects whether the [file] is a version one `.packages` file or
/// a version two `package_config.json` file.
///
/// If the [file] is a `.packages` file, first checks whether there is an
/// adjacent `.dart_tool/package_config.json` file, and if so,
/// reads that instead.
///
/// The file must exist and be a normal file.
Future<PackageConfig> readAnyConfigFile(File file) async {
  var bytes = await file.readAsBytes();
  int firstChar = firstNonWhitespaceChar(bytes);
  if (firstChar != $lbrace) {
    // Definitely not a JSON object, probably a .packages.
    var alternateFile = File(path.join(
        path.dirname(file.path), ".dart_tool", "package_config.json"));
    if (!alternateFile.existsSync()) {
      return packages_file.parse(bytes, file.uri);
    }
    file = alternateFile;
    bytes = await alternateFile.readAsBytes();
  }
  return parsePackageConfigBytes(bytes, file.uri);
}

/// Like [readAnyConfigFile] but uses a URI and an optional loader.
Future<PackageConfig> readAnyConfigFileUri(
    Uri file, Future<Uint8List /*?*/ > loader(Uri uri) /*?*/) async {
  if (file.isScheme("package")) {
    throw PackageConfigArgumentError(
        file, "file", "Must not be a package: URI");
  }
  if (loader == null) {
    if (file.isScheme("file")) return readAnyConfigFile(File.fromUri(file));
    loader = defaultLoader;
  }
  var bytes = await loader(file);
  if (bytes == null) {
    throw PackageConfigArgumentError(
        file.toString(), "file", "File cannot be read");
  }
  int firstChar = firstNonWhitespaceChar(bytes);
  if (firstChar != $lbrace) {
    // Definitely not a JSON object, probably a .packages.
    var alternateFile = file.resolveUri(packageConfigJsonPath);
    var alternateBytes = await loader(alternateFile);
    if (alternateBytes == null) {
      return packages_file.parse(bytes, file);
    }
    bytes = alternateBytes;
    file = alternateFile;
  }
  return parsePackageConfigBytes(bytes, file);
}

Future<PackageConfig> readPackageConfigJsonFile(File file) async {
  Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    return null;
  }
  return parsePackageConfigBytes(bytes, file.uri);
}

Future<PackageConfig> readDotPackagesFile(File file) async {
  Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    return null;
  }
  return packages_file.parse(bytes, file.uri);
}

PackageConfig parsePackageConfigBytes(Uint8List bytes, Uri file) {
  // TODO(lrn): Make this simpler. Maybe parse directly from bytes.
  return parsePackageConfigJson(json.fuse(utf8).decode(bytes), file);
}

/// Creates a [PackageConfig] from a parsed JSON-like object structure.
///
/// The [json] argument must be a JSON object (`Map<String, dynamic>`)
/// containing a `"configVersion"` entry with an integer value in the range
/// 1 to [PackageConfig.maxVersion],
/// and with a `"packages"` entry which is a JSON array (`List<dynamic>`)
/// containing JSON objects which each has the following properties:
///
/// * `"name"`: The package name as a string.
/// * `"rootUri"`: The root of the package as a URI stored as a string.
/// * `"packageUri"`: Optionally the root of for `package:` URI resolution
///     for the package, as a relative URI below the root URI
///     stored as a string.
/// * `"languageVersion"`: Optionally a language version string which is a
///     an integer numeral, a decimal point (`.`) and another integer numeral,
///     where the integer numeral cannot have a sign, and can only have a
///     leading zero if the entire numeral is a single zero.
///
/// All other properties are stored in [extraData].
///
/// The [baseLocation] is used as base URI to resolve the "rootUri"
/// URI referencestring.
PackageConfig parsePackageConfigJson(dynamic json, Uri baseLocation) {
  if (!baseLocation.hasScheme || baseLocation.isScheme("package")) {
    throw PackageConfigArgumentError(baseLocation.toString(), "baseLocation",
        "Must be an absolute non-package: URI");
  }

  if (!baseLocation.path.endsWith("/")) {
    baseLocation = baseLocation.resolveUri(Uri(path: "."));
  }

  String typeName<T>() {
    if (0 is T) return "int";
    if ("" is T) return "string";
    if (const [] is T) return "array";
    return "object";
  }

  T checkType<T>(dynamic value, String name, [String /*?*/ packageName]) {
    if (value is T) return value;
    // The only types we are called with are [int], [String], [List<dynamic>]
    // and Map<String, dynamic>. Recognize which to give a better error message.
    var message =
        "$name${packageName != null ? " of package $packageName" : ""}"
        " is not a JSON ${typeName<T>()}";
    throw PackageConfigFormatException(message, value);
  }

  Package parsePackage(Map<String, dynamic> entry) {
    String /*?*/ name;
    String /*?*/ rootUri;
    String /*?*/ packageUri;
    String /*?*/ languageVersion;
    Map<String, dynamic> /*?*/ extraData;
    entry.forEach((key, value) {
      switch (key) {
        case _nameKey:
          name = checkType<String>(value, _nameKey);
          break;
        case _rootUriKey:
          rootUri = checkType<String>(value, _rootUriKey, name);
          break;
        case _packageUriKey:
          packageUri = checkType<String>(value, _packageUriKey, name);
          break;
        case _languageVersionKey:
          languageVersion = checkType<String>(value, _languageVersionKey, name);
          break;
        default:
          (extraData ??= {})[key] = value;
          break;
      }
    });
    if (name == null) {
      throw PackageConfigFormatException("Missing name entry", entry);
    }
    if (rootUri == null) {
      throw PackageConfigFormatException("Missing rootUri entry", entry);
    }
    Uri root = baseLocation.resolve(rootUri);
    Uri /*?*/ packageRoot = root;
    if (packageUri != null) packageRoot = root.resolve(packageUri);
    try {
      return SimplePackage(name, root, packageRoot, languageVersion, extraData);
    } on ArgumentError catch (e) {
      throw PackageConfigFormatException(e.message, e.invalidValue);
    }
  }

  var map = checkType<Map<String, dynamic>>(json, "value");
  Map<String, dynamic> /*?*/ extraData = null;
  List<Package> /*?*/ packageList;
  int /*?*/ configVersion;
  map.forEach((key, value) {
    switch (key) {
      case _configVersionKey:
        configVersion = checkType<int>(value, _configVersionKey);
        break;
      case _packagesKey:
        var packageArray = checkType<List<dynamic>>(value, _packagesKey);
        var packages = <Package>[];
        for (var package in packageArray) {
          packages.add(parsePackage(
              checkType<Map<String, dynamic>>(package, "package entry")));
        }
        packageList = packages;
        break;
      default:
        (extraData ??= {})[key] = value;
        break;
    }
  });
  if (configVersion == null) {
    throw PackageConfigFormatException("Missing configVersion entry", json);
  }
  if (packageList == null)
    throw PackageConfigFormatException("Missing packages list", json);
  try {
    return SimplePackageConfig(configVersion, packageList, extraData);
  } on ArgumentError catch (e) {
    throw PackageConfigFormatException(e.message, e.invalidValue);
  }
}

Future<void> writePackageConfigJson(
    PackageConfig config, Directory targetDirectory) async {
  // Write .dart_tool/package_config.json first.
  var file = File(
      path.join(targetDirectory.path, ".dart_tool", "package_config.json"));
  var baseUri = file.uri;
  var extraData = config.extraData;
  var data = <String, dynamic>{
    _configVersionKey: PackageConfig.maxVersion,
    _packagesKey: [
      for (var package in config.packages)
        <String, dynamic>{
          _nameKey: package.name,
          _rootUriKey: relativizeUri(package.root, baseUri),
          if (package.root != package.packageUriRoot)
            _packageUriKey: relativizeUri(package.packageUriRoot, package.root),
          if (package.languageVersion != null)
            _languageVersionKey: package.languageVersion,
          ...?_extractExtraData(package.extraData, _packageNames),
        }
    ],
    ...?_extractExtraData(config.extraData, _topNames),
  };

  // Write .packages too.
  String /*?*/ comment;
  if (extraData != null) {
    String /*?*/ generator = extraData[_generatorKey];
    if (generator != null) {
      String /*?*/ generated = extraData[_generatedKey];
      String /*?*/ generatorVersion = extraData[_generatorVersionKey];
      comment = "Generated by $generator"
          "${generatorVersion != null ? " $generatorVersion" : ""}"
          "${generated != null ? " on $generated" : ""}.";
    }
  }
  file = File(path.join(targetDirectory.path, ".packages"));
  baseUri = file.uri;
  var buffer = StringBuffer();
  packages_file.write(buffer, config, baseUri: baseUri, comment: comment);

  await Future.wait([
    file.writeAsString(JsonEncoder.withIndent("  ").convert(data)),
    file.writeAsString(buffer.toString()),
  ]);
}

/// If "extraData" is a JSON map, then return it, otherwise return null.
///
/// If the value contains any of the [reservedNames] for the current context,
/// entries with that name in the extra data are dropped.
Map<String, dynamic> /*?*/ _extractExtraData(
    dynamic data, Iterable<String> reservedNames) {
  if (data is Map<String, dynamic>) {
    if (data.isEmpty) return null;
    for (var name in reservedNames) {
      if (data.containsKey(name)) {
        data = {
          for (var key in data.keys)
            if (!reservedNames.contains(key)) key: data[key]
        };
        if (data.isEmpty) return null;
        for (var value in data.values) {
          if (!_validateJson(value)) return null;
        }
      }
    }
    return data;
  }
  return null;
}

/// Checks that the object is a valid JSON-like data structure.
bool _validateJson(dynamic object) {
  if (object == null || object == true || object == false) return true;
  if (object is num || object is String) return true;
  if (object is List<dynamic>) {
    for (var element in object) if (!_validateJson(element)) return false;
    return true;
  }
  if (object is Map<String, dynamic>) {
    for (var value in object.values) if (!_validateJson(value)) return false;
    return true;
  }
  return false;
}
