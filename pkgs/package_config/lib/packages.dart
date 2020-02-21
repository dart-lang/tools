// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Deprecated("Use the package_config.json based API")
library package_config.packages;

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
@Deprecated("Use the package_config.json based API")
abstract class Packages {
  /// A [Packages] resolver containing no packages.
  ///
  /// This constant object is returned by [find] above if no
  /// package resolution strategy is found.
  static const Packages noPackages = NoPackages();

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

  /// Retrieve metadata associated with a package.
  ///
  /// Metadata have string keys and values, and are looked up by key.
  ///
  /// Returns `null` if the argument is not a valid package name,
  /// or if the package is not one of the packages configured by
  /// this packages object, or if the package does not have associated
  /// metadata with the provided [key].
  ///
  /// Not all `Packages` objects can support metadata.
  /// Those will always return `null`.
  String packageMetadata(String packageName, String key);

  /// Retrieve metadata associated with a library.
  ///
  /// If [libraryUri] is a `package:` URI, the returned value
  /// is the same that would be returned by [packageMetadata] with
  /// the package's name and the same key.
  ///
  /// If [libraryUri] is not a `package:` URI, and this [Packages]
  /// object has a [defaultPackageName], then the [key] is looked
  /// up on the default package instead.
  ///
  /// Otherwise the result is `null`.
  String libraryMetadata(Uri libraryUri, String key);

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

  /// The name of the "default package".
  ///
  /// A default package is a package that *non-package* libraries
  /// may be considered part of for some purposes.
  ///
  /// The value is `null` if there is no default package.
  /// Not all implementations of [Packages] supports a default package,
  /// and will always have a `null` value for those.
  String get defaultPackageName;
}
