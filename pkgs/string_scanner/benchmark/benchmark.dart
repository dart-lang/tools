// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:string_scanner/string_scanner.dart';

final _string = 'This is a test string with some typical content.\n' * 50000;
final _word = RegExp(r'\w+');
final _space = RegExp(r'\s+');

class StringScannerReadCharBenchmark extends BenchmarkBase {
  StringScannerReadCharBenchmark() : super('StringScanner readChar');

  @override
  void run() {
    final scanner = StringScanner(_string);
    while (!scanner.isDone) {
      scanner.readChar();
    }
  }
}

class LineScannerReadCharBenchmark extends BenchmarkBase {
  LineScannerReadCharBenchmark() : super('LineScanner readChar');

  @override
  void run() {
    final scanner = LineScanner(_string);
    while (!scanner.isDone) {
      scanner.readChar();
    }
  }
}

class SpanScannerReadCharBenchmark extends BenchmarkBase {
  SpanScannerReadCharBenchmark() : super('SpanScanner readChar');

  @override
  void run() {
    final scanner = SpanScanner(_string);
    while (!scanner.isDone) {
      scanner.readChar();
    }
  }
}

class StringScannerScanBenchmark extends BenchmarkBase {
  StringScannerScanBenchmark() : super('StringScanner scan');

  @override
  void run() {
    final scanner = StringScanner(_string);
    while (!scanner.isDone) {
      if (!scanner.scan(_word) &&
          !scanner.scanChar(10) &&
          !scanner.scan(_space)) {
        scanner.readChar();
      }
    }
  }
}

class LineScannerScanBenchmark extends BenchmarkBase {
  LineScannerScanBenchmark() : super('LineScanner scan');

  @override
  void run() {
    final scanner = LineScanner(_string);
    while (!scanner.isDone) {
      if (!scanner.scan(_word) &&
          !scanner.scanChar(10) &&
          !scanner.scan(_space)) {
        scanner.readChar();
      }
    }
  }
}

class SpanScannerScanBenchmark extends BenchmarkBase {
  SpanScannerScanBenchmark() : super('SpanScanner scan');

  @override
  void run() {
    final scanner = SpanScanner(_string);
    while (!scanner.isDone) {
      if (!scanner.scan(_word) &&
          !scanner.scanChar(10) &&
          !scanner.scan(_space)) {
        scanner.readChar();
      }
    }
  }
}

void main() {
  print('String length: ${_string.length}');
  StringScannerReadCharBenchmark().report();
  LineScannerReadCharBenchmark().report();
  SpanScannerReadCharBenchmark().report();
  StringScannerScanBenchmark().report();
  LineScannerScanBenchmark().report();
  SpanScannerScanBenchmark().report();
}
