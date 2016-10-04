# Changelog

## 0.1.0

- Switched from 'package:unittest' to 'package:test'.
- Since 'package:test' does not define 'solo_test', in order to keep
  this functionality, `defineReflectiveSuite` must be used to wrap
  all `defineReflectiveTests` invocations.

## 0.0.4

- Added @failingTest, @assertFailingTest and @soloTest annotations.

## 0.0.1

- Initial version
