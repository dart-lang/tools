// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:io/io.dart' hide sharedStdIn;
import 'package:test/test.dart';

void main() {
  // ignore: close_sinks
  late StreamController<String> fakeStdIn;
  late SharedStdIn sharedStdIn;

  setUp(() {
    fakeStdIn = StreamController<String>(sync: true);
    sharedStdIn = SharedStdIn(fakeStdIn.stream.map((s) => s.codeUnits));
  });

  test('should allow a single subscriber', () async {
    final logs = <String>[];
    final sub = sharedStdIn.transform(utf8.decoder).listen(logs.add);
    fakeStdIn.add('Hello World');
    await sub.cancel();
    expect(logs, ['Hello World']);
  });

  test('should allow multiple subscribers', () async {
    final logs = <String>[];
    final asUtf8 = sharedStdIn.transform(utf8.decoder);
    var sub = asUtf8.listen(logs.add);
    fakeStdIn.add('Hello World');
    await sub.cancel();
    sub = asUtf8.listen(logs.add);
    fakeStdIn.add('Goodbye World');
    await sub.cancel();
    expect(logs, ['Hello World', 'Goodbye World']);
  });

  test('should throw if a subscriber is still active', () async {
    final active = sharedStdIn.listen((_) {});
    expect(() => sharedStdIn.listen((_) {}), throwsStateError);
    await active.cancel();
    expect(() => sharedStdIn.listen((_) {}), returnsNormally);
  });

  test('should return a stream of lines', () async {
    expect(
      sharedStdIn.lines(),
      emitsInOrder(<dynamic>[
        'I',
        'Think',
        'Therefore',
        'I',
        'Am',
      ]),
    );
    [
      'I\nThink\n',
      'Therefore\n',
      'I\n',
      'Am\n',
    ].forEach(fakeStdIn.add);
  });

  test('should return the next line', () {
    expect(sharedStdIn.nextLine(), completion('Hello World'));
    fakeStdIn.add('Hello World\n');
  });

  test('should allow listening for new lines multiple times', () async {
    expect(sharedStdIn.nextLine(), completion('Hello World'));
    fakeStdIn.add('Hello World\n');
    await Future<void>.value();

    expect(sharedStdIn.nextLine(), completion('Hello World'));
    fakeStdIn.add('Hello World\n');
  });

  test('should temporarily divert events', () async {
    final logs = <List<int>>[];
    final sub = sharedStdIn.listen(logs.add);
    fakeStdIn.add('a');
    await pumpEventQueue(times: 0);
    expect(logs, ['a'.codeUnits]);

    final diverted = sub.divert();
    fakeStdIn.add('b');
    await pumpEventQueue(times: 0);
    expect(logs, ['a'.codeUnits]);

    final divertedLogs = <List<int>>[];
    final divertedSub = diverted.listen(divertedLogs.add);
    await pumpEventQueue(times: 0);
    expect(divertedLogs, ['b'.codeUnits]);

    fakeStdIn.add('c');
    await pumpEventQueue(times: 0);
    expect(divertedLogs, ['b'.codeUnits, 'c'.codeUnits]);
    expect(logs, ['a'.codeUnits]);

    final cancelDone = divertedSub.cancel();
    fakeStdIn.add('d');
    await cancelDone;
    fakeStdIn.add('e');
    await pumpEventQueue(times: 0);
    expect(logs, ['a'.codeUnits, 'd'.codeUnits, 'e'.codeUnits]);

    await sub.cancel();
  });

  test('should allow changing onData while diverted', () async {
    final logs = <List<int>>[];
    final sub = sharedStdIn.listen(logs.add);
    final diverted = sub.divert();

    final newLogs = <List<int>>[];
    sub.onData(newLogs.add);

    final divertedLogs = <List<int>>[];
    final divertedSub = diverted.listen(divertedLogs.add);

    fakeStdIn.add('a');
    await pumpEventQueue(times: 0);
    expect(divertedLogs, ['a'.codeUnits]);
    expect(logs, isEmpty);
    expect(newLogs, isEmpty);

    await divertedSub.cancel();
    fakeStdIn.add('b');
    await pumpEventQueue(times: 0);
    expect(divertedLogs, ['a'.codeUnits]);
    expect(logs, isEmpty);
    expect(newLogs, ['b'.codeUnits]);

    await sub.cancel();
  });

  test('should allow changing onDone while diverted', () async {
    var doneCalled = false;
    final sub = sharedStdIn.listen((_) {}, onDone: () {
      doneCalled = true;
    });
    final diverted = sub.divert();

    var newDoneCalled = false;
    sub.onDone(() {
      newDoneCalled = true;
    });

    final divertedSub = diverted.listen((_) {});

    await divertedSub.cancel();

    await sharedStdIn.terminate();
    await pumpEventQueue(times: 0);

    expect(doneCalled, isFalse);
    expect(newDoneCalled, isTrue);
    await sub.cancel();
  });

  test('should call both onDone if stream closes while diverted', () async {
    var doneCalled = false;
    final sub = sharedStdIn.listen((_) {}, onDone: () {
      doneCalled = true;
    });
    final diverted = sub.divert();

    var divertedDoneCalled = false;
    final divertedSub = diverted.listen((_) {}, onDone: () {
      divertedDoneCalled = true;
    });

    await sharedStdIn.terminate();
    await pumpEventQueue(times: 0);

    expect(doneCalled, isTrue);
    expect(divertedDoneCalled, isTrue);
    await divertedSub.cancel();
    await sub.cancel();
  });

  test('should handle pausing and resuming while diverted', () async {
    final sub = sharedStdIn.listen((_) {});
    final diverted = sub.divert();
    final divertedSub = diverted.listen((_) {});

    expect(sub.isPaused, isFalse);

    divertedSub.pause();
    expect(sub.isPaused, isTrue);

    divertedSub.resume();
    expect(sub.isPaused, isFalse);

    await divertedSub.cancel();
    await sub.cancel();
  });
}
