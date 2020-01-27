// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library package_config.discovery_test;

import "package:test/test.dart";
import "package:package_config_2/package_config.dart";

import "src/util.dart";

const packagesFile = """
# A comment
foo:file:///dart/packages/foo/
bar:/dart/packages/bar/
baz:packages/baz/
""";

const packageConfigFile = """
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
""";

void validatePackagesFile(PackageConfig resolver, Uri directory) {
  expect(resolver, isNotNull);
  expect(resolver.resolve(pkg("foo", "bar/baz")),
      equals(Uri.parse("file:///dart/packages/foo/bar/baz")));
  expect(resolver.resolve(pkg("bar", "baz/qux")),
      equals(directory.resolve("/dart/packages/bar/baz/qux")));
  expect(resolver.resolve(pkg("baz", "qux/foo")),
      equals(directory.resolve("packages/baz/qux/foo")));
  expect([for (var p in resolver.packages) p.name],
      unorderedEquals(["foo", "bar", "baz"]));
}

main() {
  group("findPackages", () {
    // Finds package_config.json if there.
    loaderTest("package_config.json", {
      ".packages": "invalid .packages file",
      "script.dart": "main(){}",
      "packages": {"shouldNotBeFound": {}},
      ".dart_tool": {
        "package_config.json": packageConfigFile,
      }
    }, (Uri directory, loader) async {
      PackageConfig config =
          await findPackageConfigUri(directory, loader: loader);
      expect(config.version, 2); // Found package_config.json file.
      validatePackagesFile(config, directory);
    });

    // Finds .packages if no package_config.json.
    loaderTest(".packages", {
      ".packages": packagesFile,
      "script.dart": "main(){}",
      "packages": {"shouldNotBeFound": {}}
    }, (Uri directory, loader) async {
      PackageConfig config =
          await findPackageConfigUri(directory, loader: loader);
      expect(config.version, 1); // Found .packages file.
      validatePackagesFile(config, directory);
    });

    // Finds package_config.json in super-directory.
    loaderTest("package_config.json recursive", {
      ".packages": packagesFile,
      ".dart_tool": {
        "package_config.json": packageConfigFile,
      },
      "subdir": {
        "script.dart": "main(){}",
      }
    }, (Uri directory, loader) async {
      PackageConfig config = await findPackageConfigUri(
          directory.resolve("subdir/"),
          loader: loader);
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });

    // Finds .packages in super-directory.
    loaderTest(".packages recursive", {
      ".packages": packagesFile,
      "subdir": {"script.dart": "main(){}"}
    }, (Uri directory, loader) async {
      PackageConfig config;
      config = await findPackageConfigUri(directory.resolve("subdir/"),
          loader: loader);
      expect(config.version, 1);
      validatePackagesFile(config, directory);
    });

    // Does not find a packages/ directory, and returns null if nothing found.
    loaderTest("package directory packages not supported", {
      "packages": {
        "foo": {},
      }
    }, (Uri directory, loader) async {
      PackageConfig config =
          await findPackageConfigUri(directory, loader: loader);
      expect(config, null);
    });

    loaderTest("invalid .packages", {
      ".packages": "not a .packages file",
    }, (Uri directory, loader) {
      expect(() => findPackageConfigUri(directory, loader: loader),
          throwsA(TypeMatcher<FormatException>()));
    });

    loaderTest("invalid .packages as JSON", {
      ".packages": packageConfigFile,
    }, (Uri directory, loader) {
      expect(() => findPackageConfigUri(directory, loader: loader),
          throwsA(TypeMatcher<FormatException>()));
    });

    loaderTest("invalid .packages", {
      ".dart_tool": {
        "package_config.json": "not a JSON file",
      }
    }, (Uri directory, loader) {
      expect(() => findPackageConfigUri(directory, loader: loader),
          throwsA(TypeMatcher<FormatException>()));
    });

    loaderTest("invalid .packages as INI", {
      ".dart_tool": {
        "package_config.json": packagesFile,
      }
    }, (Uri directory, loader) {
      expect(() => findPackageConfigUri(directory, loader: loader),
          throwsA(TypeMatcher<FormatException>()));
    });
  });

  group("loadPackageConfig", () {
    // Load a specific files
    group("package_config.json", () {
      var files = {
        ".packages": packagesFile,
        ".dart_tool": {
          "package_config.json": packageConfigFile,
        },
      };
      loaderTest("directly", files, (Uri directory, loader) async {
        Uri file = directory.resolve(".dart_tool/package_config.json");
        PackageConfig config = await loadPackageConfigUri(file, loader: loader);
        expect(config.version, 2);
        validatePackagesFile(config, directory);
      });
      loaderTest("indirectly through .packages", files,
          (Uri directory, loader) async {
        Uri file = directory.resolve(".packages");
        PackageConfig config = await loadPackageConfigUri(file, loader: loader);
        expect(config.version, 2);
        validatePackagesFile(config, directory);
      });
    });

    loaderTest("package_config.json non-default name", {
      ".packages": packagesFile,
      "subdir": {
        "pheldagriff": packageConfigFile,
      },
    }, (Uri directory, loader) async {
      Uri file = directory.resolve("subdir/pheldagriff");
      PackageConfig config = await loadPackageConfigUri(file, loader: loader);
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });

    loaderTest("package_config.json named .packages", {
      "subdir": {
        ".packages": packageConfigFile,
      },
    }, (Uri directory, loader) async {
      Uri file = directory.resolve("subdir/.packages");
      PackageConfig config = await loadPackageConfigUri(file, loader: loader);
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });

    loaderTest(".packages", {
      ".packages": packagesFile,
    }, (Uri directory, loader) async {
      Uri file = directory.resolve(".packages");
      PackageConfig config = await loadPackageConfigUri(file, loader: loader);
      expect(config.version, 1);
      validatePackagesFile(config, directory);
    });

    loaderTest(".packages non-default name", {
      "pheldagriff": packagesFile,
    }, (Uri directory, loader) async {
      Uri file = directory.resolve("pheldagriff");
      PackageConfig config = await loadPackageConfigUri(file, loader: loader);
      expect(config.version, 1);
      validatePackagesFile(config, directory);
    });

    loaderTest("no config found", {}, (Uri directory, loader) {
      Uri file = directory.resolve("anyname");
      expect(() => loadPackageConfigUri(file, loader: loader),
          throwsArgumentError);
    });

    loaderTest("specified file syntax error", {
      "anyname": "syntax error",
    }, (Uri directory, loader) {
      Uri file = directory.resolve("anyname");
      expect(() => loadPackageConfigUri(file, loader: loader),
          throwsFormatException);
    });

    // Find package_config.json in subdir even if initial file syntax error.
    loaderTest("specified file syntax error", {
      "anyname": "syntax error",
      ".dart_tool": {
        "package_config.json": packageConfigFile,
      },
    }, (Uri directory, loader) async {
      Uri file = directory.resolve("anyname");
      PackageConfig config = await loadPackageConfigUri(file, loader: loader);
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });

    // A file starting with `{` is a package_config.json file.
    loaderTest("file syntax error with {", {
      ".packages": "{syntax error",
    }, (Uri directory, loader) {
      Uri file = directory.resolve(".packages");
      expect(() => loadPackageConfigUri(file, loader: loader),
          throwsFormatException);
    });
  });
}
