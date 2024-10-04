<!-- [![Dart CI](https://github.com/dart-lang/tools/actions/workflows/dart.yml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/dart.yml) -->

## Overview

This repository is home to tooling related Dart packages. Generally, this means
packages published through the
[tools.dart.dev](https://pub.dev/publishers/tools.dart.dev) publisher that
don't naturally belong to other topic monorepos (like
[dart-lang/build](https://github.com/dart-lang/build),
[dart-lang/test](https://github.com/dart-lang/test), or
[dart-lang/shelf](https://github.com/dart-lang/shelf)).

## Packages

| Package | Description | Version |
| --- | --- | --- |
| [cli_config](pkgs/cli_config/) | A library to take config values from configuration files, CLI arguments, and environment variables. | [![pub package](https://img.shields.io/pub/v/cli_config.svg)](https://pub.dev/packages/cli_config) |
| [coverage](pkgs/coverage/) | Coverage data manipulation and formatting. | [![pub package](https://img.shields.io/pub/v/coverage.svg)](https://pub.dev/packages/coverage) |
| [extension_discovery](pkgs/extension_discovery/) | A convention and utilities for package extension discovery. | [![pub package](https://img.shields.io/pub/v/extension_discovery.svg)](https://pub.dev/packages/extension_discovery) |
| [file](pkgs/file/) | A pluggable, mockable file system abstraction for Dart. | [![pub package](https://img.shields.io/pub/v/file.svg)](https://pub.dev/packages/file) |
| [file_testing](pkgs/file_testing/) | Testing utilities for package:file (published but unlisted). | [![pub package](https://img.shields.io/pub/v/file_testing.svg)](https://pub.dev/packages/file_testing) |
| [graphs](pkgs/graphs/) | Graph algorithms that operate on graphs in any representation | [![pub package](https://img.shields.io/pub/v/graphs.svg)](https://pub.dev/packages/graphs) |
| [mime](pkgs/mime/) | Utilities for handling media (MIME) types. | [![pub package](https://img.shields.io/pub/v/mime.svg)](https://pub.dev/packages/mime) |
| [oauth2](pkgs/oauth2/) | A client library for authenticatingand making requests via OAuth2. | [![pub package](https://img.shields.io/pub/v/oauth2.svg)](https://pub.dev/packages/oauth2) |
| [source_map_stack_trace](pkgs/source_map_stack_trace/) | A package for applying source maps to stack traces. | [![pub package](https://img.shields.io/pub/v/source_map_stack_trace.svg)](https://pub.dev/packages/source_map_stack_trace) |
| [unified_analytics](pkgs/unified_analytics/) | A package for logging analytics for all Dart and Flutter related tooling to Google Analytics. | [![pub package](https://img.shields.io/pub/v/unified_analytics.svg)](https://pub.dev/packages/unified_analytics) |

## Publishing automation

For information about our publishing automation and release process, see
https://github.com/dart-lang/ecosystem/wiki/Publishing-automation.

For additional information about contributing, see our
[contributing](CONTRIBUTING.md) page.
