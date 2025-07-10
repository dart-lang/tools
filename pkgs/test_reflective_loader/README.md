[![Build Status](https://github.com/dart-lang/tools/actions/workflows/test_reflective_loader.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/test_reflective_loader.yaml)
[![pub package](https://img.shields.io/pub/v/test_reflective_loader.svg)](https://pub.dev/packages/test_reflective_loader)
[![package publisher](https://img.shields.io/pub/publisher/test_reflective_loader.svg)](https://pub.dev/packages/test_reflective_loader/publisher)

Support for discovering and running tests and test suites using reflection.

This package follows an xUnit style where each class can be a test suite.
Test methods within the class are discovered reflectively based on their names or annotations.

## Usage

A test file will typically have a `main` function that kicks off the test loader, and one or more classes annotated with
`@reflectiveTest`.

Here is a simple example:

```dart
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MyTestClass);
  });
}

@reflectiveTest
class MyTestClass {
  void test_simpleSuccess() {
    expect(true, isTrue);
  }

  @failingTest
  void test_expectedToFail() {
    expect(false, isTrue);
  }

  @skippedTest
  void test_skipped() {
    // This test won't be run.
  }

  void setUp() {
    // setUp is called before each test.
    print('setting up');
  }

  void tearDown() {
    // tearDown is called after each test.
    print('tearing down');
  }
}
```

To run the tests, you would execute your test file with `dart test`.

### Test Discovery

The `defineReflectiveSuite` and `defineReflectiveTests` functions are used to discover and define tests.

* `defineReflectiveSuite`: This function creates a test suite. It takes a closure as an argument, and within that
  closure, you can define tests and other nested suites. This allows you to group related tests together.

* `defineReflectiveTests`: This function tells the test runner to look for tests in a given class. The class must be
  annotated with `@reflectiveTest`. The test runner will then reflectively look for methods in that class that are
  considered tests (see below).

### Test Suites

Test suites are classes annotated with `@reflectiveTest`. The loader will instantiate this class for each test method,
so tests are isolated from each other.

### Test Methods

The loader discovers tests in a few ways:

* Methods whose names start with `test_` are treated as tests.
* Methods whose names start with `fail_` are treated as tests that are expected to fail.
* Methods whose names start with `skip_` are skipped.

### Annotations

* `@failingTest`: Marks a test that is expected to fail. This is useful for tests that demonstrate a bug that has not
  yet been fixed.
* `@skippedTest`: Marks a test that should be skipped and not run.
* `@soloTest`: Can be applied to a test class or a test method to indicate that only this test (or the tests in this
  class) should be run. If multiple tests/classes have this annotation, they will all run.

### `setUp` and `tearDown`

If a test class defines a `setUp()` method, it will be run before each test method in that class. If it defines a
`tearDown()` method, it will be run after each test method, even if the test fails. These are useful for setting up and
cleaning up test fixtures. Both `setUp()` and `tearDown()` can be `async` and return a `Future`.

### Asynchronous Tests

If a test method, `setUp()`, or `tearDown()` returns a `Future`, the test runner will wait for the future to complete.
The `tearDown` method (if any) will be executed after the test method and its `Future` completes.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Atest_reflective_loader
