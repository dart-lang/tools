[![package:unified_analytics](https://github.com/dart-lang/tools/actions/workflows/unified_analytics.yml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/unified_analytics.yml)
[![pub package](https://img.shields.io/pub/v/unified_analytics.svg)](https://pub.dev/packages/unified_analytics)
[![package publisher](https://img.shields.io/pub/publisher/unified_analytics.svg)](https://pub.dev/packages/unified_analytics/publisher)

## Hotfix `5.8.8+1` special release for Flutter 3.22

[Diff](https://github.com/dart-lang/tools/compare/unified_analytics-v5.8.8...unified_analytics-v5.8.8+1?expand=1) between `5.8.8` and this hotfix release.

This release also includes altered tests for log file related tests. This release changes the functionality for error events by not persisting them locally.

## What's this?

This package is intended to be used on Dart and Flutter related
tooling only. It provides APIs to send events to Google Analytics using the
Measurement Protocol.

This is not intended to be general purpose or consumed by the community. It is
responsible for toggling analytics collection for related tooling on each
developer's machine.

## Using this package

Refer to the [usage guide](USAGE_GUIDE.md).
