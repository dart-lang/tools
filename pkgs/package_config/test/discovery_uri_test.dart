// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:package_config/package_config.dart';
import 'package:test/test.dart';

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
  expect(
    resolver.resolve(pkg('foo', 'bar/baz')),
    equals(Uri.parse('file:///dart/packages/foo/bar/baz')),
  );
  expect(
    resolver.resolve(pkg('bar', 'baz/qux')),
    equals(directory.resolve('/dart/packages/bar/baz/qux')),
  );
  expect(
    resolver.resolve(pkg('baz', 'qux/foo')),
    equals(directory.resolve('packages/baz/qux/foo')),
  );
  expect([
    for (var p in resolver.packages) p.name,
  ], unorderedEquals(['foo', 'bar', 'baz']));
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
        expect(
          config.version,
          PackageConfig.minVersion,
        ); // Found package_config.json file.
        validatePackagesFile(config, directory);
        Uri file;
        (:config, :file) =
            (await findPackageConfigAndUri(directory, loader: loader))!;
        expect(
          config.version,
          PackageConfig.minVersion,
        ); // Found package_config.json file.
        validatePackagesFile(config, directory);
        expect(file, directory.resolve('.dart_tool/package_config.json'));
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
        expect(config.version, PackageConfig.minVersion);
        validatePackagesFile(config, directory);
        Uri file;
        (:config, :file) =
            (await findPackageConfigAndUri(directory, loader: loader))!;
        expect(
          config.version,
          PackageConfig.minVersion,
        ); // Found package_config.json file.
        validatePackagesFile(config, directory);
        expect(file, directory.resolve('.dart_tool/package_config.json'));
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
        expect(config, null);
        expect(
          await findPackageConfigAndUri(
            recurse: false,
            directory,
            loader: loader,
          ),
          null,
        );
      },
    );

    // Does not find a packages/ directory, and returns null if nothing found.
    loaderTest(
      'package directory packages not supported',
      {
        'packages': {'foo': <String, Object?>{}},
      },
      (directory, loader) async {
        expect(await findPackageConfigUri(directory, loader: loader), null);
        expect(await findPackageConfigAndUri(directory, loader: loader), null);
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
                expect(e, isA<PackageConfigVersionException>());
              }),
              loader: loader,
            );
            await findPackageConfigAndUri(
              directory,
              skipInvalid: skip,
              onError: expectAsync2((Object e, Uri f) {
                expect(e, isA<PackageConfigVersionException>());
                expect(f, directory.resolve('.dart_tool/package_config.json'));
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
                  expect(e, isA<PackageConfigVersionException>());
                }),
                loader: loader,
              );
              if (skip) expect(config, null);

              var configAndFile = await findPackageConfigAndUri(
                directory,
                skipInvalid: skip,
                minVersion: PackageConfig.minVersion + 1,
                onError: expectAsync2(count: skip ? 0 : 1, (Object e, Uri f) {
                  expect(e, isA<PackageConfigVersionException>());
                  expect(
                    f,
                    directory.resolve('.dart_tool/package_config.json'),
                  );
                }),
                loader: loader,
              );
              if (skip) expect(configAndFile, null);
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
        expect(config.version, PackageConfig.minVersion);
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
        expect(hadError, true);
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
        expect(config.version, PackageConfig.minVersion);
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
        expect(config.version, PackageConfig.minVersion);
        validatePackagesFile(config, directory);
      },
    );

    loaderTest('no config found', {}, (Uri directory, loader) {
      var file = directory.resolve('anyname');
      expect(
        () => loadPackageConfigUri(file, loader: loader),
        throwsA(isA<ArgumentError>()),
      );
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
          expect(error, isA<ArgumentError>());
        }, max: -1),
      );
      expect(hadError, true);
    });

    loaderTest('specified file syntax error', {'anyname': 'syntax error'}, (
      Uri directory,
      loader,
    ) {
      var file = directory.resolve('anyname');
      expect(
        () => loadPackageConfigUri(file, loader: loader),
        throwsFormatException,
      );
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
          expect(error, isA<FormatException>());
        }, max: -1),
      );
      expect(hadError, true);
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
        expect(
          () => loadPackageConfigUri(file, loader: loader),
          throwsFormatException,
        );
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
          expect(error, isA<FormatException>());
        }, max: -1),
      );
      expect(hadError, true);
    });
  });
}
