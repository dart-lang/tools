import 'dart:io';
import 'package:bazel_worker/bazel_worker.dart';

void main() {
  // Blocks until it gets an EOF from stdin.
  SyncSimpleWorker().run();
}

class SyncSimpleWorker extends SyncWorkerLoop {
  @override
  WorkResponse performRequest(WorkRequest request) {
    File('hello.txt').writeAsStringSync(request.arguments.first);
    return WorkResponse()..exitCode = EXIT_CODE_OK;
  }
}
