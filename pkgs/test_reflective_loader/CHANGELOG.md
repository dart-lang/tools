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
