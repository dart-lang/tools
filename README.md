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

| Package | Description | Issues | Version |
| --- | --- | --- | --- |
| [bazel_worker](pkgs/bazel_worker/) | Protocol and utilities to implement or invoke persistent bazel workers. | [![issues](https://img.shields.io/badge/issues-4774bc)][bazel_worker] | [![pub package](https://img.shields.io/pub/v/bazel_worker.svg)](https://pub.dev/packages/bazel_worker) |
| [benchmark_harness](pkgs/benchmark_harness/) | The official Dart project benchmark harness. | [![issues](https://img.shields.io/badge/issues-4774bc)][benchmark_harness] | [![pub package](https://img.shields.io/pub/v/benchmark_harness.svg)](https://pub.dev/packages/benchmark_harness) |
| [boolean_selector](pkgs/boolean_selector/) | A flexible syntax for boolean expressions, based on a simplified version of Dart's expression syntax. | [![issues](https://img.shields.io/badge/issues-4774bc)][boolean_selector] | [![pub package](https://img.shields.io/pub/v/boolean_selector.svg)](https://pub.dev/packages/boolean_selector) |
| [browser_launcher](pkgs/browser_launcher/) | Provides a standardized way to launch web browsers for testing and tools. | [![issues](https://img.shields.io/badge/issues-4774bc)][browser_launcher] | [![pub package](https://img.shields.io/pub/v/browser_launcher.svg)](https://pub.dev/packages/browser_launcher) |
| [cli_config](pkgs/cli_config/) | A library to take config values from configuration files, CLI arguments, and environment variables. | [![issues](https://img.shields.io/badge/issues-4774bc)][cli_config] | [![pub package](https://img.shields.io/pub/v/cli_config.svg)](https://pub.dev/packages/cli_config) |
| [cli_util](pkgs/cli_util/) | A library to help in building Dart command-line apps. | [![issues](https://img.shields.io/badge/issues-4774bc)][cli_util] | [![pub package](https://img.shields.io/pub/v/cli_util.svg)](https://pub.dev/packages/cli_util) |
| [clock](pkgs/clock/) | A fakeable wrapper for dart:core clock APIs. | [![issues](https://img.shields.io/badge/issues-4774bc)][clock] | [![pub package](https://img.shields.io/pub/v/clock.svg)](https://pub.dev/packages/clock) |
| [code_builder](pkgs/code_builder/) | A fluent, builder-based library for generating valid Dart code. | [![issues](https://img.shields.io/badge/issues-4774bc)][code_builder] | [![pub package](https://img.shields.io/pub/v/code_builder.svg)](https://pub.dev/packages/code_builder) |
| [coverage](pkgs/coverage/) | Coverage data manipulation and formatting | [![issues](https://img.shields.io/badge/issues-4774bc)][coverage] | [![pub package](https://img.shields.io/pub/v/coverage.svg)](https://pub.dev/packages/coverage) |
| [csslib](pkgs/csslib/) | A library for parsing and analyzing CSS (Cascading Style Sheets). | [![issues](https://img.shields.io/badge/issues-4774bc)][csslib] | [![pub package](https://img.shields.io/pub/v/csslib.svg)](https://pub.dev/packages/csslib) |
| [extension_discovery](pkgs/extension_discovery/) | A convention and utilities for package extension discovery. | [![issues](https://img.shields.io/badge/issues-4774bc)][extension_discovery] | [![pub package](https://img.shields.io/pub/v/extension_discovery.svg)](https://pub.dev/packages/extension_discovery) |
| [file](pkgs/file/) | A pluggable, mockable file system abstraction for Dart. | [![issues](https://img.shields.io/badge/issues-4774bc)][file] | [![pub package](https://img.shields.io/pub/v/file.svg)](https://pub.dev/packages/file) |
| [file_testing](pkgs/file_testing/) | Testing utilities for package:file. | [![issues](https://img.shields.io/badge/issues-4774bc)][file_testing] | [![pub package](https://img.shields.io/pub/v/file_testing.svg)](https://pub.dev/packages/file_testing) |
| [graphs](pkgs/graphs/) | Graph algorithms that operate on graphs in any representation. | [![issues](https://img.shields.io/badge/issues-4774bc)][graphs] | [![pub package](https://img.shields.io/pub/v/graphs.svg)](https://pub.dev/packages/graphs) |
| [html](pkgs/html/) | APIs for parsing and manipulating HTML content outside the browser. | [![issues](https://img.shields.io/badge/issues-4774bc)][html] | [![pub package](https://img.shields.io/pub/v/html.svg)](https://pub.dev/packages/html) |
| [io](pkgs/io/) | Utilities for the Dart VM Runtime including support for ANSI colors, file copying, and standard exit code values. | [![issues](https://img.shields.io/badge/issues-4774bc)][io] | [![pub package](https://img.shields.io/pub/v/io.svg)](https://pub.dev/packages/io) |
| [json_rpc_2](pkgs/json_rpc_2/) | Utilities to write a client or server using the JSON-RPC 2.0 spec. | [![issues](https://img.shields.io/badge/issues-4774bc)][json_rpc_2] | [![pub package](https://img.shields.io/pub/v/json_rpc_2.svg)](https://pub.dev/packages/json_rpc_2) |
| [markdown](pkgs/markdown/) | A portable Markdown library written in Dart that can parse Markdown into HTML. | [![issues](https://img.shields.io/badge/issues-4774bc)][markdown] | [![pub package](https://img.shields.io/pub/v/markdown.svg)](https://pub.dev/packages/markdown) |
| [mime](pkgs/mime/) | Utilities for handling media (MIME) types, including determining a type from a file extension and file contents. | [![issues](https://img.shields.io/badge/issues-4774bc)][mime] | [![pub package](https://img.shields.io/pub/v/mime.svg)](https://pub.dev/packages/mime) |
| [oauth2](pkgs/oauth2/) | A client library for authenticating with a remote service via OAuth2 on behalf of a user, and making authorized HTTP requests with the user's OAuth2 credentials. | [![issues](https://img.shields.io/badge/issues-4774bc)][oauth2] | [![pub package](https://img.shields.io/pub/v/oauth2.svg)](https://pub.dev/packages/oauth2) |
| [package_config](pkgs/package_config/) | Support for reading and writing Dart Package Configuration files. | [![issues](https://img.shields.io/badge/issues-4774bc)][package_config] | [![pub package](https://img.shields.io/pub/v/package_config.svg)](https://pub.dev/packages/package_config) |
| [pool](pkgs/pool/) | Manage a finite pool of resources. Useful for controlling concurrent file system or network requests. | [![issues](https://img.shields.io/badge/issues-4774bc)][pool] | [![pub package](https://img.shields.io/pub/v/pool.svg)](https://pub.dev/packages/pool) |
| [pub_semver](pkgs/pub_semver/) | Versions and version constraints implementing pub's versioning policy. This is very similar to vanilla semver, with a few corner cases. | [![issues](https://img.shields.io/badge/issues-4774bc)][pub_semver] | [![pub package](https://img.shields.io/pub/v/pub_semver.svg)](https://pub.dev/packages/pub_semver) |
| [pubspec_parse](pkgs/pubspec_parse/) | Simple package for parsing pubspec.yaml files with a type-safe API and rich error reporting. | [![issues](https://img.shields.io/badge/issues-4774bc)][pubspec_parse] | [![pub package](https://img.shields.io/pub/v/pubspec_parse.svg)](https://pub.dev/packages/pubspec_parse) |
| [source_map_stack_trace](pkgs/source_map_stack_trace/) | A package for applying source maps to stack traces. | [![issues](https://img.shields.io/badge/issues-4774bc)][source_map_stack_trace] | [![pub package](https://img.shields.io/pub/v/source_map_stack_trace.svg)](https://pub.dev/packages/source_map_stack_trace) |
| [source_maps](pkgs/source_maps/) | A library to programmatically manipulate source map files. | [![issues](https://img.shields.io/badge/issues-4774bc)][source_maps] | [![pub package](https://img.shields.io/pub/v/source_maps.svg)](https://pub.dev/packages/source_maps) |
| [source_span](pkgs/source_span/) | Provides a standard representation for source code locations and spans. | [![issues](https://img.shields.io/badge/issues-4774bc)][source_span] | [![pub package](https://img.shields.io/pub/v/source_span.svg)](https://pub.dev/packages/source_span) |
| [sse](pkgs/sse/) | Provides client and server functionality for setting up bi-directional communication through Server Sent Events (SSE) and corresponding POST requests. | [![issues](https://img.shields.io/badge/issues-4774bc)][sse] | [![pub package](https://img.shields.io/pub/v/sse.svg)](https://pub.dev/packages/sse) |
| [stack_trace](pkgs/stack_trace/) | A package for manipulating stack traces and printing them readably. | [![issues](https://img.shields.io/badge/issues-4774bc)][stack_trace] | [![pub package](https://img.shields.io/pub/v/stack_trace.svg)](https://pub.dev/packages/stack_trace) |
| [stream_channel](pkgs/stream_channel/) | An abstraction for two-way communication channels based on the Dart Stream class. | [![issues](https://img.shields.io/badge/issues-4774bc)][stream_channel] | [![pub package](https://img.shields.io/pub/v/stream_channel.svg)](https://pub.dev/packages/stream_channel) |
| [stream_transform](pkgs/stream_transform/) | A collection of utilities to transform and manipulate streams. | [![issues](https://img.shields.io/badge/issues-4774bc)][stream_transform] | [![pub package](https://img.shields.io/pub/v/stream_transform.svg)](https://pub.dev/packages/stream_transform) |
| [string_scanner](pkgs/string_scanner/) | A class for parsing strings using a sequence of patterns. | [![issues](https://img.shields.io/badge/issues-4774bc)][string_scanner] | [![pub package](https://img.shields.io/pub/v/string_scanner.svg)](https://pub.dev/packages/string_scanner) |
| [term_glyph](pkgs/term_glyph/) | Useful Unicode glyphs and ASCII substitutes. | [![issues](https://img.shields.io/badge/issues-4774bc)][term_glyph] | [![pub package](https://img.shields.io/pub/v/term_glyph.svg)](https://pub.dev/packages/term_glyph) |
| [test_reflective_loader](pkgs/test_reflective_loader/) | Support for discovering tests and test suites using reflection. | [![issues](https://img.shields.io/badge/issues-4774bc)][test_reflective_loader] | [![pub package](https://img.shields.io/pub/v/test_reflective_loader.svg)](https://pub.dev/packages/test_reflective_loader) |
| [timing](pkgs/timing/) | A simple package for tracking the performance of synchronous and asynchronous actions. | [![issues](https://img.shields.io/badge/issues-4774bc)][timing] | [![pub package](https://img.shields.io/pub/v/timing.svg)](https://pub.dev/packages/timing) |
| [unified_analytics](pkgs/unified_analytics/) | A package for logging analytics for all Dart and Flutter related tooling to Google Analytics. | [![issues](https://img.shields.io/badge/issues-4774bc)][unified_analytics] | [![pub package](https://img.shields.io/pub/v/unified_analytics.svg)](https://pub.dev/packages/unified_analytics) |
| [watcher](pkgs/watcher/) | A file system watcher. It monitors changes to contents of directories and sends notifications when files have been added, removed, or modified. | [![issues](https://img.shields.io/badge/issues-4774bc)][watcher] | [![pub package](https://img.shields.io/pub/v/watcher.svg)](https://pub.dev/packages/watcher) |
| [yaml](pkgs/yaml/) | A parser for YAML, a human-friendly data serialization standard | [![issues](https://img.shields.io/badge/issues-4774bc)][yaml] | [![pub package](https://img.shields.io/pub/v/yaml.svg)](https://pub.dev/packages/yaml) |
| [yaml_edit](pkgs/yaml_edit/) | A library for YAML manipulation with comment and whitespace preservation. | [![issues](https://img.shields.io/badge/issues-4774bc)][yaml_edit] | [![pub package](https://img.shields.io/pub/v/yaml_edit.svg)](https://pub.dev/packages/yaml_edit) |

[bazel_worker_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Abazel_worker
[benchmark_harness_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Abenchmark_harness
[boolean_selector_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Aboolean_selector
[browser_launcher_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Abrowser_launcher
[cli_config_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Acli_config
[cli_util_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Acli_util
[clock_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Aclock
[code_builder_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Acode_builder
[coverage_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Acoverage
[csslib_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Acsslib
[extension_discovery_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Aextension_discovery
[file_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Afile
[file_testing_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Afile_testing
[graphs_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Agraphs
[html_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ahtml
[io_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Aio
[json_rpc_2_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ajson_rpc_2
[markdown_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Amarkdown
[mime_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Amime
[oauth2_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Aoauth2
[package_config_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Apackage_config
[pool_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Apool
[pub_semver_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Apub_semver
[pubspec_parse_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Apubspec_parse
[source_map_stack_trace_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Asource_map_stack_trace
[source_maps_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Asource_maps
[source_span_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Asource_span
[sse_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Asse
[stack_trace_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Astack_trace
[stream_channel_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Astream_channel
[stream_transform_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Astream_transform
[string_scanner_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Astring_scanner
[term_glyph_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Aterm_glyph
[test_reflective_loader_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Atest_reflective_loader
[timing_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Atiming
[unified_analytics_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Aunified_analytics
[watcher_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Awatcher
[yaml_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ayaml
[yaml_edit_issues]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ayaml_edit

## Publishing automation

For information about our publishing automation and release process, see
https://github.com/dart-lang/ecosystem/wiki/Publishing-automation.

For additional information about contributing, see our
[contributing](CONTRIBUTING.md) page.
