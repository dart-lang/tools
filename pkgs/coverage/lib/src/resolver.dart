library coverage.resolver;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// [Resolver] resolves imports with respect to a given environment.
class Resolver {
  static const DART_PREFIX = 'dart:';
  static const PACKAGE_PREFIX = 'package:';
  static const FILE_PREFIX = 'file://';

  final String packageRoot;
  final String sdkRoot;
  final List<String> failed = [];

  Resolver({this.packageRoot, this.sdkRoot});

  /// Returns the absolute path wrt. to the given environment or null, if the
  /// import could not be resolved.
  String resolve(String uri) {
    if (uri.startsWith(DART_PREFIX)) {
      if (sdkRoot == null) {
        // No sdk-root given, do not resolve dart: URIs.
        return null;
      }
      var slashPos = uri.indexOf('/');
      var filePath;
      if (slashPos != -1) {
        var path = uri.substring(DART_PREFIX.length, slashPos);
        // Drop patch files, since we don't have their source in the compiled
        // SDK.
        if (path.endsWith('-patch')) {
          failed.add(uri);
          return null;
        }
        // Canonicalize path. For instance: _collection-dev => _collection_dev.
        path = path.replaceAll('-', '_');
        filePath = '$sdkRoot/${path}${uri.substring(slashPos, uri.length)}';
      } else {
        // Resolve 'dart:something' to be something/something.dart in the SDK.
        var lib = uri.substring(DART_PREFIX.length, uri.length);
        filePath = '$sdkRoot/$lib/${lib}.dart';
      }
      return resolveSymbolicLinks(filePath);
    }
    if (uri.startsWith(PACKAGE_PREFIX)) {
      if (packageRoot == null) {
        // No package-root given, do not resolve package: URIs.
        return null;
      }
      var path = uri.substring(PACKAGE_PREFIX.length, uri.length);
      return resolveSymbolicLinks(p.join(packageRoot, path));
    }
    if (uri.startsWith(FILE_PREFIX)) {
      return resolveSymbolicLinks(p.fromUri(Uri.parse(uri)));
    }
    // We cannot deal with anything else.
    failed.add(uri);
    return null;
  }

  /// Returns a canonicalized path, or `null` if the path cannot be resolved.
  String resolveSymbolicLinks(String path) {
    var normalizedPath = p.normalize(path);
    var type = FileSystemEntity.typeSync(normalizedPath, followLinks: true);
    if (type == FileSystemEntityType.NOT_FOUND) return null;
    return new File(normalizedPath).resolveSymbolicLinksSync();
  }
}

/// Bazel URI resolver.
class BazelResolver extends Resolver {
  static const DART_PREFIX = 'dart:';
  static const PACKAGE_PREFIX = 'package:';
  static const FILE_PREFIX = 'file://';
  static const HTTP_PREFIX = 'http://';
  static const HTTPS_PREFIX = 'https://';
  static const PACKAGES_SEGMENT = '/packages/';
  static const RUNFILES_SUFFIX = '.runfiles';

  final List<String> failed = [];
  final String workspacePath;

  /// Creates a Bazel resolver with the specified workspace path, if any.
  BazelResolver({this.workspacePath: ''});

  /// Returns the absolute path wrt. to the given environment or null, if the
  /// import could not be resolved.
  String resolve(String uri) {
    if (uri.startsWith(DART_PREFIX)) {
      // Ignore the SDK
      return null;
    }
    if (uri.startsWith(PACKAGE_PREFIX)) {
      // TODO(cbracken) belongs in a Bazel package
      var path = uri.substring(PACKAGE_PREFIX.length);
      return _resolveBazelPackage(path);
    }
    if (uri.startsWith(FILE_PREFIX)) {
      var runfilesPathSegment = '$RUNFILES_SUFFIX/$workspacePath';
      runfilesPathSegment = runfilesPathSegment.replaceAll(new RegExp(r'/*$'), '/');
      var runfilesPos = uri.indexOf(runfilesPathSegment);
      if (runfilesPos >= 0) {
        int pathStart = runfilesPos + runfilesPathSegment.length;
        return uri.substring(pathStart);
      }
      return null;
    }
    if (uri.startsWith(HTTPS_PREFIX)) {
      uri = uri.substring(HTTPS_PREFIX.length);
      int packagesPos = uri.indexOf(PACKAGES_SEGMENT);
      if (packagesPos >= 0) {
        return _resolveBazelPackage(uri.substring(packagesPos + PACKAGES_SEGMENT.length));
      }
      return uri;
    }
    if (uri.startsWith(HTTP_PREFIX)) {
      uri = uri.substring(HTTP_PREFIX.length);
      int packagesPos = uri.indexOf(PACKAGES_SEGMENT);
      if (packagesPos >= 0) {
        return _resolveBazelPackage(uri.substring(packagesPos + PACKAGES_SEGMENT.length));
      }
      return uri;
    }
    // We cannot deal with anything else.
    failed.add(uri);
    return null;
  }

  String _resolveBazelPackage(String uriPath) {
    // TODO(cbracken) belongs in a Bazel package
    var slashPos = uriPath.indexOf('/');
    var packageName = uriPath.substring(0, slashPos);
    var packageFile = uriPath.substring(slashPos + 1);
    var packagePath;
    if (packageName.contains('.')) {
      packagePath = packageName.replaceAll('.', '/');
    } else {
      packagePath = 'third_party/dart/$packageName';
    }
    return '$packagePath/lib/$packageFile';
  }
}

/// Loads the lines of imported resources.
class Loader {
  final List<String> failed = [];

  /// Loads an imported resource and returns a [Future] with a [List] of lines.
  /// Returns [null] if the resource could not be loaded.
  Future<List<String>> load(String path) async {
    try {
      return new File(path).readAsLines();
    } catch (_) {
      failed.add(path);
      return null;
    }
  }
}
