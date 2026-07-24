[![Build Status](https://github.com/dart-lang/tools/actions/workflows/api_summary.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/api_summary.yaml)
[![pub package](https://img.shields.io/pub/v/api_summary.svg)](https://pub.dev/packages/api_summary)
[![package publisher](https://img.shields.io/pub/publisher/api_summary.svg)](https://pub.dev/packages/api_summary/publisher)

A library and command-line tool to create a human-readable text summary of the
public API of a Dart package. This is highly suitable for tracking the public
API footprints and ensuring that API modifications are visible during code
reviews (e.g. using `diff` tests).

> [!NOTE]
> For robust breaking change tracking, you should use
> [dart_apitool](https://pub.dev/packages/dart_apitool).

## Command Line Usage

You can use the command-line tool to generate an API summary for any package
containing a `pubspec.yaml` file.

### Installing Globally

Activate the package using `dart pub global`:

```bash
dart pub global activate api_summary
```

Then run the tool:

```bash
api_summary --package-path /path/to/your/package
```

Or, to run against the package in the current working directory, just run:

```bash
api_summary
```

### Running via `dart run`

Alternatively, you can run the executable from within a package directory if
`api_summary` is a dependency:

```bash
dart run api_summary
```

### Options

* `-p, --package-path`: The path to the package directory to summarize
  (defaults to the current working directory).
* `-f, --format`: The output format for the summary (`text`, `json`, or
  `yaml`). Defaults to `text`.
* `-h, --help`: Prints usage instructions.

## Programmatic Usage

You can also use this package programmatically inside your Dart projects, such
as in automated testing or continuous integration scripts.

Add `api_summary` to your `pubspec.yaml`:

```yaml
dependencies:
  api_summary: ^0.1.0-wip
```

### Basic Example

Call the `apiSummary` function to generate a package's public API
representation:

```dart
import 'dart:io';
import 'package:api_summary/api_summary.dart';

void main() async {
  final summary = await apiSummary('/path/to/package');
  print(summary);
}
```

An executable programmatic example is also available in the
[example/example.dart](example/example.dart) file.

### Customizing the Summary

Extend the `ApiSummaryCustomizer` class to customize what is displayed in the
API summary. For example, to exclude specific public classes or only display
details of certain elements:

```dart
import 'package:api_summary/api_summary.dart';
import 'package:analyzer/dart/element/element.dart';

base class MyCustomizer extends ApiSummaryCustomizer {
  @override
  bool shouldShowDetails(Element element, ApiSummaryContext context) {
    // Exclude elements named 'InternalHelper' from details printout
    if (element.name == 'InternalHelper') {
      return false;
    }
    return super.shouldShowDetails(element, context);
  }
}

void main() async {
  final summary = await apiSummary(
    '/path/to/package',
    customizer: MyCustomizer(),
  );
  print(summary);
}
```

You can also override `includeReferencedTypes` to transitively include skeleton declarations (containing type hierarchy but no members) of classes, enums, or mixins from other packages and the SDK that are referenced in your public API:

```dart
import 'package:api_summary/api_summary.dart';

base class MyCustomizer extends ApiSummaryCustomizer {
  @override
  bool get includeReferencedTypes => true;
}
```


## Golden File / Diff Testing

A common best practice with `api_summary` is to verify in a unit test that the
generated summary matches a checked-in golden file (e.g. `api.txt`). If a
developer introduces an accidental breaking change or adds a new public API
element, the test will fail on the `diff`, prompting them to audit and
intentionally update the golden file.

Below is an example of such a test (available in the
[test/app_test.dart](test/app_test.dart) file):

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:api_summary/api_summary.dart';

void main() {
  test('public API has not changed unexpectedly', () async {
    final packageDir = Directory.current.path;
    final goldenFile = File(p.join(packageDir, 'api.txt'));

    final actualOutput = await apiSummary(packageDir);

    if (!goldenFile.existsSync()) {
      // In a new setup or after updates, generate the golden file first
      goldenFile.writeAsStringSync(actualOutput.toString());
      fail('Golden file api.txt did not exist and has been generated. Please review and commit it.');
    }

    final expectedOutput = goldenFile.readAsStringSync();
    expect(actualOutput.toString(), equals(expectedOutput));
  });
}
```

## Status: experimental

**NOTE**: This package is currently experimental and published under the
[tools.dart.dev](https://dart.dev/dart-team-packages) pub publisher in order to
solicit feedback.

These packages have a much higher expected rate of API and breaking changes.

Your feedback is valuable and will help us evolve this package. For general
feedback, suggestions, and comments, please file an issue in the
[bug tracker](https://github.com/dart-lang/tools/issues).
