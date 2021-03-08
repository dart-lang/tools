import 'dart:math';
import 'dart:typed_data';

import 'package:bazel_worker/bazel_worker.dart';
import 'package:bazel_worker/src/async_message_grouper.dart';

/// Benchmark for `AsyncMessageGrouper`.
Future<void> main() async {
  // Create a large work request with 10,000 inputs.
  var workRequest = WorkRequest();
  for (var i = 0; i != 10000; ++i) {
    var path = 'blaze-bin/some/path/to/a/file/that/is/an/input/$i';
    workRequest
      ..arguments.add('--input=$path')
      ..inputs.add(Input()
        ..path = ''
        ..digest.addAll(List.filled(70, 0x11)));
  }

  // Serialize it.
  var requestBytes = workRequest.writeToBuffer();
  var length = requestBytes.length;
  print('Request has $length requestBytes.');

  // Add the length in front base 128 encoded as in the worker protocol.
  requestBytes =
      Uint8List.fromList(requestBytes.toList()..insertAll(0, _varInt(length)));

  // Split into 10000 byte chunks.
  var lists = <Uint8List>[];
  for (var i = 0; i < requestBytes.length; i += 10000) {
    lists.add(Uint8List.sublistView(
        requestBytes, i, min(i + 10000, requestBytes.length)));
  }

  // Time `AsyncMessageGrouper` and deserialization.
  for (var i = 0; i != 30; ++i) {
    var stopwatch = Stopwatch()..start();
    var asyncGrouper = AsyncMessageGrouper(Stream.fromIterable(lists));
    var message = (await asyncGrouper.next)!;
    print('Grouped in ${stopwatch.elapsedMilliseconds}ms');
    stopwatch.reset();
    WorkRequest.fromBuffer(message);
    print('Deserialized in ${stopwatch.elapsedMilliseconds}ms');
  }
}

Uint8List _varInt(int value) {
  var result = <int>[];
  while (value >= 0x80) {
    result.add(0x80 | (value & 0x7f));
    value >>= 7;
  }
  result.add(value);
  return Uint8List.fromList(result);
}
