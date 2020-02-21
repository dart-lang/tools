// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Analyse a directory structure and find packages resolvers for each
/// sub-directory.
///
/// The resolvers are generally the same that would be found by using
/// the `discovery.dart` library on each sub-directory in turn,
/// but more efficiently and with some heuristics for directories that
/// wouldn't otherwise have a package resolution strategy, or that are
/// determined to be "package directories" themselves.
@Deprecated("Use the package_config.json based API")
library package_config.discovery_analysis;

import "dart:collection" show HashMap;
import "dart:io" show File, Directory;

import "package:path/path.dart" as path;

import "packages.dart";
import "packages_file.dart" as pkgfile;
import "src/packages_impl.dart";
import "src/packages_io_impl.dart";

/// Associates a [Packages] package resolution strategy with a directory.
///
/// The package resolution applies to the directory and any sub-directory
/// that doesn't have its own overriding child [PackageContext].
abstract class PackageContext {
  /// The directory that introduced the [packages] resolver.
  Directory get directory;

  /// A [Packages] resolver that applies to the directory.
  ///
  /// Introduced either by a `.packages` file or a `packages/` directory.
  Packages get packages;

  /// Child contexts that apply to sub-directories of [directory].
  List<PackageContext> get children;

  /// Look up the [PackageContext] that applies to a specific directory.
  ///
  /// The directory must be inside [directory].
  PackageContext operator [](Directory directory);

  /// A map from directory to package resolver.
  ///
  /// Has an entry for this package context and for each child context
  /// contained in this one.
  Map<Directory, Packages> asMap();

  /// Analyze [directory] and sub-directories for package resolution strategies.
  ///
  /// Returns a mapping from sub-directories to [Packages] objects.
  ///
  /// The analysis assumes that there are no `.packages` files in a parent
  /// directory of `directory`. If there is, its corresponding `Packages` object
  /// should be provided as `root`.
  static PackageContext findAll(Directory directory,
      {Packages root = Packages.noPackages}) {
    if (!directory.existsSync()) {
      throw ArgumentError("Directory not found: $directory");
    }
    var contexts = <PackageContext>[];
    void findRoots(Directory directory) {
      Packages packages;
      List<PackageContext> oldContexts;
      var packagesFile = File(path.join(directory.path, ".packages"));
      if (packagesFile.existsSync()) {
        packages = _loadPackagesFile(packagesFile);
        oldContexts = contexts;
        contexts = [];
      } else {
        var packagesDir = Directory(path.join(directory.path, "packages"));
        if (packagesDir.existsSync()) {
          packages = FilePackagesDirectoryPackages(packagesDir);
          oldContexts = contexts;
          contexts = [];
        }
      }
      for (var entry in directory.listSync()) {
        if (entry is Directory) {
          if (packages == null || !entry.path.endsWith("/packages")) {
            findRoots(entry);
          }
        }
      }
      if (packages != null) {
        oldContexts.add(_PackageContext(directory, packages, contexts));
        contexts = oldContexts;
      }
    }

    findRoots(directory);
    // If the root is not itself context root, add a the wrapper context.
    if (contexts.length == 1 && contexts[0].directory == directory) {
      return contexts[0];
    }
    return _PackageContext(directory, root, contexts);
  }
}

class _PackageContext implements PackageContext {
  final Directory directory;
  final Packages packages;
  final List<PackageContext> children;
  _PackageContext(this.directory, this.packages, List<PackageContext> children)
      : children = List<PackageContext>.unmodifiable(children);

  Map<Directory, Packages> asMap() {
    var result = HashMap<Directory, Packages>();
    void recurse(_PackageContext current) {
      result[current.directory] = current.packages;
      for (var child in current.children) {
        recurse(child);
      }
    }

    recurse(this);
    return result;
  }

  PackageContext operator [](Directory directory) {
    var path = directory.path;
    if (!path.startsWith(this.directory.path)) {
      throw ArgumentError("Not inside $path: $directory");
    }
    var current = this;
    // The current path is know to agree with directory until deltaIndex.
    var deltaIndex = current.directory.path.length;
    List children = current.children;
    var i = 0;
    while (i < children.length) {
      // TODO(lrn): Sort children and use binary search.
      _PackageContext child = children[i];
      var childPath = child.directory.path;
      if (_stringsAgree(path, childPath, deltaIndex, childPath.length)) {
        deltaIndex = childPath.length;
        if (deltaIndex == path.length) {
          return child;
        }
        current = child;
        children = current.children;
        i = 0;
        continue;
      }
      i++;
    }
    return current;
  }

  static bool _stringsAgree(String a, String b, int start, int end) {
    if (a.length < end || b.length < end) return false;
    for (var i = start; i < end; i++) {
      if (a.codeUnitAt(i) != b.codeUnitAt(i)) return false;
    }
    return true;
  }
}

Packages _loadPackagesFile(File file) {
  var uri = Uri.file(file.path);
  var bytes = file.readAsBytesSync();
  var map = pkgfile.parse(bytes, uri);
  return MapPackages(map);
}
