// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'errors.dart';
import "package_config.dart";
import "util.dart";

export "package_config.dart";

// Implementations of the main data types exposed by the API of this package.

class SimplePackageConfig implements PackageConfig {
  final int version;
  final Map<String, Package> _packages;
  final PackageTree _packageTree;
  final dynamic extraData;

  factory SimplePackageConfig(int version, Iterable<Package> packages,
      [dynamic extraData, void onError(Object error)]) {
    onError ??= throwError;
    var validVersion = _validateVersion(version, onError);
    var sortedPackages = [...packages]..sort(_compareRoot);
    var packageTree = _validatePackages(packages, sortedPackages, onError);
    return SimplePackageConfig._(validVersion, packageTree,
        {for (var p in packageTree.allPackages) p.name: p}, extraData);
  }

  SimplePackageConfig._(
      this.version, this._packageTree, this._packages, this.extraData);

  /// Creates empty configuration.
  ///
  /// The empty configuration can be used in cases where no configuration is
  /// found, but code expects a non-null configuration.
  const SimplePackageConfig.empty()
      : version = 1,
        _packageTree = const EmptyPackageTree(),
        _packages = const <String, Package>{},
        extraData = null;

  static int _validateVersion(int version, void onError(Object error)) {
    if (version < 0 || version > PackageConfig.maxVersion) {
      onError(PackageConfigArgumentError(version, "version",
          "Must be in the range 1 to ${PackageConfig.maxVersion}"));
      return 2; // The minimal version supporting a SimplePackageConfig.
    }
    return version;
  }

  static PackageTree _validatePackages(Iterable<Package> originalPackages,
      List<Package> packages, void onError(Object error)) {
    var packageNames = <String>{};
    var tree = MutablePackageTree();
    for (var originalPackage in packages) {
      if (originalPackage == null) {
        onError(ArgumentError.notNull("element of packages"));
        continue;
      }
      SimplePackage package;
      if (originalPackage is! SimplePackage) {
        // SimplePackage validates these properties.
        package = SimplePackage.validate(
            originalPackage.name,
            originalPackage.root,
            originalPackage.packageUriRoot,
            originalPackage.languageVersion,
            originalPackage.extraData, (error) {
          if (error is PackageConfigArgumentError) {
            onError(PackageConfigArgumentError(packages, "packages",
                "Package ${package.name}: ${error.message}"));
          } else {
            onError(error);
          }
        });
        if (package == null) continue;
      } else {
        package = originalPackage;
      }
      var name = package.name;
      if (packageNames.contains(name)) {
        onError(PackageConfigArgumentError(
            name, "packages", "Duplicate package name"));
        continue;
      }
      packageNames.add(name);
      tree.add(0, package, (error) {
        if (error is ConflictException) {
          // There is a conflict with an existing package.
          var existingPackage = error.existingPackage;
          if (error.isRootConflict) {
            onError(PackageConfigArgumentError(
                originalPackages,
                "packages",
                "Packages ${package.name} and ${existingPackage.name} "
                    "have the same root directory: ${package.root}.\n"));
          } else {
            assert(error.isPackageRootConflict);
            // Package is inside the package URI root of the existing package.
            onError(PackageConfigArgumentError(
                originalPackages,
                "packages",
                "Package ${package.name} is inside the package URI root of "
                    "package ${existingPackage.name}.\n"
                    "${existingPackage.name} URI root: "
                    "${existingPackage.packageUriRoot}\n"
                    "${package.name} root: ${package.root}\n"));
          }
        } else {
          // Any other error.
          onError(error);
        }
      });
    }
    return tree;
  }

  Iterable<Package> get packages => _packages.values;

  Package /*?*/ operator [](String packageName) => _packages[packageName];

  /// Provides the associated package for a specific [file] (or directory).
  ///
  /// Returns a [Package] which contains the [file]'s path.
  /// That is, the [Package.rootUri] directory is a parent directory
  /// of the [file]'s location.
  /// Returns `null` if the file does not belong to any package.
  Package /*?*/ packageOf(Uri file) => _packageTree.packageOf(file);

  Uri /*?*/ resolve(Uri packageUri) {
    var packageName = checkValidPackageUri(packageUri, "packageUri");
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
    // Find package that file belongs to.
    var package = _packageTree.packageOf(nonPackageUri);
    if (package == null) return null;
    // Check if it is inside the package URI root.
    var path = nonPackageUri.toString();
    var root = package.packageUriRoot.toString();
    if (_beginsWith(package.root.toString().length, root, path)) {
      var rest = path.substring(root.length);
      return Uri(scheme: "package", path: "${package.name}/$rest");
    }
    return null;
  }
}

/// Configuration data for a single package.
class SimplePackage implements Package {
  final String name;
  final Uri root;
  final Uri packageUriRoot;
  final LanguageVersion /*?*/ languageVersion;
  final dynamic extraData;

  SimplePackage._(this.name, this.root, this.packageUriRoot,
      this.languageVersion, this.extraData);

  /// Creates a [SimplePackage] with the provided content.
  ///
  /// The provided arguments must be valid.
  ///
  /// If the arguments are invalid then the error is reported by
  /// calling [onError], then the erroneous entry is ignored.
  ///
  /// If [onError] is provided, the user is expected to be able to handle
  /// errors themselves. An invalid [languageVersion] string
  /// will be replaced with the string `"invalid"`. This allows
  /// users to detect the difference between an absent version and
  /// an invalid one.
  ///
  /// Returns `null` if the input is invalid and an approximately valid package
  /// cannot be salvaged from the input.
  static SimplePackage /*?*/ validate(
      String name,
      Uri root,
      Uri packageUriRoot,
      LanguageVersion /*?*/ languageVersion,
      dynamic extraData,
      void onError(Object error)) {
    var fatalError = false;
    var invalidIndex = checkPackageName(name);
    if (invalidIndex >= 0) {
      onError(PackageConfigFormatException(
          "Not a valid package name", name, invalidIndex));
      fatalError = true;
    }
    if (root.isScheme("package")) {
      onError(PackageConfigArgumentError(
          "$root", "root", "Must not be a package URI"));
      fatalError = true;
    } else if (!isAbsoluteDirectoryUri(root)) {
      onError(PackageConfigArgumentError(
          "$root",
          "root",
          "In package $name: Not an absolute URI with no query or fragment "
              "with a path ending in /"));
      // Try to recover. If the URI has a scheme,
      // then ensure that the path ends with `/`.
      if (!root.hasScheme) {
        fatalError = true;
      } else if (!root.path.endsWith("/")) {
        root = root.replace(path: root.path + "/");
      }
    }
    if (packageUriRoot == null) {
      packageUriRoot = root;
    } else if (!fatalError) {
      packageUriRoot = root.resolveUri(packageUriRoot);
      if (!isAbsoluteDirectoryUri(packageUriRoot)) {
        onError(PackageConfigArgumentError(
            packageUriRoot,
            "packageUriRoot",
            "In package $name: Not an absolute URI with no query or fragment "
                "with a path ending in /"));
        packageUriRoot = root;
      } else if (!isUriPrefix(root, packageUriRoot)) {
        onError(PackageConfigArgumentError(packageUriRoot, "packageUriRoot",
            "The package URI root is not below the package root"));
        packageUriRoot = root;
      }
    }
    if (fatalError) return null;
    return SimplePackage._(
        name, root, packageUriRoot, languageVersion, extraData);
  }
}

/// Checks whether [version] is a valid Dart language version string.
///
/// The format is (as RegExp) `^(0|[1-9]\d+)\.(0|[1-9]\d+)$`.
///
/// Reports a format exception on [onError] if not, or if the numbers
/// are too large (at most 32-bit signed integers).
LanguageVersion parseLanguageVersion(
    String source, void onError(Object error)) {
  var index = 0;
  // Reads a positive decimal numeral. Returns the value of the numeral,
  // or a negative number in case of an error.
  // Starts at [index] and increments the index to the position after
  // the numeral.
  // It is an error if the numeral value is greater than 0x7FFFFFFFF.
  // It is a recoverable error if the numeral starts with leading zeros.
  int readNumeral() {
    const maxValue = 0x7FFFFFFF;
    if (index == source.length) {
      onError(PackageConfigFormatException("Missing number", source, index));
      return -1;
    }
    var start = index;

    var char = source.codeUnitAt(index);
    var digit = char ^ 0x30;
    if (digit > 9) {
      onError(PackageConfigFormatException("Missing number", source, index));
      return -1;
    }
    var firstDigit = digit;
    var value = 0;
    do {
      value = value * 10 + digit;
      if (value > maxValue) {
        onError(
            PackageConfigFormatException("Number too large", source, start));
        return -1;
      }
      index++;
      if (index == source.length) break;
      char = source.codeUnitAt(index);
      digit = char ^ 0x30;
    } while (digit <= 9);
    if (firstDigit == 0 && index > start + 1) {
      onError(PackageConfigFormatException(
          "Leading zero not allowed", source, start));
    }
    return value;
  }

  var major = readNumeral();
  if (major < 0) {
    return SimpleInvalidLanguageVersion(source);
  }
  if (index == source.length || source.codeUnitAt(index) != $dot) {
    onError(PackageConfigFormatException("Missing '.'", source, index));
    return SimpleInvalidLanguageVersion(source);
  }
  index++;
  var minor = readNumeral();
  if (minor < 0) {
    return SimpleInvalidLanguageVersion(source);
  }
  if (index != source.length) {
    onError(PackageConfigFormatException(
        "Unexpected trailing character", source, index));
    return SimpleInvalidLanguageVersion(source);
  }
  return SimpleLanguageVersion(major, minor, source);
}

abstract class _SimpleLanguageVersionBase implements LanguageVersion {
  int compareTo(LanguageVersion other) {
    var result = major.compareTo(other.major);
    if (result != 0) return result;
    return minor.compareTo(other.minor);
  }
}

class SimpleLanguageVersion extends _SimpleLanguageVersionBase {
  final int major;
  final int minor;
  String /*?*/ _source;
  SimpleLanguageVersion(this.major, this.minor, this._source);

  bool operator ==(Object other) =>
      other is LanguageVersion && major == other.major && minor == other.minor;

  int get hashCode => (major * 17 ^ minor * 37) & 0x3FFFFFFF;

  String toString() => _source ??= "$major.$minor";
}

class SimpleInvalidLanguageVersion extends _SimpleLanguageVersionBase
    implements InvalidLanguageVersion {
  final String _source;
  SimpleInvalidLanguageVersion(this._source);
  int get major => -1;
  int get minor => -1;

  String toString() => _source;
}

abstract class PackageTree {
  Iterable<Package> get allPackages;
  SimplePackage /*?*/ packageOf(Uri file);
}

/// Packages of a package configuration ordered by root path.
///
/// A package has a root path and a package root path, where the latter
/// contains the files exposed by `package:` URIs.
///
/// A package is said to be inside another package if the root path URI of
/// the latter is a prefix of the root path URI of the former.
///
/// No two packages of a package may have the same root path, so this
/// path prefix ordering defines a tree-like partial ordering on packages
/// of a configuration.
///
/// The package root path of a package must not be inside another package's
/// root path.
/// Entire other packages are allowed inside a package's root or
/// package root path.
///
/// The package tree contains an ordered mapping of unrelated packages
/// (represented by their name) to their immediately nested packages' names.
class MutablePackageTree implements PackageTree {
  /// A list of packages that are not nested inside each other.
  final List<SimplePackage> packages = [];

  /// The tree of the immediately nested packages inside each package.
  ///
  /// Indexed by [Package.name].
  /// If a package has no nested packages (which is most often the case),
  /// there is no tree object associated with it.
  Map<String, MutablePackageTree /*?*/ > /*?*/ _packageChildren;

  Iterable<Package> get allPackages sync* {
    for (var package in packages) yield package;
    if (_packageChildren != null) {
      for (var tree in _packageChildren.values) yield* tree.allPackages;
    }
  }

  /// Tries to (add) `package` to the tree.
  ///
  /// Reports a [ConflictException] if the added package conflicts with an
  /// existing package.
  /// It conflicts if its root or package root is the same as another
  /// package's root or package root, or is between the two.
  ///
  /// If a conflict is detected between [package] and a previous package,
  /// then [onError] is called with a [ConflictException] object
  /// and the [package] is not added to the tree.
  ///
  /// The packages are added in order of their root path.
  /// It is never necessary to insert a node between two existing levels.
  void add(int start, SimplePackage package, void onError(Object error)) {
    var path = package.root.toString();
    for (var treePackage in packages) {
      // Check is package is inside treePackage.
      var treePackagePath = treePackage.root.toString();
      assert(treePackagePath.length > start);
      assert(path.startsWith(treePackagePath.substring(0, start)));
      if (_beginsWith(start, treePackagePath, path)) {
        // Package *is* inside treePackage.
        var treePackagePathLength = treePackagePath.length;
        if (path.length == treePackagePathLength) {
          // Has same root. Do not add package.
          onError(ConflictException.root(package, treePackage));
          return;
        }
        var treePackageUriRoot = treePackage.packageUriRoot.toString();
        if (_beginsWith(treePackagePathLength, path, treePackageUriRoot)) {
          // The treePackage's package root is inside package, which is inside
          // the treePackage. This is not allowed.
          onError(ConflictException.packageRoot(package, treePackage));
          return;
        }
        _treeOf(treePackage).add(treePackagePathLength, package, onError);
        return;
      }
    }
    packages.add(package);
  }

  SimplePackage /*?*/ packageOf(Uri file) {
    return findPackageOf(0, file.toString());
  }

  /// Finds package containing [path] in this tree.
  ///
  /// Returns `null` if no such package is found.
  ///
  /// Assumes the first [start] characters of path agrees with all
  /// the packages at this level of the tree.
  SimplePackage /*?*/ findPackageOf(int start, String path) {
    for (var childPackage in packages) {
      var childPath = childPackage.root.toString();
      if (_beginsWith(start, childPath, path)) {
        // The [package] is inside [childPackage].
        var childPathLength = childPath.length;
        if (path.length == childPathLength) return childPackage;
        var uriRoot = childPackage.packageUriRoot.toString();
        // Is [package] is inside the URI root of [childPackage].
        if (uriRoot.length == childPathLength ||
            _beginsWith(childPathLength, uriRoot, path)) {
          return childPackage;
        }
        // Otherwise add [package] as child of [childPackage].
        // TODO(lrn): When NNBD comes, convert to:
        // return _packageChildren?[childPackage.name]
        //     ?.packageOf(childPathLength, path) ?? childPackage;
        if (_packageChildren == null) return childPackage;
        var childTree = _packageChildren[childPackage.name];
        if (childTree == null) return childPackage;
        return childTree.findPackageOf(childPathLength, path) ?? childPackage;
      }
    }
    return null;
  }

  /// Returns the [PackageTree] of the children of [package].
  ///
  /// Ensures that the object is allocated if necessary.
  MutablePackageTree _treeOf(SimplePackage package) {
    var children = _packageChildren ??= {};
    return children[package.name] ??= MutablePackageTree();
  }
}

class EmptyPackageTree implements PackageTree {
  const EmptyPackageTree();

  Iterable<Package> get allPackages => const Iterable<Package>.empty();

  SimplePackage packageOf(Uri file) => null;
}

/// Checks whether [longerPath] begins with [parentPath].
///
/// Skips checking the [start] first characters which are assumed to
/// already have been matched.
bool _beginsWith(int start, String parentPath, String longerPath) {
  if (longerPath.length < parentPath.length) return false;
  for (var i = start; i < parentPath.length; i++) {
    if (longerPath.codeUnitAt(i) != parentPath.codeUnitAt(i)) return false;
  }
  return true;
}

/// Conflict between packages added to the same configuration.
///
/// The [package] conflicts with [existingPackage] if it has
/// the same root path ([isRootConflict]) or the package URI root path
/// of [existingPackage] is inside the root path of [package]
/// ([isPackageRootConflict]).
class ConflictException {
  /// The existing package that [package] conflicts with.
  final SimplePackage existingPackage;

  /// The package that could not be added without a conflict.
  final SimplePackage package;

  /// Whether the conflict is with the package URI root of [existingPackage].
  final bool isPackageRootConflict;

  /// Creates a root conflict between [package] and [existingPackage].
  ConflictException.root(this.package, this.existingPackage)
      : isPackageRootConflict = false;

  /// Creates a package root conflict between [package] and [existingPackage].
  ConflictException.packageRoot(this.package, this.existingPackage)
      : isPackageRootConflict = true;

  /// WHether the conflict is with the root URI of [existingPackage].
  bool get isRootConflict => !isPackageRootConflict;
}

/// Used for sorting packages by root path.
int _compareRoot(Package p1, Package p2) =>
    p1.root.toString().compareTo(p2.root.toString());
