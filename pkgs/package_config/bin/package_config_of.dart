#! /bin/env dart
// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Utility for checking which package configuration applies to a specific file
/// or path.
library;

import 'dart:convert';
import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

/// Output modes.
const _printText = 0;
const _printJsonLines = 1;
const _printJsonList = 2;

void main(List<String> args) async {
  // Basic command line parser. No fancy.
  var files = <String>[];
  var stopAtPubspec = false;
  var noParent = false;
  var hasPrintedUsage = false;
  var parseFlags = true;
  var printFormat = _printText;
  for (var arg in args) {
    if (parseFlags && arg.startsWith('-')) {
      switch (arg) {
        case '-b':
          noParent = true;
        case '-g':
          stopAtPubspec = false;
        case '-h':
          if (!hasPrintedUsage) {
            hasPrintedUsage = true;
            stdout.writeln(usage);
          }
        case '-j':
          printFormat = _printJsonLines;
        case '-jl':
          printFormat = _printJsonList;
        case '-p':
          stopAtPubspec = true;
        case '--':
          parseFlags = false;
        default:
          stderr.writeln('Unexpected flag: $arg');
          if (!hasPrintedUsage) {
            hasPrintedUsage = true;
            stderr.writeln(usage);
          }
      }
    } else {
      files.add(arg);
    }
  }
  if (hasPrintedUsage) return;

  /// Check current directory if no PATHs on command line.
  if (files.isEmpty) {
    files.add(p.current);
  }

  var loader = PackageConfigLoader(
    stopAtPubspec: stopAtPubspec,
    noParent: noParent,
  );

  // Collects infos if printing as single JSON value.
  // Otherwise prints output for each file as soon as it's available.
  var jsonList = <Map<String, Object?>>[];

  for (var arg in files) {
    var fileInfo = await _resolveInfo(arg, loader);
    if (fileInfo == null) continue; // File does not exist, already reported.
    if (printFormat == _printText) {
      // Display as "readable" text.
      print(fileInfo);
    } else if (printFormat == _printJsonLines) {
      // Write JSON on a single line.
      stdout.writeln(
        const JsonEncoder.withIndent(null).convert(fileInfo.toJson()),
      );
    } else {
      // Store JSON in list, print entire list later.
      assert(printFormat == _printJsonList);
      jsonList.add(fileInfo.toJson());
    }
  }
  if (printFormat == _printJsonList) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(jsonList));
  }
}

/// Finds package information for command line provided path.
Future<ConfigInfo?> _resolveInfo(String arg, PackageConfigLoader loader) async {
  var path = p.normalize(arg);
  var file = File(path);
  if (file.existsSync()) {
    file = file.absolute;
    var directory = Directory(p.dirname(file.path));
    return await _resolvePackageConfig(directory, file, loader);
  }
  var directory = Directory(path);
  if (directory.existsSync()) {
    return await _resolvePackageConfig(directory.absolute, null, loader);
  }
  stderr.writeln('Cannot find file or directory: $arg');
  return null;
}

// --------------------------------------------------------------------
// Convert package configuration information to a simple model object.

/// Extract package configuration information for a file from a configuration.
Future<ConfigInfo> _resolvePackageConfig(
  Directory path,
  File? file,
  PackageConfigLoader loader,
) async {
  var originPath = path.path;
  var targetPath = file?.path ?? originPath;
  var (configPath, config) = await loader.findPackageConfig(originPath);
  Package? package;
  Uri? packageUri;
  LanguageVersion? overrideVersion;
  if (config != null) {
    var uri = file?.uri ?? path.uri;
    package = config.packageOf(uri);
    if (package != null) {
      packageUri = config.toPackageUri(uri);
    }
  }
  if (file != null) {
    overrideVersion = _readOverrideVersion(file);
  }
  return ConfigInfo(
    targetPath,
    configPath,
    package,
    packageUri,
    overrideVersion,
  );
}

/// Gathered package configuration information for [path].
final class ConfigInfo {
  /// Original path being resolved.
  final String path;

  /// Path to package configuration file, if any.
  final String? configPath;

  /// Package that path belongs to, if any.
  final Package? package;

  /// Package URI for [path], if it has one.
  /// Always `null` if [package] is `null`.
  final Uri? packageUri;

  /// Language version override in file, if any.
  final LanguageVersion? languageVersionOverride;

  ConfigInfo(
    this.path,
    this.configPath,
    this.package,
    this.packageUri,
    this.languageVersionOverride,
  );

  Map<String, Object?> toJson() {
    return {
      JsonKey.path: path,
      if (configPath != null) JsonKey.configPath: configPath,
      if (package case var package?)
        JsonKey.package: {
          JsonKey.name: package.name,
          JsonKey.root: _fileUriPath(package.root),
          if (package.languageVersion case var languageVersion?)
            JsonKey.languageVersion: languageVersion.toString(),
          if (packageUri case var packageUri?) ...{
            JsonKey.packageUri: packageUri.toString(),
            if (package.root != package.packageUriRoot)
              JsonKey.lib: _fileUriPath(package.packageUriRoot),
          },
        },
      if (languageVersionOverride case var override?)
        JsonKey.languageVersionOverride: override.toString(),
    };
  }

  /// Package configuration information for a path in a readable format.
  @override
  String toString() {
    var buffer = StringBuffer();
    var sep = Platform.pathSeparator;
    var kind = path.endsWith(Platform.pathSeparator) ? 'directory' : 'file';
    buffer.writeln('Package configuration for $kind: ${p.relative(path)}');
    if (configPath case var configPath?) {
      buffer.writeln('- Package configuration: ${p.relative(configPath)}');
      if (package case var package?) {
        buffer.writeln('- In package: ${package.name}');
        if (package.languageVersion case var version?) {
          buffer.writeln('  - default language version: $version');
        }
        var rootUri = _fileUriPath(package.root);
        var rootPath = p.relative(Directory.fromUri(Uri.parse(rootUri)).path);
        buffer.writeln('  - with root: $rootPath$sep');
        if (packageUri case var packageUri?) {
          buffer.writeln('  - Has package URI: $packageUri');
          if (package.root != package.packageUriRoot) {
            var libPath = p.relative(
              Directory.fromUri(package.packageUriRoot).path,
            );
            buffer.writeln('    - relative to: $libPath$sep');
          } else {
            buffer.writeln('    - relative to root');
          }
        }
      } else {
        buffer.writeln('- Is not part of any package');
      }
    } else {
      buffer.writeln('- No package configuration found');
      assert(package == null);
    }
    if (languageVersionOverride case var override?) {
      buffer.writeln('- Language version override: // @dart=$override');
    }
    return buffer.toString();
  }

  static String _fileUriPath(Uri uri) {
    assert(uri.isScheme('file'));
    return File.fromUri(uri).path;
  }
}

// Constants for all used JSON keys to prevent mis-typing.
extension type const JsonKey(String value) implements String {
  static const JsonKey path = JsonKey('path');
  static const JsonKey configPath = JsonKey('configPath');
  static const JsonKey package = JsonKey('package');
  static const JsonKey name = JsonKey('name');
  static const JsonKey root = JsonKey('root');
  static const JsonKey packageUri = JsonKey('packageUri');
  static const JsonKey lib = JsonKey('lib');
  static const JsonKey languageVersion = JsonKey('languageVersion');
  static const JsonKey languageVersionOverride = JsonKey(
    'languageVersionOverride',
  );
}

// --------------------------------------------------------------------
// Find language version override marker in file.

/// Tries to find a language override marker in a Dart file.
///
/// Uses a best-effort approach to scan for a line
/// of the form `// @dart=X.Y` before any Dart directive.
/// Any consistently and idiomatically formatted file will be recognized
/// correctly. A file with a multiline `/*...*/` comment where
/// internal lines do not start with `*`, or where a Dart directive
/// follows a `*/` on the same line, may be misinterpreted.
LanguageVersion? _readOverrideVersion(File file) {
  String fileContent;
  try {
    fileContent = file.readAsStringSync();
  } catch (e) {
    stderr
      ..writeln('Error reading ${file.path} as UTF-8 text:')
      ..writeln(e);
    return null;
  }
  // Skip BOM only at start.
  const bom = '\uFEFF';
  var contentStart = 0;
  // Skip BOM only at start.
  if (fileContent.startsWith(bom)) contentStart = 1;
  // Skip `#! ...` line only at start.
  if (fileContent.startsWith('#!', contentStart)) {
    // Skip until end-of-line, whether ended by `\n` or `\r\n`.
    var endOfHashBang = fileContent.indexOf('\n', contentStart + 2);
    if (endOfHashBang < 0) return null; // No EOL after `#!`.
    contentStart = endOfHashBang + 1;
  }
  // Match lines until one that looks like a version override or not a comment.
  for (var match in leadRegExp.allMatches(fileContent, contentStart)) {
    if (match.namedGroup('major') case var major?) {
      // Found `// @dart=<major>.<minor>` line.
      var minor = match.namedGroup('minor')!;
      return LanguageVersion(int.parse(major), int.parse(minor));
    } else if (match.namedGroup('other') != null) {
      // Found non-comment, so too late for language version markers.
      break;
    }
  }
  return null;
}

/// Heuristic scanner for finding leading comment lines.
///
/// Finds leading comments and any language version override marker
/// within them.
///
/// Accepts empty lines or lines starting with `/*`, `*` or `//` as
/// initial comment lines, and any other non-space/tab first character
/// as a non-comment, which ends the section
/// that can contain language overrides.
///
/// It's possible to construct files where that's not correct, fx.
/// ```
/// /* something */ import "banana.dart";
/// // @dart=2.14
/// ```
/// To be absolutely certain, the code would need to properly tokenize
/// *nested* comments, which is not a job for a RegExp.
/// This RegExp should work for well-behaved and -formatted files.
final leadRegExp = RegExp(
  r'^[ \t]*'
  r'(?:'
  r'$' // Empty line
  r'|'
  r'/?\*' // Line starting with `/*` or `*`, assumed a comment continuation.
  r'|'
  // Line starting with `//`, and possibly followed by language override.
  r'//(?: *@ *dart *= *(?<major>\d+) *\. *(?<minor>\d+) *$)?'
  r'|'
  r'(?<other>[^ \t/*])' // Any other line, assumed to end initial comments.
  r')',
  multiLine: true,
);

// --------------------------------------------------------------------
// Find and load (and cache) package configurations

class PackageConfigLoader {
  /// Stop searching at the current working directory.
  final bool noParent;

  /// Stop searching if finding a `pubspec.yaml` with no package configuration.
  final bool stopAtPubspec;

  /// Cache lookup results in case someone does more lookups on the same path.
  final Map<
    (String path, bool stopAtPubspec),
    (String? configPath, PackageConfig? config)
  >
  _packageConfigCache = {};

  PackageConfigLoader({this.stopAtPubspec = false, this.noParent = false});

  /// Finds a package configuration relative to [path].
  ///
  /// Caches result for each directory looked at.
  /// If someone does multiple lookups in the same directory, there is no need
  /// to find and parse the same configuration more than once.
  Future<(String? path, PackageConfig? config)> findPackageConfig(
    String path,
  ) async =>
      _packageConfigCache[(
        path,
        stopAtPubspec,
      )] ??= await _findPackageConfigNoCache(path);

  Future<(String? path, PackageConfig? config)> _findPackageConfigNoCache(
    String path,
  ) async {
    var configPath = p.join(path, '.dart_tool', 'package_config.json');
    var configFile = File(configPath);
    if (configFile.existsSync()) {
      var hasError = false;
      var config = await loadPackageConfig(
        configFile.absolute,
        onError: (error) {
          stderr.writeln(
            'Error parsing package configuration config ($configPath):\n'
            ' $error',
          );
          hasError = true;
        },
      );
      return (configPath, hasError ? null : config);
    }
    if (stopAtPubspec) {
      var pubspecPath = p.join(path, 'pubspec.yaml');
      var pubspecFile = File(pubspecPath);
      if (pubspecFile.existsSync()) {
        stderr
          ..writeln('Found pubspec.yaml with no .dart_tool/package_config.json')
          ..writeln('  at $path');
        return (null, null);
      }
    }
    if (noParent && path == p.current) return (null, null);
    var parentPath = p.dirname(path);
    if (parentPath == path) return (null, null);
    // Recurse on parent path.
    return findPackageConfig(parentPath);
  }
}

const String usage = '''
Usage: dart package_config_of.dart [-p|-j|-jl|-h] PATH*

Searches from (each) PATH for a `.dart_tool/package_config.json` file,
loads that, and prints information about that package configuration
and the configuration for PATH in it.
If no PATH is given, the current directory is used.

Flags:
  -p    : Stop when finding a 'pubspec.yaml' file without a package config.
          The default is to ignore `pubspec.yaml` files and only look for
          `.dart_tool/package_config.json` files, which will work correctly
          for Pub workspaces.
  -b    : Stop if reaching the current working directory.
          When looking for a package configuration, don't try further out
          than the current directory.
          Only works for starting PATHs inside the current directory.
  -j    : Output as JSON. Emits a single JSON object for each file, on
          a line of its own (JSON-lines format). See format below.
          Default is to output human readable text.
  -jl   : Emits as a single JSON list containing the JSON outputs.
          See format of individual elements below.
          Default is to output human readable text.
  -h    : Print this help text. Ignore any PATHs.

A JSON object written using -j or -jl has following entries:
    "path": "PATH", normalized and ends in a `/` if a directory.
    "configPath": path to config file. Omitted if no or invalid config.
    "package": The package that PATH belongs to, if any. A map with:
        "name": Package name.
        "root": Path to package root.
        "languageVersion": "A.B", default language version for package.
        "packageUri": The package: URI of PATH, if one exists.
        "lib": If package URI exists, the package URI root,
               unless it's the same as the package root.
    "languageVersionOverride": "A.B", if file has '//@dart=' version override.
''';
