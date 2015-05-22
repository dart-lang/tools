// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library package_config.packages;

import "dart:async" show Future;
import "discovery.dart" show findPackages;
import "src/packages_impl.dart";

/// A package resolution strategy.
///
/// Allows converting a `package:` URI to a different kind of URI.
///
/// May also allow listing the available packages and converting
/// to a `Map<String, Uri>` that gives the base location of each available
/// package. In some cases there is no way to find the available packages,
/// in which case [packages] and [asMap] will throw if used.
/// One such case is if the packages are resolved relative to a
/// `packages/` directory available over HTTP.
abstract class Packages {

  /// A [Packages] resolver containing no packages.
  ///
  /// This constant object is returned by [find] above if no
  /// package resolution strategy is found.
  static const Packages noPackages = const NoPackages();

  /// Create a `Packages` object based on a map from package name to base URI.
  ///
  /// The resulting `Packages` object will resolve package URIs by using this
  /// map.
  /// There is no validation of the map containing only valid package names,
  factory Packages(Map<String, Uri> packageMapping) =>
      new MapPackages(packageMapping);

  /// Attempts to find a package resolution strategy for a Dart script.
  ///
  /// The [baseLocation] should point to a Dart script or to its directory.
  /// The function goes through the following steps in order to search for
  /// a packages resolution strategy:
  ///
  /// * First check if a `.packages` file in the script's directory.
  ///   If a file is found, its content is loaded and interpreted as a map
  ///   from package names to package location URIs.
  ///   If loading or parsing of the file fails, so does this function.
  /// * Then if `baseLocation` is not a `file:` URI,
  ///   assume that a `packages/` directory exists in the script's directory,
  ///   and return a `Packages` object that resolves package URIs as
  ///   paths into that directory.
  /// * If `baseLocation` is a `file:` URI, instead *check* whether
  ///   a `packages/` directory exists in the script directory.
  ///   If it does, return a `Packages` object that resolves package URIs
  ///   as paths into that directory. This `Packages` object is able to
  ///   read the directory and see which packages are available.
  /// * Otherwise, check each directory in the parent path of `baseLocation`
  ///   for the existence of a `.packages` file. If one is found, it is loaded
  ///   just as in the first step.
  /// * If no file is found before reaching the file system root,
  ///   the constant [noPacakages] is returned. It's a `Packages` object
  ///   with no available packages.
  ///
  static Future<Packages> find(Uri baseLocation) => findPackages(baseLocation);

  /// Resolve a package URI into a non-package URI.
  ///
  /// Translates a `package:` URI, according to the package resolution
  /// strategy, into a URI that can be loaded.
  /// By default, only `file`, `http` and `https` URIs are returned.
  /// Custom `Packages` objects may return other URIs.
  ///
  /// If resolution fails because a package with the requested package name
  /// is not available, the [notFound] function is called.
  /// If no `notFound` function is provided, it defaults to throwing an error.
  ///
  /// The [packageUri] must be a valid package URI.
  Uri resolve(Uri packageUri, {Uri notFound(Uri packageUri)});

  /// Return the names of the available packages.
  ///
  /// Returns an iterable that allows iterating the names of available packages.
  ///
  /// Some `Packages` objects are unable to find the package names,
  /// and getting `packages` from such a `Packages` object will throw.
  Iterable<String> get packages;

  /// Return the names-to-base-URI mapping of the available packages.
  ///
  /// Returns a map from package name to a base URI.
  /// The [resolve] method will resolve a package URI with a specific package
  /// name to a path extending the base URI that this map gives for that
  /// package name.
  ///
  /// Some `Packages` objects are unable to find the package names,
  /// and calling `asMap` on such a `Packages` object will throw.
  Map<String, Uri> asMap();
}
