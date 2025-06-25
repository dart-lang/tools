## 0.6.0

- Test classes and suites with `name`s are now registered with `package:test`s
  `group()` function to produce a hierarchy of groups/tests rather than a flat
  set of tests with concatenated names. This may improve the display of tests
  in IDEs test explorers.

## 0.5.0

- Unawaited asynchronous exceptions in tests marked with `@FailingTest()` are
  now handled correctly and will allow the test to pass.
- Tests marked with `@FailingTest()` but passing no longer run until the
  timeout.

## 0.4.0

- Add support for one-time set up and teardown in test classes via static
  `setUpClass` and `tearDownClass` methods

## 0.3.0

- Require Dart `^3.5.0`.
- Update to `package:test` 1.26.1.
- Pass locations of groups/tests to `package:test` to improve locations reported
  in the JSON reporter that may be used for navigation in IDEs.

## 0.2.3

- Require Dart `^3.1.0`.
- Move to `dart-lang/tools` monorepo.

## 0.2.2

- Update to package:lints 2.0.0 and move it to a dev dependency.

## 0.2.1

- Use package:lints for analysis.
- Populate the pubspec `repository` field.

## 0.2.0

- Stable null safety release.

## 0.2.0-nullsafety.0

- Migrate to the null safety language feature.

## 0.1.9

- Add `@SkippedTest` annotation and `skip_test` prefix.

## 0.1.8

- Update `FailingTest` to add named parameters `issue` and `reason`.

## 0.1.7

- Update documentation comments.
- Remove `@MirrorsUsed` annotation on `dart:mirrors`.

## 0.1.6

- Make `FailingTest` public, with the URI of the issue that causes
  the test to break.

## 0.1.5

- Set max SDK version to `<3.0.0`, and adjust other dependencies.

## 0.1.3

- Fix `@failingTest` to fail when the test passes.

## 0.1.2

- Update the pubspec `dependencies` section to include `package:test`

## 0.1.1

- For `@failingTest` tests, properly handle when the test fails by throwing an
  exception in a timer task
- Analyze this package in strong mode

## 0.1.0

- Switched from 'package:unittest' to 'package:test'.
- Since 'package:test' does not define 'solo_test', in order to keep this
  functionality, `defineReflectiveSuite` must be used to wrap all
  `defineReflectiveTests` invocations.

## 0.0.4

- Added @failingTest, @assertFailingTest and @soloTest annotations.

## 0.0.1

- Initial version
