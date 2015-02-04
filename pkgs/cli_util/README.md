# cli_util

A library to help in building Dart command-line apps.

In particular, `cli_util` provides a simple, standardized way to get the current
SDK directory.  Useful, especially, when building client applications that
interact with the Dart SDK (such as the [analyzer][analyzer]).

[![Build Status](https://travis-ci.org/dart-lang/cli_util.svg)](https://travis-ci.org/dart-lang/cli_util)

## Usage

```dart
import 'dart:io';

import 'package:cli_util/cli_util.dart';
import 'package:path/path.dart' as path;

main(args) {
  // Get sdk dir from cli_util
  Directory sdkDir = getSdkDir(args);
  
  // Do stuff... For example, print version string
  File versionFile = new File(path.join(sdkDir.path, 'version'));
  print(versionFile.readAsStringSync());
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[analyzer]: https://pub.dartlang.org/packages/analyzer
[tracker]: https://github.com/dart-lang/cli_util/issues
