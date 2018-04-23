# 0.1.2

- `crawlAsync` surfaces exceptions while crawling through the result stream
  rather than as uncaught asynchronous errors.

# 0.1.1

- `crawlAsync` will now ignore nodes that are resolved to `null`.

# 0.1.0

- Initial release with an implementation of `stronglyConnectedComponents` and
  `crawlAsync`.
