## 1.1.3-wip

* Keep microseconds when using `monthsAgo`, `monthsFromNow` and `yearsAgo`

## 1.1.2

* Require Dart 3.4
* Move to `dart-lang/tools` monorepo.

## 1.1.1

* Switch to using `package:lints`.
* Populate the pubspec `repository` field.

## 1.1.0

* Update SDK constraints to `>=2.12.0 <3.0.0`.
* Update to null safety.

## 1.0.1

* Update to lowercase Dart core library constants.

## 1.0.0

This release contains the `Clock` class that was defined in [`quiver`][]. It's
backwards-compatible with the `quiver` version, and *mostly*
backwards-compatible with the old version of the `clock` package.

[`quiver`]: https://pub.dartlang.org/packages/quiver

### New Features

* A top-level `clock` field has been added that provides a default `Clock`
  implementation. It can be controlled by the `withClock()` function. It should
  generally be used in preference to manual dependency-injection, since it will
  work with the [`fake_async`][] package.

* A `Clock.stopwatch()` method has been added that creates a `Stopwatch` that
  uses the clock as its source of time.

[`fake_async`]: https://pub.dartlang.org/packages/fake_async

### Changes Relative to `clock` 0.1

* The top-level `new` getter and `getStopwatch()` methods are deprecated.
  `clock.new()` and `clock.stopwatch()` should be used instead.

* `Clock.getStopwatch()` is deprecated. `Clock.stopwatch()` should be used instead.

* The `isFinal` argument to `withClock()` is deprecated.

* `new Clock()` now takes an optional positional argument that returns the
  current time as a `DateTime` instead of its old arguments.

* `Clock.now()` is now a method rather than a getter.
