Tools for creating a persistent worker loop for [bazel](http://bazel.io/).

## Usage

There are two abstract classes provided by this package, `AsyncWorkerLoop` and
`SyncWorkerLoop`. These each have a `performRequest` method which you must
implement.

Lets look at a simple example of a `SyncWorkerLoop` implementation:

```dart
import 'dart:io';
import 'package:bazel_worker/bazel_worker.dart';

void main() {
  // Blocks until it gets an EOF from stdin.
  new SyncSimpleWorker().run();
}

class SyncSimpleWorker extends SyncWorkerLoop {
  /// Must synchronously return a [WorkResponse], since this is a
  /// [SyncWorkerLoop].
  WorkResponse performRequest(WorkRequest request) {
    new File('hello.txt').writeAsStringSync('hello world!');
    return new WorkResponse()..exitCode = EXIT_CODE_OK;
  }
}
```

And now the same thing, implemented as an `AsyncWorkerLoop`:

```dart
import 'dart:io';
import 'package:bazel_worker/bazel_worker.dart';

void main() {
  // Doesn't block, runs tasks async as they are received on stdin.
  new AsyncSimpleWorker().run();
}

class AsyncSimpleWorker extends AsyncWorkerLoop {
  /// Must return a [Future<WorkResponse>], since this is an
  /// [AsyncWorkerLoop].
  Future<WorkResponse> performRequest(WorkRequest request) async {
    await new File('hello.txt').writeAsString('hello world!');
    return new WorkResponse()..exitCode = EXIT_CODE_OK;
  }
}
```

As you can see, these are nearly identical, it mostly comes down to the
constraints on your package and personal preference which one you choose to
implement.

## Testing

A `package:bazel_worker/testing.dart` file is also provided, which can greatly
assist with writing unit tests for your worker. See the
`test/worker_loop_test.dart` test included in this package for an example of how
the helpers can be used.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/dart-lang/bazel_worker/issues
