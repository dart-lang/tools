// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Implementations of [Packages] that may be used in either server or browser
/// based applications. For implementations that can only run in the browser,
/// see [package_config.packages_io_impl].
@Deprecated("Use the package_config.json based API")
library package_config.packages_impl;

import "dart:collection" show UnmodifiableMapView;

import "../packages.dart";
import "util.dart" show checkValidPackageUri;

/// A [Packages] null-object.
class NoPackages implements Packages {
  const NoPackages();

  Uri resolve(Uri packageUri, {Uri notFound(Uri packageUri)}) {
    var packageName = checkValidPackageUri(packageUri, "packageUri");
    if (notFound != null) return notFound(packageUri);
    throw ArgumentError.value(
        packageUri, "packageUri", 'No package named "$packageName"');
  }

  Iterable<String> get packages => Iterable<String>.empty();

  Map<String, Uri> asMap() => const <String, Uri>{};

  String get defaultPackageName => null;

  String packageMetadata(String packageName, String key) => null;

  String libraryMetadata(Uri libraryUri, String key) => null;
}

/// Base class for [Packages] implementations.
///
/// This class implements the [resolve] method in terms of a private
/// member
abstract class PackagesBase implements Packages {
  Uri resolve(Uri packageUri, {Uri notFound(Uri packageUri)}) {
    packageUri = packageUri.normalizePath();
    var packageName = checkValidPackageUri(packageUri, "packageUri");
    var packageBase = getBase(packageName);
    if (packageBase == null) {
      if (notFound != null) return notFound(packageUri);
      throw ArgumentError.value(
          packageUri, "packageUri", 'No package named "$packageName"');
    }
    var packagePath = packageUri.path.substring(packageName.length + 1);
    return packageBase.resolve(packagePath);
  }

  /// Find a base location for a package name.
  ///
  /// Returns `null` if no package exists with that name, and that can be
  /// determined.
  Uri getBase(String packageName);

  String get defaultPackageName => null;

  String packageMetadata(String packageName, String key) => null;

  String libraryMetadata(Uri libraryUri, String key) => null;
}

/// A [Packages] implementation based on an existing map.
class MapPackages extends PackagesBase {
  final Map<String, Uri> _mapping;
  MapPackages(this._mapping);

  Uri getBase(String packageName) =>
      packageName.isEmpty ? null : _mapping[packageName];

  Iterable<String> get packages => _mapping.keys;

  Map<String, Uri> asMap() => UnmodifiableMapView<String, Uri>(_mapping);

  String get defaultPackageName => _mapping[""]?.toString();

  String packageMetadata(String packageName, String key) {
    if (packageName.isEmpty) return null;
    var uri = _mapping[packageName];
    if (uri == null || !uri.hasFragment) return null;
    // This can be optimized, either by caching the map or by
    // parsing incrementally instead of parsing the entire fragment.
    return Uri.splitQueryString(uri.fragment)[key];
  }

  String libraryMetadata(Uri libraryUri, String key) {
    if (libraryUri.isScheme("package")) {
      return packageMetadata(libraryUri.pathSegments.first, key);
    }
    var defaultPackageNameUri = _mapping[""];
    if (defaultPackageNameUri != null) {
      return packageMetadata(defaultPackageNameUri.toString(), key);
    }
    return null;
  }
}

/// A [Packages] implementation based on a remote (e.g., HTTP) directory.
///
/// There is no way to detect which packages exist short of trying to use
/// them. You can't necessarily check whether a directory exists,
/// except by checking for a know file in the directory.
class NonFilePackagesDirectoryPackages extends PackagesBase {
  final Uri _packageBase;
  NonFilePackagesDirectoryPackages(this._packageBase);

  Uri getBase(String packageName) => _packageBase.resolve("$packageName/");

  Error _failListingPackages() {
    return UnsupportedError(
        "Cannot list packages for a ${_packageBase.scheme}: "
        "based package root");
  }

  Iterable<String> get packages {
    throw _failListingPackages();
  }

  Map<String, Uri> asMap() {
    throw _failListingPackages();
  }
}
