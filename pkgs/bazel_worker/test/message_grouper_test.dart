// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import 'package:bazel_worker/src/async_message_grouper.dart';
import 'package:bazel_worker/src/sync_message_grouper.dart';
import 'package:bazel_worker/bazel_worker.dart';
import 'package:bazel_worker/testing.dart';

void main() {
  group('AsyncMessageGrouper', () {
    runTests(() => TestStdinAsync(),
        (Stdin stdinStream) => AsyncMessageGrouper(stdinStream));
  });

  group('SyncMessageGrouper', () {
    runTests(() => TestStdinSync(),
        (Stdin stdinStream) => SyncMessageGrouper(stdinStream));
  });
}

void runTests(TestStdin Function() stdinFactory,
    MessageGrouper Function(Stdin) messageGrouperFactory) {
  MessageGrouper messageGrouper;

  TestStdin stdinStream;

  setUp(() {
    stdinStream = stdinFactory();
    messageGrouper = messageGrouperFactory(stdinStream);
  });

  /// Check that if the message grouper produces the [expectedOutput] in
  /// response to the corresponding [input].
  Future check(List<int> input, List<List<int>> expectedOutput) async {
    stdinStream.addInputBytes(input);
    for (var chunk in expectedOutput) {
      expect(await messageGrouper.next, equals(chunk));
    }
  }

  /// Make a simple message having the given [length]
  List<int> makeMessage(int length) {
    var result = <int>[];
    for (var i = 0; i < length; i++) {
      result.add(i & 0xff);
    }
    return result;
  }

  test('Empty message', () async {
    await check([0], [[]]);
  });

  test('Short message', () async {
    await check([
      5,
      10,
      20,
      30,
      40,
      50
    ], [
      [10, 20, 30, 40, 50]
    ]);
  });

  test('Message with 2-byte length', () async {
    var len = 0x155;
    var msg = makeMessage(len);
    var encodedLen = [0xd5, 0x02];
    await check([...encodedLen, ...msg], [msg]);
  });

  test('Message with 3-byte length', () async {
    var len = 0x4103;
    var msg = makeMessage(len);
    var encodedLen = [0x83, 0x82, 0x01];
    await check([...encodedLen, ...msg], [msg]);
  });

  test('Multiple messages', () async {
    await check([
      2,
      10,
      20,
      2,
      30,
      40
    ], [
      [10, 20],
      [30, 40]
    ]);
  });

  test('Empty message at start', () async {
    await check([
      0,
      2,
      10,
      20
    ], [
      [],
      [10, 20]
    ]);
  });

  test('Empty message at end', () async {
    await check([
      2,
      10,
      20,
      0
    ], [
      [10, 20],
      []
    ]);
  });

  test('Empty message in the middle', () async {
    await check([
      2,
      10,
      20,
      0,
      2,
      30,
      40
    ], [
      [10, 20],
      [],
      [30, 40]
    ]);
  });

  test('Handles the case when stdin gives an error instead of EOF', () async {
    if (stdinStream is TestStdinSync) {
      // Reading will now cause an error as pendingBytes is empty.
      (stdinStream as TestStdinSync).pendingBytes.clear();
      expect(messageGrouper.next, isNull);
    } else if (stdinStream is TestStdinAsync) {
      (stdinStream as TestStdinAsync).controller.addError('Error!');
      expect(await messageGrouper.next, isNull);
    }
  });
}
