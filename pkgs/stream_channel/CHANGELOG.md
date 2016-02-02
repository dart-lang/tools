## 1.1.1

* Fix the type annotation for `StreamChannel.transform()`'s parameter.

## 1.1.0

* Add `StreamChannel.transformStream()`, `StreamChannel.transformSink()`,
  `StreamChannel.changeStream()`, and `StreamChannel.changeSink()` to support
  changing only the stream or only the sink of a channel.

* Be more explicit about `JsonDocumentTransformer`'s error-handling behavior.

## 1.0.1

* Fix `MultiChannel`'s constructor to take a `StreamChannel`. This is
  technically a breaking change, but since 1.0.0 was only released an hour ago,
  we're treating it as a bug fix.

## 1.0.0

* Initial version
