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
