// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:test/test.dart';

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
  "configVersion": 2,
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
  expect(resolver, isNotNull);
  expect(resolver.resolve(pkg('foo', 'bar/baz')),
      equals(Uri.parse('file:///dart/packages/foo/bar/baz')));
  expect(resolver.resolve(pkg('bar', 'baz/qux')),
      equals(Uri.parse('file:///dart/packages/bar/baz/qux')));
  expect(resolver.resolve(pkg('baz', 'qux/foo')),
      equals(Uri.directory(directory.path).resolve('packages/baz/qux/foo')));
  expect([for (var p in resolver.packages) p.name],
      unorderedEquals(['foo', 'bar', 'baz']));
}

void main() {
  group('findPackages', () {
    // Finds package_config.json if there.
    fileTest('package_config.json', {
      '.packages': 'invalid .packages file',
      'script.dart': 'main(){}',
      'packages': {'shouldNotBeFound': <Never, Never>{}},
      '.dart_tool': {
        'package_config.json': packageConfigFile,
      }
    }, (Directory directory) async {
      var config = (await findPackageConfig(directory))!;
      expect(config.version, 2); // Found package_config.json file.
      validatePackagesFile(config, directory);
    });

    // Does not find .packages if no package_config.json.
    fileTest('.packages', {
      '.packages': packagesFile,
      'script.dart': 'main(){}',
      'packages': {'shouldNotBeFound': <Object, Object>{}}
    }, (Directory directory) async {
      var config = await findPackageConfig(directory);
      expect(config, null);
    });

    // Finds package_config.json in super-directory.
    fileTest('package_config.json recursive', {
      '.packages': packagesFile,
      '.dart_tool': {
        'package_config.json': packageConfigFile,
      },
      'subdir': {
        '.packages': packagesFile,
        'script.dart': 'main(){}',
      }
    }, (Directory directory) async {
      var config = (await findPackageConfig(subdir(directory, 'subdir/')))!;
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });

    // Does not find a packages/ directory, and returns null if nothing found.
    fileTest('package directory packages not supported', {
      'packages': {
        'foo': <String, dynamic>{},
      }
    }, (Directory directory) async {
      var config = await findPackageConfig(directory);
      expect(config, null);
    });

    group('throws', () {
      fileTest('invalid package config not JSON', {
        '.dart_tool': {
          'package_config.json': 'not a JSON file',
        }
      }, (Directory directory) {
        expect(findPackageConfig(directory), throwsA(isA<FormatException>()));
      });

      fileTest('invalid package config as INI', {
        '.dart_tool': {
          'package_config.json': packagesFile,
        }
      }, (Directory directory) {
        expect(findPackageConfig(directory), throwsA(isA<FormatException>()));
      });

      fileTest('indirectly through .packages', {
        '.packages': packagesFile,
        '.dart_tool': {
          'package_config.json': packageConfigFile,
        },
      }, (Directory directory) async {
        // A .packages file in the directory of a .dart_tool/package_config.json
        // used to automatically redirect to the package_config.json.
        var file = dirFile(directory, '.packages');
        expect(loadPackageConfig(file), throwsA(isA<FormatException>()));
      });
    });

    group('handles error', () {
      fileTest('invalid package config not JSON', {
        '.dart_tool': {
          'package_config.json': 'not a JSON file',
        }
      }, (Directory directory) async {
        var hadError = false;
        await findPackageConfig(directory,
            onError: expectAsync1((error) {
              hadError = true;
              expect(error, isA<FormatException>());
            }, max: -1));
        expect(hadError, true);
      });

      fileTest('invalid package config as INI', {
        '.dart_tool': {
          'package_config.json': packagesFile,
        }
      }, (Directory directory) async {
        var hadError = false;
        await findPackageConfig(directory,
            onError: expectAsync1((error) {
              hadError = true;
              expect(error, isA<FormatException>());
            }, max: -1));
        expect(hadError, true);
      });
    });

    // Does not find .packages if no package_config.json and minVersion > 1.
    fileTest('.packages ignored', {
      '.packages': packagesFile,
      'script.dart': 'main(){}'
    }, (Directory directory) async {
      var config = await findPackageConfig(directory, minVersion: 2);
      expect(config, null);
    });

    // Finds package_config.json in super-directory.
    // (Even with `.packages` in search directory.)
    fileTest('package_config.json recursive .packages ignored', {
      '.dart_tool': {
        'package_config.json': packageConfigFile,
      },
      'subdir': {
        '.packages': packagesFile,
        'script.dart': 'main(){}',
      }
    }, (Directory directory) async {
      var config = (await findPackageConfig(subdir(directory, 'subdir/'),
          minVersion: 2))!;
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });
  });

  group('loadPackageConfig', () {
    // Load a specific files
    group('package_config.json', () {
      var files = {
        '.packages': packagesFile,
        '.dart_tool': {
          'package_config.json': packageConfigFile,
        },
      };
      fileTest('directly', files, (Directory directory) async {
        var file =
            dirFile(subdir(directory, '.dart_tool'), 'package_config.json');
        var config = await loadPackageConfig(file);
        expect(config.version, 2);
        validatePackagesFile(config, directory);
      });
    });

    fileTest('package_config.json non-default name', {
      '.packages': packagesFile,
      'subdir': {
        'pheldagriff': packageConfigFile,
      },
    }, (Directory directory) async {
      var file = dirFile(directory, 'subdir/pheldagriff');
      var config = await loadPackageConfig(file);
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });

    fileTest('package_config.json named .packages', {
      'subdir': {
        '.packages': packageConfigFile,
      },
    }, (Directory directory) async {
      var file = dirFile(directory, 'subdir/.packages');
      var config = await loadPackageConfig(file);
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });

    fileTest('.packages cannot be loaded', {
      '.packages': packagesFile,
    }, (Directory directory) async {
      var file = dirFile(directory, '.packages');
      expect(loadPackageConfig(file), throwsFormatException);
    });

    fileTest('no config file found', {}, (Directory directory) {
      var file = dirFile(directory, 'any_name');
      expect(
          () => loadPackageConfig(file), throwsA(isA<FileSystemException>()));
    });

    fileTest('no config found, handled', {}, (Directory directory) async {
      var file = dirFile(directory, 'any_name');
      var hadError = false;
      await loadPackageConfig(file,
          onError: expectAsync1((error) {
            hadError = true;
            expect(error, isA<FileSystemException>());
          }, max: -1));
      expect(hadError, true);
    });

    fileTest('specified file syntax error', {
      'any_name': 'syntax error',
    }, (Directory directory) {
      var file = dirFile(directory, 'any_name');
      expect(() => loadPackageConfig(file), throwsFormatException);
    });
  });
}
