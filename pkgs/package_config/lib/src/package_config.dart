// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'errors.dart';
import 'package_config_json.dart';
import 'util.dart';

/// A package configuration.
///
/// Associates configuration data to packages and files in packages.
///
/// More members may be added to this class in the future,
/// so classes outside of this package must not implement [PackageConfig]
/// or any subclass of it.
abstract final class PackageConfig {
  /// The lowest configuration version currently supported.
  static const int minVersion = 2;

  /// The highest configuration version currently supported.
  static const int maxVersion = 2;

  /// An empty package configuration.
  ///
  /// A package configuration with no available packages.
  /// Is used as a default value where a package configuration
  /// is expected, but none have been specified or found.
  static const PackageConfig empty = SimplePackageConfig.empty();

  /// Creates a package configuration with the provided available [packages].
  ///
  /// The packages must be valid packages (valid package name, valid
  /// absolute directory URIs, valid language version, if any),
  /// and there must not be two packages with the same name.
  ///
  /// The package's root ([Package.root]) and package-root
  /// ([Package.packageUriRoot]) paths must satisfy a number of constraints
  /// We say that one path (which we know ends with a `/` character)
  /// is inside another path, if the latter path is a prefix of the former path,
  /// including the two paths being the same.
  ///
  /// * No package's root must be the same as another package's root.
  /// * The package-root of a package must be inside the package's root.
  /// * If one package's package-root is inside another package's root,
  ///   then the latter package's package root must not be inside the former
  ///   package's root. (No getting between a package and its package root!)
  ///   This also disallows a package's root being the same as another
  ///   package's package root.
  ///
  /// If supplied, the [extraData] will be available as the
  /// [PackageConfig.extraData] of the created configuration.
  ///
  /// The version of the resulting configuration is always [maxVersion].
  factory PackageConfig(Iterable<Package> packages, {Object? extraData}) =>
      SimplePackageConfig(maxVersion, packages, extraData);

  /// Parses a package configuration file.
  ///
  /// The [bytes] must be an UTF-8 encoded JSON object
  /// containing a valid package configuration.
  ///
  /// The [baseUri] is used as the base for resolving relative
  /// URI references in the configuration file. If the configuration
  /// has been read from a file, the [baseUri] can be the URI of that
  /// file, or of the directory it occurs in.
  ///
  /// If [onError] is provided, errors found during parsing or building
  /// the configuration are reported by calling [onError] instead of
  /// throwing, and parser makes a *best effort* attempt to continue
  /// despite the error. The input must still be valid JSON.
  /// The result may be [PackageConfig.empty] if there is no way to
  /// extract useful information from the bytes.
  static PackageConfig parseBytes(Uint8List bytes, Uri baseUri,
          {void Function(Object error)? onError}) =>
      parsePackageConfigBytes(bytes, baseUri, onError ?? throwError);

  /// Parses a package configuration file.
  ///
  /// The [configuration] must be a JSON object
  /// containing a valid package configuration.
  ///
  /// The [baseUri] is used as the base for resolving relative
  /// URI references in the configuration file. If the configuration
  /// has been read from a file, the [baseUri] can be the URI of that
  /// file, or of the directory it occurs in.
  ///
  /// If [onError] is provided, errors found during parsing or building
  /// the configuration are reported by calling [onError] instead of
  /// throwing, and parser makes a *best effort* attempt to continue
  /// despite the error. The input must still be valid JSON.
  /// The result may be [PackageConfig.empty] if there is no way to
  /// extract useful information from the bytes.
  static PackageConfig parseString(String configuration, Uri baseUri,
          {void Function(Object error)? onError}) =>
      parsePackageConfigString(configuration, baseUri, onError ?? throwError);

  /// Parses the JSON data of a package configuration file.
  ///
  /// The [jsonData] must be a JSON-like Dart data structure,
  /// like the one provided by parsing JSON text using `dart:convert`,
  /// containing a valid package configuration.
  ///
  /// The [baseUri] is used as the base for resolving relative
  /// URI references in the configuration file. If the configuration
  /// has been read from a file, the [baseUri] can be the URI of that
  /// file, or of the directory it occurs in.
  ///
  /// If [onError] is provided, errors found during parsing or building
  /// the configuration are reported by calling [onError] instead of
  /// throwing, and parser makes a *best effort* attempt to continue
  /// despite the error. The input must still be valid JSON.
  /// The result may be [PackageConfig.empty] if there is no way to
  /// extract useful information from the bytes.
  static PackageConfig parseJson(Object? jsonData, Uri baseUri,
          {void Function(Object error)? onError}) =>
      parsePackageConfigJson(jsonData, baseUri, onError ?? throwError);

  /// Writes a configuration file for this configuration on [output].
  ///
  /// If [baseUri] is provided, URI references in the generated file
  /// will be made relative to [baseUri] where possible.
  static void writeBytes(PackageConfig configuration, Sink<Uint8List> output,
      [Uri? baseUri]) {
    writePackageConfigJsonUtf8(configuration, baseUri, output);
  }

  /// Writes a configuration JSON text for this configuration on [output].
  ///
  /// If [baseUri] is provided, URI references in the generated file
  /// will be made relative to [baseUri] where possible.
  static void writeString(PackageConfig configuration, StringSink output,
      [Uri? baseUri]) {
    writePackageConfigJsonString(configuration, baseUri, output);
  }

  /// Converts a configuration to a JSON-like data structure.
  ///
  /// If [baseUri] is provided, URI references in the generated data
  /// will be made relative to [baseUri] where possible.
  static Map<String, Object?> toJson(PackageConfig configuration,
          [Uri? baseUri]) =>
      packageConfigToJson(configuration, baseUri);

  /// The configuration version number.
  ///
  /// So far these have been 1 or 2, where
  /// * Version one is the `.packages` file format, and is no longer supported.
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
  /// Returns the [Package] from [packages] with [packageName] as
  /// [Package.name]. Returns `null` if the package is not available in the
  /// current configuration.
  Package? operator [](String packageName);

  /// Provides the associated package for a specific [file] (or directory).
  ///
  /// Returns a [Package] which contains the [file]'s path, if any.
  /// That is, the [Package.root] directory is a parent directory
  /// of the [file]'s location.
  ///
  /// Returns `null` if the file does not belong to any package.
  Package? packageOf(Uri file);

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
  Uri? resolve(Uri packageUri);

  /// The package URI which resolves to [nonPackageUri].
  ///
  /// The [nonPackageUri] must not have any query or fragment part,
  /// and it must not have `package` as scheme.
  /// Throws an [ArgumentError] (which also implements [PackageConfigError])
  /// if the non-package URI is not valid.
  ///
  /// Returns a package URI which [resolve] will convert to [nonPackageUri],
  /// if any such URI exists. Returns `null` if no such package URI exists.
  Uri? toPackageUri(Uri nonPackageUri);

  /// Extra data associated with the package configuration.
  ///
  /// The data may be in any format, depending on who introduced it.
  /// The standard `package_config.json` file storage will only store
  /// JSON-like list/map data structures.
  Object? get extraData;
}

/// Configuration data for a single package.
abstract final class Package {
  /// Creates a package with the provided properties.
  ///
  /// The [name] must be a valid package name.
  /// The [root] must be an absolute directory URI, meaning an absolute URI
  /// with no query or fragment path and a path starting and ending with `/`.
  /// The [packageUriRoot], if provided, must be either an absolute
  /// directory URI or a relative URI reference which is then resolved
  /// relative to [root]. It must then also be a subdirectory of [root],
  /// or the same directory, and must end with `/`.
  /// If [languageVersion] is supplied, it must be a valid Dart language
  /// version, which means two decimal integer literals separated by a `.`,
  /// where the integer literals have no leading zeros unless they are
  /// a single zero digit.
  ///
  /// The [relativeRoot] controls whether the [root] is written as
  /// relative to the `package_config.json` file when the package
  /// configuration is written to a file. It defaults to being relative.
  ///
  /// If [extraData] is supplied, it will be available as the
  /// [Package.extraData] of the created package.
  factory Package(String name, Uri root,
          {Uri? packageUriRoot,
          LanguageVersion? languageVersion,
          Object? extraData,
          bool relativeRoot = true}) =>
      SimplePackage.validate(name, root, packageUriRoot, languageVersion,
          extraData, relativeRoot, throwError)!;

  /// The package-name of the package.
  String get name;

  /// The location of the root of the package.
  ///
  /// Is always an absolute URI with no query or fragment parts,
  /// and with a path ending in `/`.
  ///
  /// All files in the [root] directory are considered
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
  /// A package version is defined by two non-negative numbers,
  /// the *major* and *minor* version numbers.
  ///
  /// A package may have no language version associated with it
  /// in the package configuration, in which case tools should
  /// use a default behavior for the package.
  LanguageVersion? get languageVersion;

  /// Extra data associated with the specific package.
  ///
  /// The data may be in any format, depending on who introduced it.
  /// The standard `package_config.json` file storage will only store
  /// JSON-like list/map data structures.
  Object? get extraData;

  /// Whether the [root] URI should be written as relative.
  ///
  /// When the configuration is written to a `package_config.json`
  /// file, the [root] URI can be either relative to the file
  /// location or absolute, controller by this value.
  bool get relativeRoot;
}

/// A language version.
///
/// A language version is represented by two non-negative integers,
/// the [major] and [minor] version numbers.
///
/// If errors during parsing are handled using an `onError` handler,
/// then an *invalid* language version may be represented by an
/// [InvalidLanguageVersion] object.
abstract final class LanguageVersion implements Comparable<LanguageVersion> {
  /// The maximal value allowed by [major] and [minor] values;
  static const int maxValue = 0x7FFFFFFF;

  /// Constructs a [LanguageVersion] with the specified
  /// [major] and [minor] version numbers.
  ///
  /// Both [major] and [minor] must be greater than or equal to 0
  /// and less than or equal to [maxValue].
  factory LanguageVersion(int major, int minor) {
    RangeError.checkValueInInterval(major, 0, maxValue, 'major');
    RangeError.checkValueInInterval(minor, 0, maxValue, 'minor');
    return SimpleLanguageVersion(major, minor, null);
  }

  /// Parses a language version string.
  ///
  /// A valid language version string has the form
  ///
  /// > *decimalNumber* `.` *decimalNumber*
  ///
  /// where a *decimalNumber* is a non-empty sequence of decimal digits
  /// with no unnecessary leading zeros (the decimal number only starts
  /// with a zero digit if that digit is the entire number).
  /// No spaces are allowed in the string.
  ///
  /// If the [source] is valid then it is parsed into a valid
  /// [LanguageVersion] object.
  /// If not, then the [onError] is called with a [FormatException].
  /// If [onError] is not supplied, it defaults to throwing the exception.
  /// If the call does not throw, then an [InvalidLanguageVersion] is returned
  /// containing the original [source].
  static LanguageVersion parse(String source,
          {void Function(Object error)? onError}) =>
      parseLanguageVersion(source, onError ?? throwError);

  /// The major language version.
  ///
  /// A non-negative integer less than 2<sup>31</sup>.
  ///
  /// The value is negative for objects representing *invalid* language
  /// versions ([InvalidLanguageVersion]).
  int get major;

  /// The minor language version.
  ///
  /// A non-negative integer less than 2<sup>31</sup>.
  ///
  /// The value is negative for objects representing *invalid* language
  /// versions ([InvalidLanguageVersion]).
  int get minor;

  /// Compares language versions.
  ///
  /// Two language versions are equal if they have the same
  /// major and minor version numbers.
  ///
  /// A language version is greater than another if the former's major version
  /// is greater than the latter's major version, or if they have
  /// the same major version and the former's minor version is greater than
  /// the latter's.
  ///
  /// Invalid language versions are ordered before all valid versions,
  /// and are all ordered together.
  @override
  int compareTo(LanguageVersion other);

  /// Whether this language version is less than [other].
  ///
  /// If either version being compared is an [InvalidLanguageVersion],
  /// a [StateError] is thrown. Verify versions are valid before comparing them.
  ///
  /// For details on how valid language versions are compared,
  /// check out [LanguageVersion.compareTo].
  bool operator <(LanguageVersion other);

  /// Whether this language version is less than or equal to [other].
  ///
  /// If either version being compared is an [InvalidLanguageVersion],
  /// a [StateError] is thrown. Verify versions are valid before comparing them.
  ///
  /// For details on how valid language versions are compared,
  /// check out [LanguageVersion.compareTo].
  bool operator <=(LanguageVersion other);

  /// Whether this language version is greater than [other].
  ///
  /// Neither version being compared must be  an [InvalidLanguageVersion].
  ///
  /// For details on how valid language versions are compared,
  /// check out [LanguageVersion.compareTo].
  bool operator >(LanguageVersion other);

  /// Whether this language version is greater than or equal to [other].
  ///
  /// Neither version being compared must be  an [InvalidLanguageVersion].
  ///
  /// For details on how valid language versions are compared,
  /// check out [LanguageVersion.compareTo].
  bool operator >=(LanguageVersion other);

  /// Valid language versions with the same [major] and [minor] values are
  /// equal.
  ///
  /// Invalid language versions ([InvalidLanguageVersion]) are not equal to
  /// any other object.
  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  /// A string representation of the language version.
  ///
  /// A valid language version is represented as
  /// `"${version.major}.${version.minor}"`.
  @override
  String toString();
}

/// An *invalid* language version.
///
/// Stored in a [Package] when the original language version string
/// was invalid and a `onError` handler was passed to the parser
/// which did not throw on an error.
/// The caller which provided the `onError` handler which was called
/// should be prepared to encounter invalid values.
abstract final class InvalidLanguageVersion implements LanguageVersion {
  /// The value -1 for an invalid language version.
  @override
  int get major;

  /// The value -1 for an invalid language version.
  @override
  int get minor;

  /// An invalid language version is only equal to itself.
  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  /// The original invalid version string.
  @override
  String toString();
}

// --------------------------------------------------------------------
// Implementation of interfaces.

const bool _disallowPackagesInsidePackageUriRoot = false;

// Implementations of the main data types exposed by the API of this package.

final class SimplePackageConfig implements PackageConfig {
  @override
  final int version;
  final Map<String, Package> _packages;
  final PackageTree _packageTree;
  @override
  final Object? extraData;

  factory SimplePackageConfig(int version, Iterable<Package> packages,
      [Object? extraData, void Function(Object error)? onError]) {
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
  ///
  /// The version number is [PackageConfig.maxVersion] to avoid
  /// minimum-version filters discarding the configuration.
  const SimplePackageConfig.empty()
      : version = PackageConfig.maxVersion,
        _packageTree = const EmptyPackageTree(),
        _packages = const <String, Package>{},
        extraData = null;

  static int _validateVersion(
      int version, void Function(Object error) onError) {
    if (version < 0 || version > PackageConfig.maxVersion) {
      onError(PackageConfigArgumentError(version, 'version',
          'Must be in the range 1 to ${PackageConfig.maxVersion}'));
      return 2; // The minimal version supporting a SimplePackageConfig.
    }
    return version;
  }

  static PackageTree _validatePackages(Iterable<Package> originalPackages,
      List<Package> packages, void Function(Object error) onError) {
    var packageNames = <String>{};
    var tree = TriePackageTree();
    for (var originalPackage in packages) {
      SimplePackage? newPackage;
      if (originalPackage is! SimplePackage) {
        // SimplePackage validates these properties.
        newPackage = SimplePackage.validate(
            originalPackage.name,
            originalPackage.root,
            originalPackage.packageUriRoot,
            originalPackage.languageVersion,
            originalPackage.extraData,
            originalPackage.relativeRoot, (error) {
          if (error is PackageConfigArgumentError) {
            onError(PackageConfigArgumentError(packages, 'packages',
                'Package ${newPackage!.name}: ${error.message}'));
          } else {
            onError(error);
          }
        });
        if (newPackage == null) continue;
      } else {
        newPackage = originalPackage;
      }
      var name = newPackage.name;
      if (packageNames.contains(name)) {
        onError(PackageConfigArgumentError(
            name, 'packages', "Duplicate package name '$name'"));
        continue;
      }
      packageNames.add(name);
      tree.add(newPackage, (error) {
        if (error is ConflictException) {
          // There is a conflict with an existing package.
          var existingPackage = error.existingPackage;
          switch (error.conflictType) {
            case ConflictType.sameRoots:
              onError(PackageConfigArgumentError(
                  originalPackages,
                  'packages',
                  'Packages ${newPackage!.name} and ${existingPackage.name} '
                      'have the same root directory: ${newPackage.root}.\n'));
              break;
            case ConflictType.interleaving:
              // The new package is inside the package URI root of the existing
              // package.
              onError(PackageConfigArgumentError(
                  originalPackages,
                  'packages',
                  'Package ${newPackage!.name} is inside the root of '
                      'package ${existingPackage.name}, and the package root '
                      'of ${existingPackage.name} is inside the root of '
                      '${newPackage.name}.\n'
                      '${existingPackage.name} package root: '
                      '${existingPackage.packageUriRoot}\n'
                      '${newPackage.name} root: ${newPackage.root}\n'));
              break;
            case ConflictType.insidePackageRoot:
              onError(PackageConfigArgumentError(
                  originalPackages,
                  'packages',
                  'Package ${newPackage!.name} is inside the package root of '
                      'package ${existingPackage.name}.\n'
                      '${existingPackage.name} package root: '
                      '${existingPackage.packageUriRoot}\n'
                      '${newPackage.name} root: ${newPackage.root}\n'));
              break;
          }
        } else {
          // Any other error.
          onError(error);
        }
      });
    }
    return tree;
  }

  @override
  Iterable<Package> get packages => _packages.values;

  @override
  Package? operator [](String packageName) => _packages[packageName];

  @override
  Package? packageOf(Uri file) => _packageTree.packageOf(file);

  @override
  Uri? resolve(Uri packageUri) {
    var packageName = checkValidPackageUri(packageUri, 'packageUri');
    return _packages[packageName]?.packageUriRoot.resolveUri(
        Uri(path: packageUri.path.substring(packageName.length + 1)));
  }

  @override
  Uri? toPackageUri(Uri nonPackageUri) {
    if (nonPackageUri.isScheme('package')) {
      throw PackageConfigArgumentError(
          nonPackageUri, 'nonPackageUri', 'Must not be a package URI');
    }
    if (nonPackageUri.hasQuery || nonPackageUri.hasFragment) {
      throw PackageConfigArgumentError(nonPackageUri, 'nonPackageUri',
          'Must not have query or fragment part');
    }
    // Find package that file belongs to.
    var package = _packageTree.packageOf(nonPackageUri);
    if (package == null) return null;
    // Check if it is inside the package URI root.
    var path = nonPackageUri.toString();
    var root = package.packageUriRoot.toString();
    if (_beginsWith(package.root.toString().length, root, path)) {
      var rest = path.substring(root.length);
      return Uri(scheme: 'package', path: '${package.name}/$rest');
    }
    return null;
  }
}

/// Configuration data for a single package.
final class SimplePackage implements Package {
  @override
  final String name;
  @override
  final Uri root;
  @override
  final Uri packageUriRoot;
  @override
  final LanguageVersion? languageVersion;
  @override
  final Object? extraData;
  @override
  final bool relativeRoot;

  SimplePackage._(this.name, this.root, this.packageUriRoot,
      this.languageVersion, this.extraData, this.relativeRoot);

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
  static SimplePackage? validate(
      String name,
      Uri root,
      Uri? packageUriRoot,
      LanguageVersion? languageVersion,
      Object? extraData,
      bool relativeRoot,
      void Function(Object error) onError) {
    var fatalError = false;
    var invalidIndex = checkPackageName(name);
    if (invalidIndex >= 0) {
      onError(PackageConfigFormatException(
          'Not a valid package name', name, invalidIndex));
      fatalError = true;
    }
    if (root.isScheme('package')) {
      onError(PackageConfigArgumentError(
          '$root', 'root', 'Must not be a package URI'));
      fatalError = true;
    } else if (!isAbsoluteDirectoryUri(root)) {
      onError(PackageConfigArgumentError(
          '$root',
          'root',
          'In package $name: Not an absolute URI with no query or fragment '
              'with a path ending in /'));
      // Try to recover. If the URI has a scheme,
      // then ensure that the path ends with `/`.
      if (!root.hasScheme) {
        fatalError = true;
      } else if (!root.path.endsWith('/')) {
        root = root.replace(path: '${root.path}/');
      }
    }
    if (packageUriRoot == null) {
      packageUriRoot = root;
    } else if (!fatalError) {
      packageUriRoot = root.resolveUri(packageUriRoot);
      if (!isAbsoluteDirectoryUri(packageUriRoot)) {
        onError(PackageConfigArgumentError(
            packageUriRoot,
            'packageUriRoot',
            'In package $name: Not an absolute URI with no query or fragment '
                'with a path ending in /'));
        packageUriRoot = root;
      } else if (!isUriPrefix(root, packageUriRoot)) {
        onError(PackageConfigArgumentError(packageUriRoot, 'packageUriRoot',
            'The package URI root is not below the package root'));
        packageUriRoot = root;
      }
    }
    if (fatalError) return null;
    return SimplePackage._(
        name, root, packageUriRoot, languageVersion, extraData, relativeRoot);
  }
}

/// Checks whether [source] is a valid Dart language version string.
///
/// The format is (as RegExp) `^(0|[1-9]\d+)\.(0|[1-9]\d+)$`.
///
/// Reports a format exception on [onError] if not, or if the numbers
/// are too large (at most 32-bit signed integers).
LanguageVersion parseLanguageVersion(
    String? source, void Function(Object error) onError) {
  var index = 0;
  // Reads a positive decimal numeral. Returns the value of the numeral,
  // or a negative number in case of an error.
  // Starts at [index] and increments the index to the position after
  // the numeral.
  // It is an error if the numeral value is greater than 0x7FFFFFFFF.
  // It is a recoverable error if the numeral starts with leading zeros.
  int readNumeral() {
    const maxValue = 0x7FFFFFFF;
    if (index == source!.length) {
      onError(PackageConfigFormatException('Missing number', source, index));
      return -1;
    }
    var start = index;

    var char = source.codeUnitAt(index);
    var digit = char ^ 0x30;
    if (digit > 9) {
      onError(PackageConfigFormatException('Missing number', source, index));
      return -1;
    }
    var firstDigit = digit;
    var value = 0;
    do {
      value = value * 10 + digit;
      if (value > maxValue) {
        onError(
            PackageConfigFormatException('Number too large', source, start));
        return -1;
      }
      index++;
      if (index == source.length) break;
      char = source.codeUnitAt(index);
      digit = char ^ 0x30;
    } while (digit <= 9);
    if (firstDigit == 0 && index > start + 1) {
      onError(PackageConfigFormatException(
          'Leading zero not allowed', source, start));
    }
    return value;
  }

  var major = readNumeral();
  if (major < 0) {
    return SimpleInvalidLanguageVersion(source);
  }
  if (index == source!.length || source.codeUnitAt(index) != $dot) {
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
        'Unexpected trailing character', source, index));
    return SimpleInvalidLanguageVersion(source);
  }
  return SimpleLanguageVersion(major, minor, source);
}

abstract final class _SimpleLanguageVersionBase implements LanguageVersion {
  @override
  int compareTo(LanguageVersion other) {
    var result = major - other.major;
    if (result != 0) return result;
    return minor - other.minor;
  }
}

final class SimpleLanguageVersion extends _SimpleLanguageVersionBase {
  @override
  final int major;
  @override
  final int minor;
  String? _source;
  SimpleLanguageVersion(this.major, this.minor, this._source);

  @override
  bool operator ==(Object other) =>
      other is LanguageVersion && major == other.major && minor == other.minor;

  @override
  int get hashCode => (major * 17 ^ minor * 37) & 0x3FFFFFFF;

  @override
  String toString() => _source ??= '$major.$minor';

  /// Whether this language version is less than [other].
  ///
  /// Neither version being compared must be  an [InvalidLanguageVersion].
  ///
  /// For details on how valid language versions are compared,
  /// check out [LanguageVersion.compareTo].
  @override
  bool operator <(LanguageVersion other) {
    // Throw an error if comparing with an invalid language version.
    if (other is InvalidLanguageVersion) _throwOtherInvalid();

    return compareTo(other) < 0;
  }

  /// Whether this language version is less than or equal to [other].
  ///
  /// Neither version being compared must be  an [InvalidLanguageVersion].
  ///
  /// For details on how valid language versions are compared,
  /// check out [LanguageVersion.compareTo].
  @override
  bool operator <=(LanguageVersion other) {
    // Throw an error if comparing with an invalid language version.
    if (other is InvalidLanguageVersion) _throwOtherInvalid();
    return compareTo(other) <= 0;
  }

  /// Whether this language version is greater than [other].
  ///
  /// Neither version being compared must be  an [InvalidLanguageVersion].
  ///
  /// For details on how valid language versions are compared,
  /// check out [LanguageVersion.compareTo].
  @override
  bool operator >(LanguageVersion other) {
    if (other is InvalidLanguageVersion) _throwOtherInvalid();
    return compareTo(other) > 0;
  }

  /// Whether this language version is greater than or equal to [other].
  ///
  /// If either version being compared is an [InvalidLanguageVersion],
  /// a [StateError] is thrown. Verify versions are valid before comparing them.
  ///
  /// For details on how valid language versions are compared,
  /// check out [LanguageVersion.compareTo].
  @override
  bool operator >=(LanguageVersion other) {
    // Throw an error if comparing with an invalid language version.
    if (other is InvalidLanguageVersion) _throwOtherInvalid();
    return compareTo(other) >= 0;
  }

  static Never _throwOtherInvalid() => throw StateError(
      'Can\'t compare a language version to an invalid language version. '
      'Verify language versions are valid after parsing.');
}

final class SimpleInvalidLanguageVersion extends _SimpleLanguageVersionBase
    implements InvalidLanguageVersion {
  final String? _source;
  SimpleInvalidLanguageVersion(this._source);
  @override
  int get major => -1;
  @override
  int get minor => -1;

  @override
  bool operator <(LanguageVersion other) {
    _throwThisInvalid();
  }

  @override
  bool operator <=(LanguageVersion other) {
    _throwThisInvalid();
  }

  @override
  bool operator >(LanguageVersion other) {
    _throwThisInvalid();
  }

  @override
  bool operator >=(LanguageVersion other) {
    _throwThisInvalid();
  }

  @override
  String toString() => _source!;

  static Never _throwThisInvalid() => throw StateError(
      'Can\'t compare an invalid language version to another language version. '
      'Verify language versions are valid after parsing.');
}

abstract class PackageTree {
  Iterable<Package> get allPackages;
  SimplePackage? packageOf(Uri file);
}

class _PackageTrieNode {
  SimplePackage? package;

  /// Indexed by path segment.
  Map<String, _PackageTrieNode> map = {};
}

/// Packages of a package configuration ordered by root path.
///
/// A package has a root path and a package root path, where the latter
/// contains the files exposed by `package:` URIs.
///
/// A package is said to be inside another package if the root path URI of
/// the latter is a prefix of the root path URI of the former.
///
/// No two packages of a package may have the same root path.
/// The package root path of a package must not be inside another package's
/// root path.
/// Entire other packages are allowed inside a package's root.
class TriePackageTree implements PackageTree {
  /// Indexed by URI scheme.
  final Map<String, _PackageTrieNode> _map = {};

  /// A list of all packages.
  final List<SimplePackage> _packages = [];

  @override
  Iterable<Package> get allPackages sync* {
    for (var package in _packages) {
      yield package;
    }
  }

  bool _checkConflict(_PackageTrieNode node, SimplePackage newPackage,
      void Function(Object error) onError) {
    var existingPackage = node.package;
    if (existingPackage != null) {
      // Trying to add package that is inside the existing package.
      // 1) If it's an exact match it's not allowed (i.e. the roots can't be
      //    the same).
      if (newPackage.root.path.length == existingPackage.root.path.length) {
        onError(ConflictException(
            newPackage, existingPackage, ConflictType.sameRoots));
        return true;
      }
      // 2) The existing package has a packageUriRoot thats inside the
      //    root of the new package.
      if (_beginsWith(0, newPackage.root.toString(),
          existingPackage.packageUriRoot.toString())) {
        onError(ConflictException(
            newPackage, existingPackage, ConflictType.interleaving));
        return true;
      }

      // For internal reasons we allow this (for now). One should still never do
      // it though.
      // 3) The new package is inside the packageUriRoot of existing package.
      if (_disallowPackagesInsidePackageUriRoot) {
        if (_beginsWith(0, existingPackage.packageUriRoot.toString(),
            newPackage.root.toString())) {
          onError(ConflictException(
              newPackage, existingPackage, ConflictType.insidePackageRoot));
          return true;
        }
      }
    }
    return false;
  }

  /// Tries to add `newPackage` to the tree.
  ///
  /// Reports a [ConflictException] if the added package conflicts with an
  /// existing package.
  /// It conflicts if its root or package root is the same as an existing
  /// package's root or package root, is between the two, or if it's inside the
  /// package root of an existing package.
  ///
  /// If a conflict is detected between [newPackage] and a previous package,
  /// then [onError] is called with a [ConflictException] object
  /// and the [newPackage] is not added to the tree.
  ///
  /// The packages are added in order of their root path.
  void add(SimplePackage newPackage, void Function(Object error) onError) {
    var root = newPackage.root;
    var node = _map[root.scheme] ??= _PackageTrieNode();
    if (_checkConflict(node, newPackage, onError)) return;
    var segments = root.pathSegments;
    // Notice that we're skipping the last segment as it's always the empty
    // string because roots are directories.
    for (var i = 0; i < segments.length - 1; i++) {
      var path = segments[i];
      node = node.map[path] ??= _PackageTrieNode();
      if (_checkConflict(node, newPackage, onError)) return;
    }
    node.package = newPackage;
    _packages.add(newPackage);
  }

  bool _isMatch(
      String path, _PackageTrieNode node, List<SimplePackage> potential) {
    var currentPackage = node.package;
    if (currentPackage != null) {
      var currentPackageRootLength = currentPackage.root.toString().length;
      if (path.length == currentPackageRootLength) return true;
      var currentPackageUriRoot = currentPackage.packageUriRoot.toString();
      // Is [file] inside the package root of [currentPackage]?
      if (currentPackageUriRoot.length == currentPackageRootLength ||
          _beginsWith(currentPackageRootLength, currentPackageUriRoot, path)) {
        return true;
      }
      potential.add(currentPackage);
    }
    return false;
  }

  @override
  SimplePackage? packageOf(Uri file) {
    var currentTrieNode = _map[file.scheme];
    if (currentTrieNode == null) return null;
    var path = file.toString();
    var potential = <SimplePackage>[];
    if (_isMatch(path, currentTrieNode, potential)) {
      return currentTrieNode.package;
    }
    var segments = file.pathSegments;

    for (var i = 0; i < segments.length - 1; i++) {
      var segment = segments[i];
      currentTrieNode = currentTrieNode!.map[segment];
      if (currentTrieNode == null) break;
      if (_isMatch(path, currentTrieNode, potential)) {
        return currentTrieNode.package;
      }
    }
    if (potential.isEmpty) return null;
    return potential.last;
  }
}

class EmptyPackageTree implements PackageTree {
  const EmptyPackageTree();

  @override
  Iterable<Package> get allPackages => const Iterable<Package>.empty();

  @override
  SimplePackage? packageOf(Uri file) => null;
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

enum ConflictType { sameRoots, interleaving, insidePackageRoot }

/// Conflict between packages added to the same configuration.
///
/// The [package] conflicts with [existingPackage] if it has
/// the same root path or the package URI root path
/// of [existingPackage] is inside the root path of [package].
class ConflictException {
  /// The existing package that [package] conflicts with.
  final SimplePackage existingPackage;

  /// The package that could not be added without a conflict.
  final SimplePackage package;

  /// Whether the conflict is with the package URI root of [existingPackage].
  final ConflictType conflictType;

  /// Creates a root conflict between [package] and [existingPackage].
  ConflictException(this.package, this.existingPackage, this.conflictType);
}

/// Used for sorting packages by root path.
int _compareRoot(Package p1, Package p2) =>
    p1.root.toString().compareTo(p2.root.toString());
