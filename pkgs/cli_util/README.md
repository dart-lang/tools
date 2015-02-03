# cli_util

Utilities to help in building Dart command-line apps.

In particular, ``cli_util`` provides a simple, standardized way to get the current SDK directory.  Useful, especially, when building client applications that interact with the Dart SDK (such as the [analyzer](https://pub.dartlang.org/packages/analyzer)).

## Install

```shell
pub global activate cli_util
```

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

[tracker]: https://github.com/dart-lang/cli_util/issues
