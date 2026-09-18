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

Install the executable using `dart install`:

```bash
dart install api_summary
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
* `-o, --output`: Write the summary to a file path instead of `stdout`.
* `-w, --write`: Write the summary to the default golden file (`api.txt`,
  `api.json`, or `api.yaml`, based on `--format`) in the package directory.
* `-c, --check`: Verify that the golden file (`api.txt`, `api.json`, or
  `api.yaml`) matches the current public API, exiting with code `1` on mismatch.
* `-h, --help`: Prints usage instructions.

## Programmatic Usage

You can also use this package programmatically inside your Dart projects, such
as in automated testing or continuous integration scripts.

Add `api_summary` to your `pubspec.yaml`:

```yaml
dev_dependencies:
  api_summary: ^1.1.0
```

### Basic Example

Call the `apiSummary` function to generate a package's public API
representation:

```dart
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


## Golden File / Diff Testing (`expectApiSummaryClean`)

A recommended practice is to verify in a unit test that your package's public
API matches a checked-in `api.txt` golden file.

First, generate `api.txt` in your package root:

```bash
dart run api_summary --write
```

Then wire up `expectApiSummaryClean` as a one-liner in `test/api_test.dart`:

```dart
import 'package:api_summary/api_summary.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('api_summary', expectApiSummaryClean);
}
```

If a developer introduces a breaking change or adds a new public API element,
`expectApiSummaryClean` fails the test with a compact line diff and instructs
them to run `dart run api_summary --write` to update `api.txt`.
