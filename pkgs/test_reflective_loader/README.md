# test_reflective_loader

[![Build Status](https://github.com/dart-lang/test_reflective_loader/workflows/Dart/badge.svg)](https://github.com/dart-lang/test_reflective_loader/actions)

Support for discovering tests and test suites using reflection.

This package follows the xUnit style where each class is a test suite, and each
method with the name prefix `test_` is a single test.

Methods with names starting with `test_` are run using the `test()` function with
the corresponding name. If the class defines methods `setUp()` or `tearDown()`,
they are executed before / after each test correspondingly, even if the test fails.

Methods with names starting with `solo_test_` are run using the `solo_test()` function.

Methods with names starting with `fail_` are expected to fail.

Methods with names starting with `solo_fail_` are run using the `solo_test()` function
and expected to fail.

Method returning `Future` class instances are asynchronous, so `tearDown()` is
executed after the returned `Future` completes.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/dart-lang/test_reflective_loader/issues
