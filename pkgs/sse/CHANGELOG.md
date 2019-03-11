## 2.0.0

- No longer expose `close` and `onClose` on an `SseConnection`. This is simply
  handled by the underlying `stream` / `sink`.
- Fix a bug where resources of the `SseConnection` were not properly closed.

## 1.0.0

- Internal cleanup.


## 0.0.1

- Initial commit.
