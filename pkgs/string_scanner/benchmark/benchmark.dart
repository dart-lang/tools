import 'package:string_scanner/string_scanner.dart';

void main() {
  final string = 'This is a test string with some typical content.\n' * 50000;

  print('String length: ${string.length}');

  void runBenchmark(String name, void Function() fn) {
    // Warmup
    for (var i = 0; i < 5; i++) {
      fn();
    }

    // Measure
    final watch = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      fn();
    }
    watch.stop();
    print('$name: ${watch.elapsedMilliseconds / 10} ms/iter');
  }

  runBenchmark('StringScanner readChar', () {
    final scanner = StringScanner(string);
    while (!scanner.isDone) {
      scanner.readChar();
    }
  });

  runBenchmark('LineScanner readChar', () {
    final scanner = LineScanner(string);
    while (!scanner.isDone) {
      scanner.readChar();
    }
  });

  runBenchmark('SpanScanner readChar', () {
    final scanner = SpanScanner(string);
    while (!scanner.isDone) {
      scanner.readChar();
    }
  });

  final word = RegExp(r'\w+');
  final space = RegExp(r'\s+');

  runBenchmark('StringScanner scan', () {
    final scanner = StringScanner(string);
    while (!scanner.isDone) {
      if (!scanner.scan(word)) {
        scanner.scanChar(10); // \n
        scanner.scan(space);
      }
    }
  });

  runBenchmark('LineScanner scan', () {
    final scanner = LineScanner(string);
    while (!scanner.isDone) {
      if (!scanner.scan(word)) {
        scanner.scanChar(10);
        scanner.scan(space);
      }
    }
  });

  runBenchmark('SpanScanner scan', () {
    final scanner = SpanScanner(string);
    while (!scanner.isDone) {
      if (!scanner.scan(word)) {
        scanner.scanChar(10);
        scanner.scan(space);
      }
    }
  });
}
