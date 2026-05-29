// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';

import 'package:checks/checks.dart';
import 'package:package_config/package_config.dart';
import 'package:test/expect.dart' show expectAsync1, expectAsync2;
import 'package:test/scaffolding.dart';

import 'src/util.dart';
import 'src/util_io.dart';

const packagesFile = '''
# A comment
foo:file:///dart/packages/foo/
bar:/dart/packages/bar/
baz:packages/baz/
''';

const packageConfigFile = '''
{
  "configVersion": ${PackageConfig.minVersion},
  "packages": [
    {
      "name": "foo",
      "rootUri": "file:///dart/packages/foo/"
    },
    {
      "name": "bar",
      "rootUri": "/dart/packages/bar/"
    },
    {
      "name": "baz",
      "rootUri": "../packages/baz/"
    }
  ],
  "extra": [42]
}
''';

void validatePackagesFile(PackageConfig resolver, Directory directory) {
  check(
    resolver.resolve(pkg('foo', 'bar/baz')),
  ).equals(Uri.parse('file:///dart/packages/foo/bar/baz'));
  check(
    resolver.resolve(pkg('bar', 'baz/qux')),
  ).equals(Uri.parse('file:///dart/packages/bar/baz/qux'));
  check(
    resolver.resolve(pkg('baz', 'qux/foo')),
  ).equals(Uri.directory(directory.path).resolve('packages/baz/qux/foo'));
  check([
    for (var p in resolver.packages) p.name,
  ]).unorderedEquals(['foo', 'bar', 'baz']);
}

void main() {
  group('findPackages', () {
    // Finds package_config.json if there.
    fileTest(
      'package_config.json',
      {
        '.packages': 'invalid .packages file',
        'script.dart': 'main(){}',
        'packages': {'shouldNotBeFound': <Never, Never>{}},
        '.dart_tool': {'package_config.json': packageConfigFile},
      },
      (Directory directory) async {
        var config = (await findPackageConfig(directory))!;
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);

        File file;
        (:config, :file) = (await findPackageConfigAndFile(directory))!;
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);
        check(file.path).equals(configFile(directory).path);
      },
    );

    // Does not find .packages if no package_config.json.
    fileTest(
      '.packages',
      {
        '.packages': packagesFile,
        'script.dart': 'main(){}',
        'packages': {'shouldNotBeFound': <Object, Object>{}},
      },
      (Directory directory) async {
        check(await findPackageConfig(directory)).isNull();
        check(await findPackageConfigAndFile(directory)).isNull();
      },
    );

    // Finds package_config.json in super-directory.
    fileTest(
      'package_config.json recursive',
      {
        '.packages': packagesFile,
        '.dart_tool': {'package_config.json': packageConfigFile},
        'subdir': {'.packages': packagesFile, 'script.dart': 'main(){}'},
      },
      (Directory directory) async {
        var config = (await findPackageConfig(subDir(directory, 'subdir')))!;
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);

        File file;
        (:config, :file) = (await findPackageConfigAndFile(directory))!;
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);
        check(file.path).equals(configFile(directory).path);
      },
    );

    // Finds package_config.json in super-directory, even inside `.dart_tool`.
    fileTest(
      'package_config.json recursive inside .dart_tool',
      {
        '.packages': packagesFile,
        '.dart_tool': {'package_config.json': packageConfigFile},
        'subdir': {'.packages': packagesFile, 'script.dart': 'main(){}'},
      },
      (Directory directory) async {
        var config =
            (await findPackageConfig(subDir(directory, '.dart_tool')))!;
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);

        File file;
        (:config, :file) = (await findPackageConfigAndFile(directory))!;
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);
        check(file.path).equals(configFile(directory).path);
      },
    );

    // Does not find a packages/ directory, and returns null if nothing found.
    fileTest(
      'package directory packages not supported',
      {
        'packages': {'foo': <String, Object?>{}},
      },
      (Directory directory) async {
        check(await findPackageConfig(directory)).isNull();
        check(await findPackageConfigAndFile(directory)).isNull();
      },
    );

    for (var skip in [false, true]) {
      group('skipInvalid: $skip', () {
        fileTest(
          'does not affect invalid configVersion',
          {
            '.dart_tool': {
              'package_config.json': '''
                {
                  "configVersion": ${PackageConfig.minVersion - 1},
                  "packages": []
                }
              ''',
            },
          },
          (Directory directory) async {
            await findPackageConfig(
              directory,
              skipInvalid: skip,
              onError: expectAsync1((Object e) {
                check(e).isA<PackageConfigVersionException>();
              }),
            );
            await findPackageConfigAndFile(
              directory,
              skipInvalid: skip,
              onError: expectAsync2((Object e, File f) {
                check(e).isA<PackageConfigVersionException>();
                check(f.path).equals(configFile(directory).path);
              }),
            );
          },
        );

        if (PackageConfig.maxVersion > PackageConfig.minVersion) {
          // Cannot test a minVersion above actual version until supporting
          // more than one version.
          // (Can be tested by temporarily increasing maxVersion
          // fx using `-Dpkg_package_config_test_override.maxVersion=3`)
          fileTest(
            'affects minVersion',
            {
              '.dart_tool': {
                'package_config.json': '''
                {
                  "configVersion": ${PackageConfig.minVersion},
                  "packages": []
                }
              ''',
              },
            },
            (Directory directory) async {
              var config = await findPackageConfig(
                directory,
                minVersion: PackageConfig.minVersion + 1,
                skipInvalid: skip,
                onError: expectAsync1(count: skip ? 0 : 1, (Object e) {
                  check(e).isA<PackageConfigVersionException>();
                }),
              );
              if (skip) check(config).isNull();

              var configAndFile = await findPackageConfigAndFile(
                directory,
                skipInvalid: skip,
                minVersion: PackageConfig.minVersion + 1,
                onError: expectAsync2(count: skip ? 0 : 1, (Object e, File f) {
                  check(e).isA<PackageConfigVersionException>();
                  check(f.path).equals(configFile(directory).path);
                }),
              );
              if (skip) check(configAndFile).isNull();
            },
          );
        }
      });
    }

    group('throws', () {
      fileTest(
        'invalid package config not JSON',
        {
          '.dart_tool': {'package_config.json': 'not a JSON file'},
        },
        (Directory directory) async {
          await check(findPackageConfig(directory)).throws<FormatException>();
          await check(
            findPackageConfigAndFile(directory),
          ).throws<FormatException>();
        },
      );

      fileTest(
        'invalid package config as INI',
        {
          '.dart_tool': {'package_config.json': packagesFile},
        },
        (Directory directory) async {
          await check(findPackageConfig(directory)).throws<FormatException>();
          await check(
            findPackageConfigAndFile(directory),
          ).throws<FormatException>();
        },
      );

      fileTest(
        'indirectly through .packages',
        {
          '.packages': packagesFile,
          '.dart_tool': {'package_config.json': packageConfigFile},
        },
        (Directory directory) async {
          // A .packages file in the directory of a .dart_tool/package_config.json
          // used to automatically redirect to the package_config.json.
          // It no longer does.
          var file = dirFile(directory, '.packages');
          await check(loadPackageConfig(file)).throws<FormatException>();
        },
      );
    });

    group('handles error', () {
      fileTest(
        'invalid package config not JSON',
        {
          '.dart_tool': {'package_config.json': 'not a JSON file'},
        },
        (Directory directory) async {
          var hadError = false;
          await findPackageConfig(
            directory,
            onError: expectAsync1((error) {
              hadError = true;
              check(error).isA<FormatException>();
            }, max: -1),
          );
          check(hadError).isTrue();
        },
      );

      fileTest(
        'invalid package config as INI',
        {
          '.dart_tool': {'package_config.json': packagesFile},
        },
        (Directory directory) async {
          var hadError = false;
          await findPackageConfig(
            directory,
            onError: expectAsync1((error) {
              hadError = true;
              check(error).isA<FormatException>();
            }, max: -1),
          );
          check(hadError).isTrue();
        },
      );
    });

    // Does not find .packages if no package_config.json and minVersion > 1.
    fileTest(
      '.packages ignored',
      {'.packages': packagesFile, 'script.dart': 'main(){}'},
      (Directory directory) async {
        var config = await findPackageConfig(directory, minVersion: 2);
        check(config).isNull();
      },
    );

    // Finds package_config.json in super-directory.
    // (Even with `.packages` in search directory.)
    fileTest(
      'package_config.json recursive .packages ignored',
      {
        '.dart_tool': {'package_config.json': packageConfigFile},
        'subdir': {'.packages': packagesFile, 'script.dart': 'main(){}'},
      },
      (Directory directory) async {
        var config =
            (await findPackageConfig(
              subDir(directory, 'subdir'),
              minVersion: 2,
            ))!;
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);
      },
    );
  });

  group('loadPackageConfig', () {
    // Load a specific files
    group('package_config.json', () {
      var files = {
        '.packages': packagesFile,
        '.dart_tool': {'package_config.json': packageConfigFile},
      };
      fileTest('directly', files, (Directory directory) async {
        var file = configFile(directory);
        var config = await loadPackageConfig(file);
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);
      });
    });

    fileTest(
      'package_config.json non-default name',
      {
        '.packages': packagesFile,
        'subdir': {'pheldagriff': packageConfigFile},
      },
      (Directory directory) async {
        var file = dirFile(subDir(directory, 'subdir'), 'pheldagriff');
        var config = await loadPackageConfig(file);
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);
      },
    );

    fileTest(
      'package_config.json named .packages',
      {
        'subdir': {'.packages': packageConfigFile},
      },
      (Directory directory) async {
        var file = dirFile(subDir(directory, 'subdir'), '.packages');
        var config = await loadPackageConfig(file);
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);
      },
    );

    fileTest('.packages cannot be loaded', {'.packages': packagesFile}, (
      Directory directory,
    ) async {
      var file = dirFile(directory, '.packages');
      await check(loadPackageConfig(file)).throws<FormatException>();
    });

    fileTest('no config file found', {}, (Directory directory) async {
      var file = dirFile(directory, 'any_name');
      await check(loadPackageConfig(file)).throws<FileSystemException>();
    });

    fileTest('no config found, handled', {}, (Directory directory) async {
      var file = dirFile(directory, 'any_name');
      var hadError = false;
      await loadPackageConfig(
        file,
        onError: expectAsync1((error) {
          hadError = true;
          check(error).isA<FileSystemException>();
        }, max: -1),
      );
      check(hadError).isTrue();
    });

    fileTest('specified file syntax error', {'any_name': 'syntax error'}, (
      Directory directory,
    ) async {
      var file = dirFile(directory, 'any_name');
      await check(loadPackageConfig(file)).throws<FormatException>();
    });
  });
}

// Simple path helpers.

File configFile(Directory directory) {
  var s = Platform.pathSeparator;
  var path = directory.path;
  return File(
    '$path${_ifNeeded(path, s)}.dart_tool${s}package_config.json',
  );
}

Directory subDir(Directory directory, String name) {
  var s = Platform.pathSeparator;
  var path = directory.path;
  return Directory('$path${_ifNeeded(path, s)}$name$s');
}

File dirFile(Directory directory, String name) {
  var s = Platform.pathSeparator;
  var path = directory.path;
  return File('$path${_ifNeeded(path, s)}$name');
}

String _ifNeeded(String previous, String separator) {
  if (previous.endsWith(separator)) return '';
  return separator;
}
