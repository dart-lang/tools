## 1.4.0

* Add `forEach` to `Pool` to support efficient async processing of an
  `Iterable`.

* Throw ArgumentError if poolSize <= 0

## 1.3.6

* Set max SDK version to `<3.0.0`, and adjust other dependencies.

## 1.3.5

- Updated SDK version to 2.0.0-dev.17.0

## 1.3.4

* Modify code to eliminate Future flattening.

## 1.3.3

* Declare support for `async` 2.0.0.

## 1.3.2

* Update to make the code work with strong-mode clean Zone API.

* Required minimum SDK of 1.23.0.

## 1.3.1

* Fix the type annotation of `Pool.withResource()` to indicate that it takes
  `() -> FutureOr<T>`.

## 1.3.0

* Add a `Pool.done` getter that returns the same future returned by
  `Pool.close()`.

## 1.2.4

* Fix a strong-mode error.

## 1.2.3

* Fix a bug in which `Pool.withResource()` could throw a `StateError` when
  called immediately before closing the pool.

## 1.2.2

* Fix strong mode warnings and add generic method annotations.

## 1.2.1

* Internal changes only.

## 1.2.0

* Add `Pool.close()`, which forbids new resource requests and releases all
  releasable resources.

## 1.1.0

* Add `PoolResource.allowRelease()`, which allows a resource to indicate that it
  can be released without forcing it to deallocate immediately.

## 1.0.2

* Fixed the homepage.

## 1.0.1

* A `TimeoutException` is now correctly thrown if the pool detects a deadlock.
