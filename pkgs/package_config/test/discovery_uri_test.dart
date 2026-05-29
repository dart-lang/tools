// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:checks/checks.dart';
import 'package:package_config/package_config.dart';
import 'package:test/expect.dart' show expectAsync1, expectAsync2;
import 'package:test/scaffolding.dart';

import 'src/checks.dart';
import 'src/util.dart';

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

void validatePackagesFile(PackageConfig resolver, Uri directory) {
  var checkResolver = check(resolver);
  checkResolver
      .resolve(pkg('foo', 'bar/baz'))
      .equals(Uri.parse('file:///dart/packages/foo/bar/baz'));
  checkResolver
      .resolve(pkg('bar', 'baz/qux'))
      .equals(directory.resolve('/dart/packages/bar/baz/qux'));
  checkResolver
      .resolve(pkg('baz', 'qux/foo'))
      .equals(directory.resolve('packages/baz/qux/foo'));
  checkResolver.packages.map((p) => p.name).unorderedEquals([
    'foo',
    'bar',
    'baz',
  ]);
}

void main() {
  group('findPackages', () {
    // Finds package_config.json if there.
    loaderTest(
      'package_config.json',
      {
        '.packages': 'invalid .packages file',
        'script.dart': 'main(){}',
        'packages': {'shouldNotBeFound': <String, Object?>{}},
        '.dart_tool': {'package_config.json': packageConfigFile},
      },
      (directory, loader) async {
        var config = (await findPackageConfigUri(directory, loader: loader))!;
        check(config).version.equals(
          PackageConfig.minVersion,
        ); // Found package_config.json file.
        validatePackagesFile(config, directory);
        Uri file;
        (:config, :file) =
            (await findPackageConfigAndUri(directory, loader: loader))!;
        check(
          config).version.equals(
          PackageConfig.minVersion,
        ); // Found package_config.json file.
        validatePackagesFile(config, directory);
        check(file).equals(directory.resolve('.dart_tool/package_config.json'));
      },
    );

    // Finds package_config.json in super-directory.
    loaderTest(
      'package_config.json recursive',
      {
        '.packages': packagesFile,
        '.dart_tool': {'package_config.json': packageConfigFile},
        'subdir': {'script.dart': 'main(){}'},
      },
      (directory, loader) async {
        var config =
            (await findPackageConfigUri(
              directory.resolve('subdir/'),
              loader: loader,
            ))!;
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);
        Uri file;
        (:config, :file) =
            (await findPackageConfigAndUri(directory, loader: loader))!;
        check(
          config.version,
        ).equals(PackageConfig.minVersion); // Found package_config.json file.
        validatePackagesFile(config, directory);
        check(file).equals(directory.resolve('.dart_tool/package_config.json'));
      },
    );

    // Does not find a .packages file.
    loaderTest(
      'Not .packages',
      {
        '.packages': packagesFile,
        'script.dart': 'main(){}',
        'packages': {'shouldNotBeFound': <String, Object?>{}},
      },
      (directory, loader) async {
        var config = await findPackageConfigUri(
          recurse: false,
          directory,
          loader: loader,
        );
        check(config).isNull();
        check(
          await findPackageConfigAndUri(
            recurse: false,
            directory,
            loader: loader,
          ),
        ).isNull();
      },
    );

    // Does not find a packages/ directory, and returns null if nothing found.
    loaderTest(
      'package directory packages not supported',
      {
        'packages': {'foo': <String, Object?>{}},
      },
      (directory, loader) async {
        check(await findPackageConfigUri(directory, loader: loader)).isNull();
        check(
          await findPackageConfigAndUri(directory, loader: loader),
        ).isNull();
      },
    );

    for (var skip in [false, true]) {
      group('skipInvalid: $skip', () {
        loaderTest(
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
          (Uri directory, loader) async {
            await findPackageConfigUri(
              directory,
              skipInvalid: skip,
              onError: expectAsync1((Object e) {
                check(e).isA<PackageConfigVersionException>();
              }),
              loader: loader,
            );
            await findPackageConfigAndUri(
              directory,
              skipInvalid: skip,
              onError: expectAsync2((Object e, Uri f) {
                check(e).isA<PackageConfigVersionException>();
                check(
                  f,
                ).equals(directory.resolve('.dart_tool/package_config.json'));
              }),
              loader: loader,
            );
          },
        );

        if (PackageConfig.maxVersion > PackageConfig.minVersion) {
          // Cannot test a minVersion above actual version until supporting
          // more than one version.
          // (Can be tested by temporarily increasing maxVersion
          // fx using `-Dpkg_package_config_test_override.maxVersion=3`)
          loaderTest(
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
            (directory, loader) async {
              var config = await findPackageConfigUri(
                directory,
                minVersion: PackageConfig.minVersion + 1,
                skipInvalid: skip,
                onError: expectAsync1(count: skip ? 0 : 1, (Object e) {
                  check(e).isA<PackageConfigVersionException>();
                }),
                loader: loader,
              );
              if (skip) check(config).isNull();

              var configAndFile = await findPackageConfigAndUri(
                directory,
                skipInvalid: skip,
                minVersion: PackageConfig.minVersion + 1,
                onError: expectAsync2(count: skip ? 0 : 1, (Object e, Uri f) {
                  check(e).isA<PackageConfigVersionException>();
                  check(
                    f,
                  ).equals(directory.resolve('.dart_tool/package_config.json'));
                }),
                loader: loader,
              );
              if (skip) check(configAndFile).isNull();
            },
          );
        }
      });
    }
  });

  group('loadPackageConfig', () {
    // Load a specific files
    group('package_config.json', () {
      var files = {
        '.packages': packagesFile,
        '.dart_tool': {'package_config.json': packageConfigFile},
      };
      loaderTest('directly', files, (Uri directory, loader) async {
        var file = directory.resolve('.dart_tool/package_config.json');
        var config = await loadPackageConfigUri(file, loader: loader);
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);
      });
      loaderTest('indirectly through .packages', files, (
        Uri directory,
        loader,
      ) async {
        // Is no longer supported.
        var file = directory.resolve('.packages');
        var hadError = false;
        await loadPackageConfigUri(
          file,
          loader: loader,
          onError: (_) {
            hadError = true;
          },
        );
        check(hadError).isTrue();
      });
    });

    loaderTest(
      'package_config.json non-default name',
      {
        '.packages': packagesFile,
        'subdir': {'pheldagriff': packageConfigFile},
      },
      (Uri directory, loader) async {
        var file = directory.resolve('subdir/pheldagriff');
        var config = await loadPackageConfigUri(file, loader: loader);
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);
      },
    );

    loaderTest(
      'package_config.json named .packages',
      {
        'subdir': {'.packages': packageConfigFile},
      },
      (Uri directory, loader) async {
        var file = directory.resolve('subdir/.packages');
        var config = await loadPackageConfigUri(file, loader: loader);
        check(config.version).equals(PackageConfig.minVersion);
        validatePackagesFile(config, directory);
      },
    );

    loaderTest('no config found', {}, (Uri directory, loader) async {
      var file = directory.resolve('anyname');
      await check(
        loadPackageConfigUri(file, loader: loader),
      ).throws<ArgumentError>();
    });

    loaderTest('no config found, handle error', {}, (
      Uri directory,
      loader,
    ) async {
      var file = directory.resolve('anyname');
      var hadError = false;
      await loadPackageConfigUri(
        file,
        loader: loader,
        onError: expectAsync1((error) {
          hadError = true;
          check(error).isA<ArgumentError>();
        }, max: -1),
      );
      check(hadError).isTrue();
    });

    loaderTest('specified file syntax error', {'anyname': 'syntax error'}, (
      Uri directory,
      loader,
    ) async {
      var file = directory.resolve('anyname');
      await check(
        loadPackageConfigUri(file, loader: loader),
      ).throws<FormatException>();
    });

    loaderTest('specified file syntax onError', {'anyname': 'syntax error'}, (
      directory,
      loader,
    ) async {
      var file = directory.resolve('anyname');
      var hadError = false;
      await loadPackageConfigUri(
        file,
        loader: loader,
        onError: expectAsync1((error) {
          hadError = true;
          check(error).isA<FormatException>();
        }, max: -1),
      );
      check(hadError).isTrue();
    });

    // Don't look for package_config.json if original name or file are bad.
    loaderTest(
      'specified file syntax error with alternative',
      {
        'anyname': 'syntax error',
        '.dart_tool': {'package_config.json': packageConfigFile},
      },
      (directory, loader) async {
        var file = directory.resolve('anyname');
        await check(
          loadPackageConfigUri(file, loader: loader),
        ).throws<FormatException>();
      },
    );

    // A file starting with `{` is a package_config.json file.
    loaderTest('file syntax error with {', {'.packages': '{syntax error'}, (
      directory,
      loader,
    ) async {
      var file = directory.resolve('.packages');
      var hadError = false;
      await loadPackageConfigUri(
        file,
        loader: loader,
        onError: expectAsync1((error) {
          hadError = true;
          check(error).isA<FormatException>();
        }, max: -1),
      );
      check(hadError).isTrue();
    });
  });
}
