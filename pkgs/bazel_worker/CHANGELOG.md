## 1.0.0-nullsafety.0

* Migrate to null safety.
* Use `WorkResponse` with `exitCode` set to `EXIT_CODE_BROKEN_PIPE` instead of
  `null` responses.

## 0.1.25+1-dev

* Regenerate proto code and fix some new analysis hints.

## 0.1.25

* Add `isBroadcast` implementation to `TestStdin` classes.

## 0.1.24

* Check for closed port when trying to read a response in
  `IsolateDriverConnection` and return `null` if there is nothing to be read.

## 0.1.23+1

* Don't rely on `exitCode` to know when a worker terminates, instead wait for
  the input stream to close.
  * The SDK may also start throwing instead of returning a `null` here, so this
    pre-emptively guards against that.

## 0.1.23

* Support protobuf `1.x`.
* Added a tool for updating generated proto files and updated them
  using the latest version of the protoc_plugin package.
  * This required a lower bound bump of the `protobuf` package to `0.14.4`.

## 0.1.22

* Require protobuf 0.14.0.

## 0.1.21+1

* Don't rely on `exitCode` to know when a worker terminates, instead wait for
  the input stream to close. Backport of fix in `0.1.23+1` in a version that
  does not require a newer protobuf.

## 0.1.21

* Make `TestStdinAsync` behave like a `Stream<Uint8List>`

## 0.1.20

* Close worker `outputStream` on `cancel`.

## 0.1.19

* Work around https://github.com/dart-lang/sdk/issues/35874.

## 0.1.18

* Add a `trackWork` optional named argument to `BazelDriver.doWork`. This allows
  the caller to know when a work request is actually sent to a worker.

## 0.1.17

* Allow protobuf 0.13.0.

## 0.1.16

* Update the worker_protocol.pb.dart file with the latest proto generator.
* Require protobuf 0.11.0.

## 0.1.15

* Update the worker_protocol.pb.dart file with the latest proto generator.
* Require protobuf 0.10.4.

## 0.1.14

* Allow workers to support running in isolates. To support running in isolates,
  workers must modify their `main` method to accept a `SendPort` then use it
  when creating the `AsyncWorkerConnection`. See `async_worker` in `e2e_test`.

## 0.1.13

* Support protobuf 0.10.0.

## 0.1.12

* Set max SDK version to `<3.0.0`.

## 0.1.11

* Added support for protobuf 0.9.0.

## 0.1.10

* Update the SDK dependency to 2.0.0-dev.17.0.
* Update to protobuf version 0.8.0
* Remove usages of deprecated upper-case constants from the SDK.

## 0.1.9

* Update the worker_protocol.pb.dart file with the latest proto generator.

## 0.1.8

* Add `Future cancel()` method to `DriverConnection`, which in the case of a
  `StdDriverConnection` closes the input stream.
  * The `terminateWorkers` method on `BazelWorkerDriver` now calls `cancel` on
    all worker connections to ensure the vm can exit correctly.

## 0.1.7

* Update the `BazelWorkerDriver` class to handle worker crashes, and retry work
  requests. The number of retries is configurable with the new `int maxRetries`
  optional arg to the `BazelWorkerDriver` constructor.

## 0.1.6

* Update the worker_protocol.pb.dart file with the latest proto generator.
* Add support for package:async 2.x and package:protobuf 6.x.

## 0.1.5

* Change TestStdinAsync.controller to StreamController<List<int>> (instead of
  using dynamic as the type argument).

## 0.1.4

* Added `BazelWorkerDriver` class, which can be used to implement the bazel side
  of the protocol. This allows you to speak to any process which knows the bazel
  protocol from your own process.
* Changed `WorkerConnection#readRequest` to return a `FutureOr<WorkRequest>`
  instead of dynamic.

## 0.1.3

* Add automatic intercepting of print calls and append them to
  `response.output`. This makes more libraries work out of the box, as printing
  would previously cause an error due to communication over stdin/stdout.
  * Note that using stdin/stdout directly will still cause an error, but that is
    less common.

## 0.1.2

* Add better handling for the case where stdin gives an error instead of an EOF.

## 0.1.1

* Export `AsyncMessageGrouper` and `SyncMessageGrouper` as part of the testing
  library. These can assist when writing e2e tests and communicating with a
  worker process.

## 0.1.0

* Initial version.
