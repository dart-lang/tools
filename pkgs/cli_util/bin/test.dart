import 'dart:async';

var stopped = false;

void main() async {
  final ints = manyInts(10);
  final strings = stringify(ints);
  final done = Completer<void>();
  final listener = strings.listen((value) {
    if (value == "2") {
      done.complete();
      print('cancelled');
      stopped = true;
    }
    print(value);
  });
  await done.future;
  print('canceling listener');
  await listener.cancel();
  print('done');
}

Stream<int> manyInts(int count) async* {
  for (var i = 0; i < count; i++) {
    if (!stopped) {
      yield i;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1000));
  }
}

Stream<String> stringify(Stream<Object?> original) async* {
  await for (final item in original) {
    yield item.toString();
  }
}
