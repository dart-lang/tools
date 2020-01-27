// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library package_config.discovery_test;

import "dart:io";
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

void validatePackagesFile(PackageConfig resolver, Directory directory) {
  expect(resolver, isNotNull);
  expect(resolver.resolve(pkg("foo", "bar/baz")),
      equals(Uri.parse("file:///dart/packages/foo/bar/baz")));
  expect(resolver.resolve(pkg("bar", "baz/qux")),
      equals(Uri.parse("file:///dart/packages/bar/baz/qux")));
  expect(resolver.resolve(pkg("baz", "qux/foo")),
      equals(Uri.directory(directory.path).resolve("packages/baz/qux/foo")));
  expect([for (var p in resolver.packages) p.name],
      unorderedEquals(["foo", "bar", "baz"]));
}

main() {
  group("findPackages", () {
    // Finds package_config.json if there.
    fileTest("package_config.json", {
      ".packages": "invalid .packages file",
      "script.dart": "main(){}",
      "packages": {"shouldNotBeFound": {}},
      ".dart_tool": {
        "package_config.json": packageConfigFile,
      }
    }, (Directory directory) async {
      PackageConfig config = await findPackageConfig(directory);
      expect(config.version, 2); // Found package_config.json file.
      validatePackagesFile(config, directory);
    });

    // Finds .packages if no package_config.json.
    fileTest(".packages", {
      ".packages": packagesFile,
      "script.dart": "main(){}",
      "packages": {"shouldNotBeFound": {}}
    }, (Directory directory) async {
      PackageConfig config = await findPackageConfig(directory);
      expect(config.version, 1); // Found .packages file.
      validatePackagesFile(config, directory);
    });

    // Finds package_config.json in super-directory.
    fileTest("package_config.json recursive", {
      ".packages": packagesFile,
      ".dart_tool": {
        "package_config.json": packageConfigFile,
      },
      "subdir": {
        "script.dart": "main(){}",
      }
    }, (Directory directory) async {
      PackageConfig config =
          await findPackageConfig(subdir(directory, "subdir/"));
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });

    // Finds .packages in super-directory.
    fileTest(".packages recursive", {
      ".packages": packagesFile,
      "subdir": {"script.dart": "main(){}"}
    }, (Directory directory) async {
      PackageConfig config;
      config = await findPackageConfig(subdir(directory, "subdir/"));
      expect(config.version, 1);
      validatePackagesFile(config, directory);
    });

    // Does not find a packages/ directory, and returns null if nothing found.
    fileTest("package directory packages not supported", {
      "packages": {
        "foo": {},
      }
    }, (Directory directory) async {
      PackageConfig config = await findPackageConfig(directory);
      expect(config, null);
    });

    fileTest("invalid .packages", {
      ".packages": "not a .packages file",
    }, (Directory directory) {
      expect(() => findPackageConfig(directory),
          throwsA(TypeMatcher<FormatException>()));
    });

    fileTest("invalid .packages as JSON", {
      ".packages": packageConfigFile,
    }, (Directory directory) {
      expect(() => findPackageConfig(directory),
          throwsA(TypeMatcher<FormatException>()));
    });

    fileTest("invalid .packages", {
      ".dart_tool": {
        "package_config.json": "not a JSON file",
      }
    }, (Directory directory) {
      expect(() => findPackageConfig(directory),
          throwsA(TypeMatcher<FormatException>()));
    });

    fileTest("invalid .packages as INI", {
      ".dart_tool": {
        "package_config.json": packagesFile,
      }
    }, (Directory directory) {
      expect(() => findPackageConfig(directory),
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
      fileTest("directly", files, (Directory directory) async {
        File file =
            dirFile(subdir(directory, ".dart_tool"), "package_config.json");
        PackageConfig config = await loadPackageConfig(file);
        expect(config.version, 2);
        validatePackagesFile(config, directory);
      });
      fileTest("indirectly through .packages", files,
          (Directory directory) async {
        File file = dirFile(directory, ".packages");
        PackageConfig config = await loadPackageConfig(file);
        expect(config.version, 2);
        validatePackagesFile(config, directory);
      });
      fileTest("prefer .packages", files, (Directory directory) async {
        File file = dirFile(directory, ".packages");
        PackageConfig config =
            await loadPackageConfig(file, preferNewest: false);
        expect(config.version, 1);
        validatePackagesFile(config, directory);
      });
    });

    fileTest("package_config.json non-default name", {
      ".packages": packagesFile,
      "subdir": {
        "pheldagriff": packageConfigFile,
      },
    }, (Directory directory) async {
      File file = dirFile(directory, "subdir/pheldagriff");
      PackageConfig config = await loadPackageConfig(file);
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });

    fileTest("package_config.json named .packages", {
      "subdir": {
        ".packages": packageConfigFile,
      },
    }, (Directory directory) async {
      File file = dirFile(directory, "subdir/.packages");
      PackageConfig config = await loadPackageConfig(file);
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });

    fileTest(".packages", {
      ".packages": packagesFile,
    }, (Directory directory) async {
      File file = dirFile(directory, ".packages");
      PackageConfig config = await loadPackageConfig(file);
      expect(config.version, 1);
      validatePackagesFile(config, directory);
    });

    fileTest(".packages non-default name", {
      "pheldagriff": packagesFile,
    }, (Directory directory) async {
      File file = dirFile(directory, "pheldagriff");
      PackageConfig config = await loadPackageConfig(file);
      expect(config.version, 1);
      validatePackagesFile(config, directory);
    });

    fileTest("no config found", {}, (Directory directory) {
      File file = dirFile(directory, "anyname");
      expect(() => loadPackageConfig(file),
          throwsA(TypeMatcher<FileSystemException>()));
    });

    fileTest("specified file syntax error", {
      "anyname": "syntax error",
    }, (Directory directory) {
      File file = dirFile(directory, "anyname");
      expect(() => loadPackageConfig(file), throwsFormatException);
    });

    // Find package_config.json in subdir even if initial file syntax error.
    fileTest("specified file syntax error", {
      "anyname": "syntax error",
      ".dart_tool": {
        "package_config.json": packageConfigFile,
      },
    }, (Directory directory) async {
      File file = dirFile(directory, "anyname");
      PackageConfig config = await loadPackageConfig(file);
      expect(config.version, 2);
      validatePackagesFile(config, directory);
    });

    // A file starting with `{` is a package_config.json file.
    fileTest("file syntax error with {", {
      ".packages": "{syntax error",
    }, (Directory directory) {
      File file = dirFile(directory, ".packages");
      expect(() => loadPackageConfig(file), throwsFormatException);
    });
  });
}
