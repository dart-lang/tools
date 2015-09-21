csslib in Pure Dart
===================

This is a CSS parser written entirely in [Dart][dart].
It can be used in the client/server/command line.

This package is installed with [Pub][pub], see:
[install instructions](https://pub.dartlang.org/packages/csslib#installing)
for this package.

Usage
-----

Parsing CSS is easy!
```dart
import 'package:csslib/parser.dart' show parse;
import 'package:csslib/css.dart';

main() {
  var stylesheet = parse(
      '.foo { color: red; left: 20px; top: 20px; width: 100px; height:200px }');
  print(stylesheet.toString());
}
```

You can pass a String or list of bytes to `parse`.


Running Tests
-------------

All tests (both canary and suite) should be passing.  Canary are quick test
verifies that basic CSS is working.  The suite tests are a comprehensive set of
~11,000 tests.

```bash
export DART_SDK=path/to/dart/sdk

# Make sure dependencies are installed
pub install

# Run command both canary and the suite tests
test/run.sh
```

  Run only the canary test:

```bash
 test/run.sh canary
```

  Run only the suite tests:

```bash
 test/run.sh suite
```

[dart]: http://www.dartlang.org/
[pub]: http://www.dartlang.org/docs/pub-package-manager/
