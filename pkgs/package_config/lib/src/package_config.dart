// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "package_config_impl.dart";

/// A package configuration.
///
/// Associates configuration data to packages and files in packages.
///
/// More members may be added to this class in the future,
/// so classes outside of this package must not implement [PackageConfig]
/// or any subclass of it.
abstract class PackageConfig {
  /// The largest configuration version currently recognized.
  static const int maxVersion = 2;

  /// An empty package configuration.
  ///
  /// A package configuration with no available packages.
  /// Is used as a default value where a package configuration
  /// is expected, but none have been specified or found.
  static const PackageConfig empty = const SimplePackageConfig.empty();

  /// Creats a package configuration with the provided available [packages].
  ///
  /// The packages must be valid packages (valid package name, valid
  /// absolute directory URIs, valid language version, if any),
  /// and there must not be two packages with the same name or with
  /// overlapping root directories.
  ///
  /// If supplied, the [extraData] will be available as the
  /// [PackageConfig.extraData] of the created configuration.
  ///
  /// The version of the resulting configuration is always [maxVersion].
  factory PackageConfig(Iterable<Package> packages, {dynamic extraData}) =>
      SimplePackageConfig(maxVersion, packages);

  /// The configuration version number.
  ///
  /// Currently this is 1 or 2, where
  /// * Version one is the `.packages` file format and
  /// * Version two is the first `package_config.json` format.
  ///
  /// Instances of this class supports both, and the version
  /// is only useful for detecting which kind of file the configuration
  /// was read from.
  int get version;

  /// All the available packages of this configuration.
  ///
  /// No two of these packages have the same name,
  /// and no two [Package.root] directories overlap.
  Iterable<Package> get packages;

  /// Look up a package by name.
  ///
  /// Returns the [Package] fron [packages] with [packageName] as
  /// [Package.name]. Returns `null` if the package is not available in the
  /// current configuration.
  Package /*?*/ operator [](String packageName);

  /// Provides the associated package for a specific [file] (or directory).
  ///
  /// Returns a [Package] which contains the [file]'s path, if any.
  /// That is, the [Package.rootUri] directory is a parent directory
  /// of the [file]'s location.
  ///
  /// Returns `null` if the file does not belong to any package.
  Package /*?*/ packageOf(Uri file);

  /// Resolves a `package:` URI to a non-package URI
  ///
  /// The [packageUri] must be a valid package URI. That means:
  /// * A URI with `package` as scheme,
  /// * with no authority part (`package://...`),
  /// * with a path starting with a valid package name followed by a slash, and
  /// * with no query or fragment part.
  ///
  /// Throws an [ArgumentError] (which also implements [PackageConfigError])
  /// if the package URI is not valid.
  ///
  /// Returns `null` if the package name of [packageUri] is not available
  /// in this package configuration.
  /// Returns the remaining path of the package URI resolved relative to the
  /// [Package.packageUriRoot] of the corresponding package.
  Uri /*?*/ resolve(Uri packageUri);

  /// The package URI which resolves to [nonPackageUri].
  ///
  /// The [nonPackageUri] must not have any query or fragment part,
  /// and it must not have `package` as scheme.
  /// Throws an [ArgumentError] (which also implements [PackageConfigError])
  /// if the non-package URI is not valid.
  ///
  /// Returns a package URI which [resolve] will convert to [nonPackageUri],
  /// if any such URI exists. Returns `null` if no such package URI exists.
  Uri /*?*/ toPackageUri(Uri nonPackageUri);

  /// Extra data associated with the package configuration.
  ///
  /// The data may be in any format, depending on who introduced it.
  /// The standard `packjage_config.json` file storage will only store
  /// JSON-like list/map data structures.
  dynamic get extraData;
}

/// Configuration data for a single package.
abstract class Package {
  /// Creates a package with the provided properties.
  ///
  /// The [name] must be a valid package name.
  /// The [root] must be an absolute directory URI, meaning an absolute URI
  /// with no query or fragment path and a path starting and ending with `/`.
  /// The [packageUriRoot], if provided, must be either an absolute
  /// directory URI or a relative URI reference which is then resolved
  /// relative to [root]. It must then also be a subdirectory of [root],
  /// or the same directory.
  /// If [languageVersion] is supplied, it must be a valid Dart language
  /// version, which means two decimal integer literals separated by a `.`,
  /// where the integer literals have no leading zeros unless they are
  /// a single zero digit.
  /// If [extraData] is supplied, it will be available as the
  /// [Package.extraData] of the created package.
  factory Package(String name, Uri root,
          {Uri /*?*/ packageUriRoot,
          String /*?*/ languageVersion,
          dynamic extraData}) =>
      SimplePackage(name, root, packageUriRoot, languageVersion, extraData);

  /// The package-name of the package.
  String get name;

  /// The location of the root of the package.
  ///
  /// Is always an absolute URI with no query or fragment parts,
  /// and with a path ending in `/`.
  ///
  /// All files in the [rootUri] directory are considered
  /// part of the package for purposes where that that matters.
  Uri get root;

  /// The root of the files available through `package:` URIs.
  ///
  /// A `package:` URI with [name] as the package name is
  /// resolved relative to this location.
  ///
  /// Is always an absolute URI with no query or fragment part
  /// with a path ending in `/`,
  /// and with a location which is a subdirectory
  /// of the [root], or the same as the [root].
  Uri get packageUriRoot;

  /// The default language version associated with this package.
  ///
  /// Each package may have a default language version associated,
  /// which is the language version used to parse and compile
  /// Dart files in the package.
  /// A package version is always of the form:
  ///
  /// * A numeral consisting of one or more decimal digits,
  ///   with no leading zero unless the entire numeral is a single zero digit.
  /// * Followed by a `.` character.
  /// * Followed by another numeral of the same form.
  ///
  /// There is no whitespace allowed around the numerals.
  /// Valid version numbers include `2.5`, `3.0`, and `1234.5678`.
  String /*?*/ get languageVersion;

  /// Extra data associated with the specific package.
  ///
  /// The data may be in any format, depending on who introduced it.
  /// The standard `packjage_config.json` file storage will only store
  /// JSON-like list/map data structures.
  dynamic get extraData;
}
