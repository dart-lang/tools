// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Find extensions with [findExtensions].
library;

import 'dart:collection' show UnmodifiableListView;
import 'dart:io' show File, IOException;
import 'dart:isolate' show Isolate;

import 'src/io.dart';
import 'src/package_config.dart';
import 'src/registry.dart';
import 'src/yaml_config_format.dart';

export 'src/package_config.dart' show PackageConfigException;

/// Information about an extension for target package.
final class Extension {
  /// Name of the package providing an extension.
  final String package;

  /// Absolute path to the package root.
  ///
  /// This folder usually contains a `lib/` folder and a `pubspec.yaml`
  /// (assuming dependencies are fetched using the pub package manager).
  ///
  /// **Examples:** If `foo` is installed in pub-cache this would be:
  ///  * `/home/my_user/.pub-cache/hosted/pub.dev/foo-1.0.0/`
  ///
  /// See `rootUri` in the [specification for `package_config.json`][1],
  /// for details.
  ///
  /// [1]: https://github.com/dart-lang/language/blob/main/accepted/2.8/language-versioning/package-config-file-v2.md
  final Uri rootUri;

  /// Path to the library import path relative to [rootUri].
  ///
  /// In Dart code the `package:<package>/<path>` will be resolved as
  /// `<rootUri>/<packageUri>/<path>`.
  ///
  /// If dependencies are installed using `dart pub`, then this is
  /// **always** `lib/`.
  ///
  /// See `packageUri` in the [specification for `package_config.json`][1],
  /// for details.
  ///
  /// [1]: https://github.com/dart-lang/language/blob/main/accepted/2.8/language-versioning/package-config-file-v2.md
  final Uri packageUri;

  /// Contents of `extension/<targetPackage>/config.yaml` parsed as YAML and
  /// converted to JSON compatible types.
  ///
  /// If parsing YAML from this file failed, then no [Extension] entry
  /// will exist.
  ///
  /// This field is always a structure consisting of the following types:
  ///  * `null`,
  ///  * [bool] (`true` or `false`),
  ///  * [String],
  ///  * [num] ([int] or [double]),
  ///  * [List<Object?>], and,
  ///  * [Map<String, Object?>].
  final Map<String, Object?> config;

  Extension._({
    required this.package,
    required this.rootUri,
    required this.packageUri,
    required this.config,
  });
}

/// Find extensions for [targetPackage] provided by packages in
/// `.dart_tool/package_config.json`.
///
/// ## Locating `.dart_tool/package_config.json`
///
/// This method requires the location of the [packageConfig], unless the current
/// isolate has been setup for package resolution.
/// Notably, Dart programs compiled for AOT cannot find their own
/// `package_config.json`.
///
/// If operating on a project that isn't the current project, for example, if
/// you are developing a tool that users are globally activating and then
/// running against their own projects, and you wish to detect extensions within
/// their projects, then you must specify the path the
/// `.dart_tool/package_config.json` for the users project as [packageConfig].
///
/// The [packageConfig] parameter must reference a file, absolute or
/// relative-path, may use the `file://` scheme. This method throws, if
/// [packageConfig] is not a valid [Uri] for a file-path.
///
/// ## Detection of extensions
///
/// An extension for [targetPackage] is detected in `package:foo` if `foo`
/// contains `extension/<targetPackage>/config.yaml`, and the contents of this
/// file is valid YAML, that can be represented as JSON.
///
/// ### Caching results
///
/// When [useCache] is `true` then the detected extensions will be cached
/// in `.dart_tool/extension_discovery/<targetPackage>.yaml`.
/// This function will compare modification timestamps of
/// `.dart_tool/package_config.json` with the cache file, before reusing cached
/// results.
/// This function will also treat relative path-dependencies as mutable
/// packages, and check such packages for extensions every time [findExtensions]
/// is called. Notably, it'll compare the modification time of the
/// `extension/<targetPackage>/config.yaml` file, to ensure that it's older than
/// the extension cache file. Otherwise, it'll reload the extension
/// configuration.
///
/// ## Exceptions
///
/// This method will throw [PackageConfigException], if the
/// `.dart_tool/package_config.json` file specified in [packageConfig] could not
/// be loaded or is invalid. This usually happens if dependencies are not
/// resolved, and users can probably address it by running `dart pub get`.
///
/// But, **do consider catch** [PackageConfigException] and handling the failure
/// to load extensions appropriately.
///
/// This method will throw an [Error] if [packageConfig] is not specified, and
/// the current isolate isn't configured for package resolution.
Future<List<Extension>> findExtensions(
  String targetPackage, {
  bool useCache = true,
  Uri? packageConfig,
}) async {
  packageConfig ??= await Isolate.packageConfig;
  if (packageConfig == null) {
    throw UnsupportedError(
      'packageConfigUri must be provided, if not running in JIT mode',
    );
  }
  if ((packageConfig.hasScheme && !packageConfig.isScheme('file')) ||
      packageConfig.hasEmptyPath ||
      packageConfig.hasFragment ||
      packageConfig.hasPort ||
      packageConfig.hasQuery) {
    throw ArgumentError.value(
      packageConfig,
      'packageConfig',
      'must be a file:// URI',
    );
  }
  // Always normalize to an absolute URI
  final packageConfigUri = File.fromUri(packageConfig).absolute.uri;

  return await _findExtensions(
    targetPackage: targetPackage,
    useCache: useCache,
    packageConfigUri: packageConfigUri,
  );
}

/// Find extensions with normalized arguments.
Future<List<Extension>> _findExtensions({
  required String targetPackage,
  required bool useCache,
  required Uri packageConfigUri,
}) async {
  final packageConfigFile = File.fromUri(packageConfigUri);
  final registryFile = File.fromUri(packageConfigFile.parent.uri.resolve(
    'extension_discovery/$targetPackage.json',
  ));

  Registry? registry;
  final registryStat = registryFile.statSync();
  if (registryStat.isFileOrLink && useCache) {
    final packageConfigStat = packageConfigFile.statSync();
    if (!packageConfigStat.isFileOrLink) {
      throw packageConfigNotFound(packageConfigUri);
    }
    if (packageConfigStat.isPossiblyModifiedAfter(registryStat.modified)) {
      await registryFile.tryDelete();
    } else {
      registry = await loadRegistry(registryFile);
    }
  }

  final configFileName = 'extension/$targetPackage/config.yaml';
  var registryUpdated = false;
  if (registry != null) {
    // Update mutable entries in registry
    for (var i = 0; i < registry.length; i++) {
      final p = registry[i];
      if (p.rootUri.hasAbsolutePath) continue;

      final rootUri = packageConfigUri.resolveUri(p.rootUri);
      final configFile = File.fromUri(rootUri.resolve(configFileName));
      final configStat = configFile.statSync();
      if (configStat.isFileOrLink) {
        if (configStat.isPossiblyModifiedAfter(registryStat.modified)) {
          try {
            registryUpdated = true;
            registry[i] = (
              package: p.package,
              rootUri: p.rootUri,
              packageUri: p.packageUri,
              config: parseYamlFromConfigFile(await configFile.readAsString()),
            );
            continue;
          } on FormatException {
            // pass
          } on IOException {
            // pass
          }
          registryUpdated = true;
          registry[i] = (
            package: p.package,
            rootUri: p.rootUri,
            packageUri: p.packageUri,
            config: null,
          );
        }
      } else {
        // If there is no file present, but registry says there is then we need
        // to update the registry.
        if (p.config != null) {
          registryUpdated = true;
          registry[i] = (
            package: p.package,
            rootUri: p.rootUri,
            packageUri: p.packageUri,
            config: null,
          );
        }
      }
    }
  } else {
    // Load packages from package_config.json
    final packages = await loadPackageConfig(packageConfigFile);
    registryUpdated = true;
    registry = (await Future.wait(packages.map((p) async {
      try {
        final rootUri = packageConfigUri.resolveUri(p.rootUri);
        final configFile = File.fromUri(rootUri.resolve(configFileName));
        final configStat = configFile.statSync();
        if (configStat.isFileOrLink) {
          return (
            package: p.name,
            rootUri: p.rootUri,
            packageUri: p.packageUri,
            config: parseYamlFromConfigFile(await configFile.readAsString()),
          );
        }
      } on FormatException {
        // pass
      } on IOException {
        // pass
      }
      if (!p.rootUri.hasAbsolutePath) {
        return (
          package: p.name,
          rootUri: p.rootUri,
          packageUri: p.packageUri,
          config: null,
        );
      }
      return null;
    })))
        .whereType<RegistryEntry>()
        .toList(growable: false);
  }

  // Save registry
  if (registryUpdated && useCache) {
    await saveRegistry(registryFile, registry);
  }

  return UnmodifiableListView(
    registry
        .where((e) => e.config != null)
        .map((e) => Extension._(
              package: e.package,
              rootUri: packageConfigUri.resolveUri(e.rootUri),
              packageUri: e.packageUri,
              config: e.config!,
            ))
        .toList(growable: false),
  );
}
