part of coverage;

/// [Resolver] resolves imports with respect to a given environment.
class Resolver {
  static const DART_PREFIX = 'dart:';
  static const PACKAGE_PREFIX = 'package:';
  static const FILE_PREFIX = 'file://';
  static const HTTP_PREFIX = 'http://';

  final String pkgRoot;
  final String sdkRoot;
  List failed = [];

  Resolver({packageRoot: null, sdkRoot: null})
      : pkgRoot = packageRoot,
        sdkRoot = sdkRoot;

  /// Returns the absolute path wrt. to the given environment or null, if the
  /// import could not be resolved.
  resolve(String uri) {
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
      return filePath;
    }
    if (uri.startsWith(PACKAGE_PREFIX)) {
      if (pkgRoot == null) {
        // No package-root given, do not resolve package: URIs.
        return null;
      }
      return '$pkgRoot/${uri.substring(PACKAGE_PREFIX.length, uri.length)}';
    }
    if (uri.startsWith(FILE_PREFIX)) {
      return fromUri(Uri.parse(uri));
    }
    if (uri.startsWith(HTTP_PREFIX)) {
      return uri;
    }
    // We cannot deal with anything else.
    failed.add(uri);
    return null;
  }
}
