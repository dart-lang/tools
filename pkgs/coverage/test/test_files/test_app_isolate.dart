import 'dart:isolate';

void isolateTask(List things) {
  SendPort port = things.first;

  var sum = things.skip(1).reduce((a, b) => a + b);

  port.send(sum);
}
