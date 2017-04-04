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
