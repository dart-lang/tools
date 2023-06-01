## 2.3.1

- Update package repository after move.

## 2.3.0

- Add a `transitiveClosure` function.
- Make `stronglyConnectedComponents` and `topologicalSort` iterative rather than
  recursive to avoid stack overflows on very large graphs.
- Require Dart 2.18

## 2.2.0

- Add a `secondarySort` parameter to the `topologicalSort()` function which
  applies an additional lexical sort where that doesn't break the topological
  sort.

## 2.1.0

- Add a `topologicalSort()` function.

## 2.0.0

- **Breaking**: `crawlAsync` will no longer ignore a node from the graph if the
  `readNode` callback returns null.

## 1.0.0

- Migrate to null safety.
- **Breaking**: Paths from `shortestPath[s]` are now returned as iterables to
  reduce memory consumption of the algorithm to O(n).

## 0.2.0

- **BREAKING** `shortestPath`, `shortestPaths` and `stronglyConnectedComponents`
  now have one generic parameter and have replaced the `key` parameter with
  optional params: `{bool equals(T key1, T key2), int hashCode(T key)}`.
  This follows the pattern used in `dart:collection` classes `HashMap` and 
  `LinkedHashMap`. It improves the usability and performance of the case where
  the source values are directly usable in a hash data structure.

## 0.1.3+1

- Fixed a bug with non-identity `key` in `shortestPath` and `shortestPaths`.

## 0.1.3

- Added `shortestPath` and `shortestPaths` functions.
- Use `HashMap` and `HashSet` from `dart:collection` for
  `stronglyConnectedComponents`. Improves runtime performance.

## 0.1.2+1

- Allow using non-dev Dart 2 SDK.

## 0.1.2

- `crawlAsync` surfaces exceptions while crawling through the result stream
  rather than as uncaught asynchronous errors.

## 0.1.1

- `crawlAsync` will now ignore nodes that are resolved to `null`.

## 0.1.0

- Initial release with an implementation of `stronglyConnectedComponents` and
  `crawlAsync`.
