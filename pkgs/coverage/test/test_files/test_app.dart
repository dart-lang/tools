import 'dart:isolate';

import 'test_app_isolate.dart';

main() async {
  for (var i = 0; i < 10; i++) {
    for (var j = 0; j < 10; j++) {
      var sum = usedMethod(i, j);
      if (sum != (i + j)) {
        throw 'bad method!';
      }
    }
  }

  ReceivePort port = new ReceivePort();

  Isolate isolate =
      await Isolate.spawn(isolateTask, [port.sendPort, 1, 2], paused: true);
  isolate.addOnExitListener(port.sendPort);
  isolate.resume(isolate.pauseCapability);

  var value = await port.first;

  if (value != 3) {
    throw 'expected 3!';
  }
}

int usedMethod(int a, int b) {
  return a + b;
}

int unusedMethod(int a, int b) {
  return a - b;
}
