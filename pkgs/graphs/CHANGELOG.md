# 0.1.3+1

- Fixed a bug with non-identity `key` in `shortestPath` and `shortestPaths`.

# 0.1.3

- Added `shortestPath` and `shortestPaths` functions.
- Use `HashMap` and `HashSet` from `dart:collection` for 
  `stronglyConnectedComponents`. Improves runtime performance.

# 0.1.2+1

- Allow using non-dev Dart 2 SDK.

# 0.1.2

- `crawlAsync` surfaces exceptions while crawling through the result stream
  rather than as uncaught asynchronous errors.

# 0.1.1

- `crawlAsync` will now ignore nodes that are resolved to `null`.

# 0.1.0

- Initial release with an implementation of `stronglyConnectedComponents` and
  `crawlAsync`.
