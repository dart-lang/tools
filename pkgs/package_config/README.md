[![Build Status](https://travis-ci.org/dart-lang/package_config.svg?branch=master)](https://travis-ci.org/dart-lang/package_config)
[![pub package](https://img.shields.io/pub/v/package_config.svg)](https://pub.dev/packages/package_config)

Support for working with **Package Configuration** files as described
in the Package Configuration v2 [design document](https://github.com/dart-lang/language/blob/master/accepted/future-releases/language-versioning/package-config-file-v2.md).

The primary libraries are
* `package_config.dart`:
    Defines the `PackageConfig` class and other types needed to use
    package configurations.

* `package_config_discovery.dart`:
    Provides functions for reading configurations from files,
    and writing them back out.

The package includes deprecated backwards compatible functionality to
work with the `.packages` file. This functionality will not be maintained,
and will be removed in a future version of this package.
