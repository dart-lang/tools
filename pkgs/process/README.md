[![pub package](https://img.shields.io/pub/v/process.svg)](https://pub.dev/packages/process)
[![package publisher](https://img.shields.io/pub/publisher/process.svg)](https://pub.dev/packages/process/publisher)

A pluggable, mockable process invocation abstraction for Dart.

## What's this?

A generic process invocation abstraction for Dart.

Like `dart:io`, `package:process` supplies a rich, Dart-idiomatic API for
spawning OS processes.

Unlike `dart:io`, `package:process` requires processes to be started with
[ProcessManager], which allows for easy mocking and testing of code that
spawns processes in a hermetic way.

[ProcessManager]: https://pub.dev/documentation/process/latest/process/ProcessManager-class.html
