// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library package_config.packages_impl;

import "dart:collection" show UnmodifiableMapView;
import "dart:io" show Directory;
import "package:path/path.dart" as path;
import "../packages.dart";
import "util.dart" show checkValidPackageUri;

/// A [Packages] null-object.
class NoPackages implements Packages {
  const NoPackages();

  Uri resolve(Uri packageUri, {Uri notFound(Uri packageUri)}) {
    String packageName = checkValidPackageUri(packageUri);
    if (notFound != null) return notFound(packageUri);
    throw new ArgumentError.value(packageUri, "packageUri",
                                  'No package named "$packageName"');
  }

  Iterable<String> get packages => new Iterable<String>.empty();

  Map<String, Uri> asMap() => const<String,Uri>{};
}


/// Base class for [Packages] implementations.
///
/// This class implements the [resolve] method in terms of a private
/// member
abstract class _PackagesBase implements Packages {
  Uri resolve(Uri packageUri, {Uri notFound(Uri packageUri)}) {
    packageUri = packageUri.normalizePath();
    String packageName = checkValidPackageUri(packageUri);
    Uri packageBase = _getBase(packageName);
    if (packageBase == null) {
      if (notFound != null) return notFound(packageUri);
      throw new ArgumentError.value(packageUri, "packageUri",
                                    'No package named "$packageName"');
    }
    String packagePath = packageUri.path.substring(packageName.length + 1);
    return packageBase.resolve(packagePath);
  }

  /// Find a base location for a package name.
  ///
  /// Returns `null` if no package exists with that name, and that can be
  /// determined.
  Uri _getBase(String packageName);
}

/// A [Packages] implementation based on an existing map.
class MapPackages extends _PackagesBase {
  final Map<String, Uri> _mapping;
  MapPackages(this._mapping);

  Uri _getBase(String packageName) => _mapping[packageName];

  Iterable<String> get packages => _mapping.keys;

  Map<String, Uri> asMap() => new UnmodifiableMapView<String, Uri>(_mapping);
}

/// A [Packages] implementation based on a local directory.
class FilePackagesDirectoryPackages extends _PackagesBase {
  final Directory _packageDir;
  FilePackagesDirectoryPackages(this._packageDir);

  Uri _getBase(String packageName) =>
      new Uri.directory(path.join(packageName,''));

  Iterable<String> _listPackageNames() {
    return _packageDir.listSync()
                      .where((e) => e is Directory)
                      .map((e) => path.basename(e.path));
  }

  Iterable<String> get packages {
    return _listPackageNames();
  }

  Map<String, Uri> asMap() {
    var result = <String, Uri>{};
    for (var packageName in _listPackageNames()) {
      result[packageName] = _getBase(packageName);
    }
    return new UnmodifiableMapView<String, Uri>(result);
  }
}

/// A [Packages] implementation based on a remote (e.g., HTTP) directory.
///
/// There is no way to detect which packages exist short of trying to use
/// them. You can't necessarily check whether a directory exists,
/// except by checking for a know file in the directory.
class NonFilePackagesDirectoryPackages extends _PackagesBase {
  final Uri _packageBase;
  NonFilePackagesDirectoryPackages(this._packageBase);

  Uri _getBase(String packageName) => _packageBase.resolve("$packageName/");

  Error _failListingPackages() {
    return new UnsupportedError(
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
