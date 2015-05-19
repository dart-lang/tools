import 'dart:isolate';

/// The number of covered lines is tested and expected to be 4.
///
/// If you modify this method, you may have to update the tests!
void isolateTask(List threeThings) {
  SendPort port = threeThings.first;

  var sum = threeThings[1] + threeThings[2];

  port.send(sum);
}
