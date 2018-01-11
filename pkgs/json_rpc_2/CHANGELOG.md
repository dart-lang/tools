## 2.0.6

* Internal changes only.

## 2.0.5

* Internal changes only.

## 2.0.4

* `Client.sendRequest()` now throws a `StateError` if the client is closed while
  the request is in-flight. This avoids dangling `Future`s that will never be
  completed.

* Both `Client.sendRequest()` and `Client.sendNotification()` now throw
  `StateError`s if they're called after the client is closed.

## 2.0.3

* Fix new strong-mode warnings.

## 2.0.2

* Fix all strong-mode warnings.

## 2.0.1

* Fix a race condition in which a `StateError` could be top-leveled if
  `Peer.close()` was called before the underlying channel closed.

## 2.0.0

* **Breaking change:** all constructors now take a `StreamChannel` rather than a
  `Stream`/`StreamSink` pair.

* `Client.sendRequest()` and `Client.sendNotification()` no longer throw
  `StateError`s after the connection has been closed but before `Client.close()`
  has been called.

* The various `close()` methods may now be called before their corresponding
  `listen()` methods.

* The various `close()` methods now wait on the result of closing the underlying
  `StreamSink`. Be aware that [in some circumstances][issue 19095]
  `StreamController`s' `Sink.close()` futures may never complete.

[issue 19095]: https://github.com/dart-lang/sdk/issues/19095

## 1.2.0

* Add `Client.isClosed` and `Server.isClosed`, which make it possible to
  synchronously determine whether the connection is open. In particular, this
  makes it possible to reliably tell whether it's safe to call
  `Client.sendRequest`.

* Fix a race condition in `Server` where a `StateError` could be thrown if the
  connection was closed in the middle of handling a request.

* Improve stack traces for error responses.

## 1.1.1

* Update the README to match the current API.

## 1.1.0

* Add a `done` getter to `Client`, `Server`, and `Peer`.

## 1.0.0

* Add a `Client` class for communicating with external JSON-RPC 2.0 servers.

* Add a `Peer` class that's both a `Client` and a `Server`.

## 0.1.0

* Remove `Server.handleRequest()` and `Server.parseRequest()`. Instead, `new
  Server()` takes a `Stream` and a `StreamSink` and uses those behind-the-scenes
  for its communication.

* Add `Server.listen()`, which causes the server to begin listening to the
  underlying request stream.

* Add `Server.close()`, which closes the underlying request stream and response
  sink.

## 0.0.2+3

* Widen the version constraint for `stack_trace`.

## 0.0.2+2

* Fix error response to include data from `RpcException` when not a map.
