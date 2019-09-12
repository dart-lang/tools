## 2.1.1

- Use proper headers delimiter.

## 2.1.0

- Support Firefox.

## 2.0.3

- Fix an issue where messages could come out of order.

## 2.0.2

- Support the latest `package:stream_channel`.
- Require Dart SDK `>=2.1.0 <3.0.0`.

## 2.0.1

- Update to `package:uuid` version 2.0.

## 2.0.0

- No longer expose `close` and `onClose` on an `SseConnection`. This is simply
  handled by the underlying `stream` / `sink`.
- Fix a bug where resources of the `SseConnection` were not properly closed.

## 1.0.0

- Internal cleanup.


## 0.0.1

- Initial commit.
