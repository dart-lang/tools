[![Build Status](https://github.com/dart-lang/tools/actions/workflows/cli_util.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/cli_util.yaml)
[![Pub](https://img.shields.io/pub/v/cli_util.svg)](https://pub.dev/packages/cli_util)
[![package publisher](https://img.shields.io/pub/publisher/cli_util.svg)](https://pub.dev/packages/cli_util/publisher)

A package to help in building Dart command-line apps.

## What's this?

`package:cli_util` provides:
- utilities to find the Dart SDK directory (`sdkPath`) and the `dart` and
  `flutter` executables (`dartExecutable`, `flutterExecutable`)
- utilities to find the settings directory for a tool (`applicationConfigHome()`)
- utilities to aid in showing rich CLI output and progress information (`cli_logging.dart`)

## Locating the Dart SDK and executables

```dart
import 'dart:io';

import 'package:cli_util/cli_util.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) {
  // Get SDK directory from cli_util.
  final sdkDir = sdkPath;
  if (sdkDir != null) {
    // Do stuff... For example, print version string
    final versionFile = File(path.join(sdkDir, 'version'));
    print(versionFile.readAsStringSync());
  }

  // Locate the dart and flutter executables if available.
  print('Dart: $dartExecutable');
  print('Flutter: $flutterExecutable');
}
```

## Displaying output and progress

`package:cli_util` can also be used to help CLI tools display output and progress.
It has a logging mechanism which can help differentiate between regular tool
output and error messages, and can facilitate having a more verbose (`-v`) mode for
output.

In addition, it can display an indeterminate progress spinner for longer running
tasks, and optionally display the elapsed time when finished: 

```dart
import 'package:cli_util/cli_logging.dart';

void main(List<String> args) async {
  var verbose = args.contains('-v');
  var logger = verbose ? Logger.verbose() : Logger.standard();

  logger.stdout('Hello world!');
  logger.trace('message 1');
  await Future.delayed(Duration(milliseconds: 200));
  logger.trace('message 2');
  logger.trace('message 3');

  var progress = logger.progress('doing some work');
  await Future.delayed(Duration(seconds: 2));
  progress.finish(showTiming: true);

  logger.stdout('All ${logger.ansi.emphasized('done')}.');
  logger.flush();
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/dart-lang/tools/issues
