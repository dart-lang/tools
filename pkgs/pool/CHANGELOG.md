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
