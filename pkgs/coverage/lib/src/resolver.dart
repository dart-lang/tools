// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:package_config/packages_file.dart' as packages_file;
import 'package:path/path.dart' as p;

/// [Resolver] resolves imports with respect to a given environment.
class Resolver {
  Resolver({String packagesPath, this.packageRoot, this.sdkRoot})
      : packagesPath = packagesPath,
        _packages = packagesPath != null ? _parsePackages(packagesPath) : null;

  final String packagesPath;
  final String packageRoot;
  final String sdkRoot;
  final List<String> failed = [];
  Map<String, Uri> _packages;

  /// Returns the absolute path wrt. to the given environment or null, if the
  /// import could not be resolved.
  String resolve(String scriptUri) {
    var uri = Uri.parse(scriptUri);
    if (uri.scheme == 'dart') {
      if (sdkRoot == null) {
        // No sdk-root given, do not resolve dart: URIs.
        return null;
      }
      String filePath;
      if (uri.pathSegments.length > 1) {
        var path = uri.pathSegments[0];
        // Drop patch files, since we don't have their source in the compiled
        // SDK.
        if (path.endsWith('-patch')) {
          failed.add('$uri');
          return null;
        }
        // Canonicalize path. For instance: _collection-dev => _collection_dev.
        path = path.replaceAll('-', '_');
        var pathSegments = [sdkRoot, path]..addAll(uri.pathSegments.sublist(1));
        filePath = p.joinAll(pathSegments);
      } else {
        // Resolve 'dart:something' to be something/something.dart in the SDK.
        var lib = uri.path;
        filePath = p.join(sdkRoot, lib, '$lib.dart');
      }
      return resolveSymbolicLinks(filePath);
    }
    if (uri.scheme == 'package') {
      if (packagesPath == null && packageRoot == null) {
        // No package-root given, do not resolve package: URIs.
        return null;
      }

      var packageName = uri.pathSegments[0];
      if (_packages != null) {
        var packageUri = _packages[packageName];
        if (packageUri == null) {
          failed.add('$uri');
          return null;
        }
        var packagePath = p.fromUri(packageUri);
        var pathInPackage = p.joinAll(uri.pathSegments.sublist(1));
        return resolveSymbolicLinks(p.join(packagePath, pathInPackage));
      }
      return resolveSymbolicLinks(p.join(packageRoot, uri.path));
    }
    if (uri.scheme == 'file') {
      return resolveSymbolicLinks(p.fromUri(uri));
    }
    // We cannot deal with anything else.
    failed.add('$uri');
    return null;
  }

  /// Returns a canonicalized path, or `null` if the path cannot be resolved.
  String resolveSymbolicLinks(String path) {
    var normalizedPath = p.normalize(path);
    var type = FileSystemEntity.typeSync(normalizedPath, followLinks: true);
    if (type == FileSystemEntityType.notFound) return null;
    return File(normalizedPath).resolveSymbolicLinksSync();
  }

  static Map<String, Uri> _parsePackages(String packagesPath) {
    var source = File(packagesPath).readAsBytesSync();
    return packages_file.parse(source, Uri.file(packagesPath));
  }
}

/// Bazel URI resolver.
class BazelResolver extends Resolver {
  /// Creates a Bazel resolver with the specified workspace path, if any.
  BazelResolver({this.workspacePath = ''});

  final String workspacePath;

  /// Returns the absolute path wrt. to the given environment or null, if the
  /// import could not be resolved.
  @override
  String resolve(String scriptUri) {
    var uri = Uri.parse(scriptUri);
    if (uri.scheme == 'dart') {
      // Ignore the SDK
      return null;
    }
    if (uri.scheme == 'package') {
      // TODO(cbracken) belongs in a Bazel package
      return _resolveBazelPackage(uri.pathSegments);
    }
    if (uri.scheme == 'file') {
      var runfilesPathSegment = '.runfiles/$workspacePath';
      runfilesPathSegment = runfilesPathSegment.replaceAll(RegExp(r'/*$'), '/');
      var runfilesPos = uri.path.indexOf(runfilesPathSegment);
      if (runfilesPos >= 0) {
        int pathStart = runfilesPos + runfilesPathSegment.length;
        return uri.path.substring(pathStart);
      }
      return null;
    }
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      return _extractHttpPath(uri);
    }
    // We cannot deal with anything else.
    failed.add('$uri');
    return null;
  }

  String _extractHttpPath(Uri uri) {
    int packagesPos = uri.pathSegments.indexOf('packages');
    if (packagesPos >= 0) {
      var workspacePath = uri.pathSegments.sublist(packagesPos + 1);
      return _resolveBazelPackage(workspacePath);
    }
    return uri.pathSegments.join('/');
  }

  String _resolveBazelPackage(List<String> pathSegments) {
    // TODO(cbracken) belongs in a Bazel package
    var packageName = pathSegments[0];
    var pathInPackage = pathSegments.sublist(1).join('/');
    String packagePath;
    if (packageName.contains('.')) {
      packagePath = packageName.replaceAll('.', '/');
    } else {
      packagePath = 'third_party/dart/$packageName';
    }
    return '$packagePath/lib/$pathInPackage';
  }
}

/// Loads the lines of imported resources.
class Loader {
  final List<String> failed = [];

  /// Loads an imported resource and returns a [Future] with a [List] of lines.
  /// Returns `null` if the resource could not be loaded.
  Future<List<String>> load(String path) async {
    try {
      return File(path).readAsLines();
    } catch (_) {
      failed.add(path);
      return null;
    }
  }
}
