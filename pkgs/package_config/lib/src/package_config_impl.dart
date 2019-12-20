// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'errors.dart';
import "package_config.dart";
export "package_config.dart";
import "util.dart";

class SimplePackageConfig implements PackageConfig {
  final int version;
  final Map<String, Package> _packages;
  final dynamic extraData;

  SimplePackageConfig(int version, Iterable<Package> packages, [this.extraData])
      : version = _validateVersion(version),
        _packages = _validatePackages(packages);

  SimplePackageConfig._(
      int version, Iterable<SimplePackage> packages, this.extraData)
      : version = _validateVersion(version),
        _packages = {for (var package in packages) package.name: package};

  /// Creates empty configuration.
  ///
  /// The empty configuration can be used in cases where no configuration is
  /// found, but code expects a non-null configuration.
  const SimplePackageConfig.empty()
      : version = 1,
        _packages = const <String, Package>{},
        extraData = null;

  static int _validateVersion(int version) {
    if (version < 0 || version > PackageConfig.maxVersion) {
      throw PackageConfigArgumentError(version, "version",
          "Must be in the range 1 to ${PackageConfig.maxVersion}");
    }
    return version;
  }

  static Map<String, Package> _validatePackages(Iterable<Package> packages) {
    Map<String, Package> result = {};
    for (var package in packages) {
      if (package is! SimplePackage) {
        // SimplePackage validates these properties.
        try {
          _validatePackageData(package.name, package.root,
              package.packageUriRoot, package.languageVersion);
        } catch (e) {
          throw PackageConfigArgumentError(
              packages, "packages", "Package ${package.name}: ${e.message}");
        }
      }
      var name = package.name;
      if (result.containsKey(name)) {
        throw PackageConfigArgumentError(
            name, "packages", "Duplicate package name");
      }
      result[name] = package;
    }

    // Check that no root URI is a prefix of another.
    if (result.length > 1) {
      // Uris cache their toString, so this is not as bad as it looks.
      var rootUris = [...result.values]
        ..sort((a, b) => a.root.toString().compareTo(b.root.toString()));
      var prev = rootUris[0];
      var prevRoot = prev.root.toString();
      for (int i = 1; i < rootUris.length; i++) {
        var next = rootUris[i];
        var nextRoot = next.root.toString();
        // If one string is a prefix of another,
        // the former sorts just before the latter.
        if (nextRoot.startsWith(prevRoot)) {
          throw PackageConfigArgumentError(
              packages,
              "packages",
              "Package ${next.name} root overlaps "
                  "package ${prev.name} root.\n"
                  "${prev.name} root: $prevRoot\n"
                  "${next.name} root: $nextRoot\n");
        }
        prev = next;
      }
    }
    return result;
  }

  Iterable<Package> get packages => _packages.values;

  Package /*?*/ operator [](String packageName) => _packages[packageName];

  /// Provides the associated package for a specific [file] (or directory).
  ///
  /// Returns a [Package] which contains the [file]'s path.
  /// That is, the [Package.rootUri] directory is a parent directory
  /// of the [file]'s location.
  /// Returns `null` if the file does not belong to any package.
  Package /*?*/ packageOf(Uri file) {
    String path = file.toString();
    for (var package in _packages.values) {
      var rootPath = package.root.toString();
      if (path.startsWith(rootPath)) return package;
    }
    return null;
  }

  Uri /*?*/ resolve(Uri packageUri) {
    String packageName = checkValidPackageUri(packageUri, "packageUri");
    return _packages[packageName]?.packageUriRoot?.resolveUri(
        Uri(path: packageUri.path.substring(packageName.length + 1)));
  }

  Uri /*?*/ toPackageUri(Uri nonPackageUri) {
    if (nonPackageUri.isScheme("package")) {
      throw PackageConfigArgumentError(
          nonPackageUri, "nonPackageUri", "Must not be a package URI");
    }
    if (nonPackageUri.hasQuery || nonPackageUri.hasFragment) {
      throw PackageConfigArgumentError(nonPackageUri, "nonPackageUri",
          "Must not have query or fragment part");
    }
    for (var package in _packages.values) {
      var root = package.packageUriRoot;
      if (isUriPrefix(root, nonPackageUri)) {
        var rest = nonPackageUri.toString().substring(root.toString().length);
        return Uri(scheme: "package", path: "${package.name}/$rest");
      }
    }
    return null;
  }
}

/// Configuration data for a single package.
class SimplePackage implements Package {
  final String name;
  final Uri root;
  final Uri packageUriRoot;
  final String /*?*/ languageVersion;
  final dynamic extraData;

  SimplePackage._(this.name, this.root, this.packageUriRoot,
      this.languageVersion, this.extraData);

  factory SimplePackage(String name, Uri root, Uri packageUriRoot,
      String /*?*/ languageVersion, dynamic extraData) {
    _validatePackageData(name, root, packageUriRoot, languageVersion);
    return SimplePackage._(
        name, root, packageUriRoot, languageVersion, extraData);
  }
}

void _validatePackageData(
    String name, Uri root, Uri packageUriRoot, String /*?*/ languageVersion) {
  if (!isValidPackageName(name)) {
    throw PackageConfigArgumentError(name, "name", "Not a valid package name");
  }
  if (!isAbsoluteDirectoryUri(root)) {
    throw PackageConfigArgumentError(
        "$root",
        "root",
        "Not an absolute URI with no query or fragment "
            "with a path ending in /");
  }
  if (!isAbsoluteDirectoryUri(packageUriRoot)) {
    throw PackageConfigArgumentError(
        packageUriRoot,
        "packageUriRoot",
        "Not an absolute URI with no query or fragment "
            "with a path ending in /");
  }
  if (!isUriPrefix(root, packageUriRoot)) {
    throw PackageConfigArgumentError(packageUriRoot, "packageUriRoot",
        "The package URI root is not below the package root");
  }
  if (languageVersion != null &&
      checkValidVersionNumber(languageVersion) >= 0) {
    throw PackageConfigArgumentError(
        languageVersion, "languageVersion", "Invalid language version format");
  }
}
