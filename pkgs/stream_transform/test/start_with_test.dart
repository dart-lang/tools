// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stream_transform/stream_transform.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  late StreamController<int> values;
  late Stream<int> transformed;
  late StreamSubscription<int> subscription;

  late List<int> emittedValues;
  late bool isDone;

  void setupForStreamType(
      String streamType, Stream<int> Function(Stream<int>) transform) {
    emittedValues = [];
    isDone = false;
    values = createController(streamType);
    transformed = transform(values.stream);
    subscription =
        transformed.listen(emittedValues.add, onDone: () => isDone = true);
  }

  for (var streamType in streamTypesWithSync) {
    group('startWith then [$streamType]', () {
      setUp(() => setupForStreamType(streamType, (s) => s.startWith(1)));

      test('outputs all values', () async {
        values
          ..add(2)
          ..add(3);
        await Future(() {});
        expect(emittedValues, [1, 2, 3]);
      });

      test('outputs initial when followed by empty stream', () async {
        await values.close();
        expect(emittedValues, [1]);
      });

      test('closes with values', () async {
        expect(isDone, false);
        await values.close();
        expect(isDone, true);
      });

      if (streamType != 'single subscription') {
        test('can cancel and relisten', () async {
          values.add(2);
          await Future(() {});
          await subscription.cancel();
          subscription = transformed.listen(emittedValues.add);
          values.add(3);
          await Future(() {});
          await Future(() {});
          expect(emittedValues, [1, 2, 3]);
        });
      }
    });

    group('startWithMany then [$streamType]', () {
      setUp(() async {
        setupForStreamType(streamType, (s) => s.startWithMany([1, 2]));
        // Ensure all initial values go through
        await Future(() {});
      });

      test('outputs all values', () async {
        values
          ..add(3)
          ..add(4);
        await Future(() {});
        expect(emittedValues, [1, 2, 3, 4]);
      });

      test('outputs initial when followed by empty stream', () async {
        await values.close();
        expect(emittedValues, [1, 2]);
      });

      test('closes with values', () async {
        expect(isDone, false);
        await values.close();
        expect(isDone, true);
      });

      if (streamType != 'single subscription') {
        test('can cancel and relisten', () async {
          values.add(3);
          await Future(() {});
          await subscription.cancel();
          subscription = transformed.listen(emittedValues.add);
          values.add(4);
          await Future(() {});
          expect(emittedValues, [1, 2, 3, 4]);
        });
      }
    });

    for (var startingStreamType in streamTypes) {
      group('startWithStream [$startingStreamType] then [$streamType]', () {
        late StreamController<int> starting;
        setUp(() async {
          starting = createController(startingStreamType);
          setupForStreamType(
              streamType, (s) => s.startWithStream(starting.stream));
        });

        test('outputs all values', () async {
          starting
            ..add(1)
            ..add(2);
          await starting.close();
          values
            ..add(3)
            ..add(4);
          await Future(() {});
          expect(emittedValues, [1, 2, 3, 4]);
        });

        test('closes with values', () async {
          expect(isDone, false);
          await starting.close();
          expect(isDone, false);
          await values.close();
          expect(isDone, true);
        });

        if (streamType != 'single subscription') {
          test('can cancel and relisten during starting', () async {
            starting.add(1);
            await Future(() {});
            await subscription.cancel();
            subscription = transformed.listen(emittedValues.add);
            starting.add(2);
            await starting.close();
            values
              ..add(3)
              ..add(4);
            await Future(() {});
            expect(emittedValues, [1, 2, 3, 4]);
          });

          test('can cancel and relisten during values', () async {
            starting
              ..add(1)
              ..add(2);
            await starting.close();
            values.add(3);
            await Future(() {});
            await subscription.cancel();
            subscription = transformed.listen(emittedValues.add);
            values.add(4);
            await Future(() {});
            expect(emittedValues, [1, 2, 3, 4]);
          });
        }
      });
    }
  }

  for (var streamType in ['broadcast', 'sync broadcast']) {
    final operators = {
      'startWith': (
        apply: (Stream<int> s) => s.startWith(1),
        initial: [1],
      ),
      'startWithMany': (
        apply: (Stream<int> s) => s.startWithMany([1, 2]),
        initial: [1, 2],
      ),
    };
    for (var MapEntry(key: name, value: operator) in operators.entries) {
      final initial = operator.initial;
      group('$name listens to the source immediately [$streamType]', () {
        late StreamController<int> source;
        late Stream<int> transformed;
        late List<int> emitted;

        setUp(() {
          source = createController(streamType);
          transformed = operator.apply(source.stream);
          emitted = [];
        });

        test('does not drop an event added right after listen', () async {
          transformed.listen(emitted.add);
          source.add(10);
          await Future(() {});
          expect(emitted, [...initial, 10]);
        });

        test('does not drop events on either side of the first microtask',
            () async {
          transformed.listen(emitted.add);
          source.add(10);
          await null;
          source.add(20);
          await Future(() {});
          expect(emitted, [...initial, 10, 20]);
        });

        test(
            'emits initial before an event from an already scheduled microtask',
            () async {
          scheduleMicrotask(() => source.add(20));
          transformed.listen(emitted.add);
          await Future(() {});
          expect(emitted, [...initial, 20]);
        });

        test('keeps an error and done added right after listen behind initial',
            () async {
          final log = <String>[];
          transformed.listen((v) => log.add('$v'),
              onError: (Object e) => log.add('error $e'),
              onDone: () => log.add('done'));
          source.addError('x');
          unawaited(source.close());
          await Future(() {});
          expect(log, [...initial.map((v) => '$v'), 'error x', 'done']);
        });

        test('holds initial and buffered events while paused', () async {
          final subscription = transformed.listen(emitted.add)..pause();
          source.add(10);
          await Future(() {});
          expect(emitted, isEmpty);
          subscription.resume();
          await Future(() {});
          expect(emitted, [...initial, 10]);
        });

        test('cancelling before initial is delivered cancels the source',
            () async {
          final subscription = transformed.listen(emitted.add);
          await subscription.cancel();
          await Future(() {});
          expect(source.hasListener, false);
          expect(emitted, isEmpty);
        });

        test('orders an event added while emitting initial after all of it',
            () async {
          transformed.listen((v) {
            emitted.add(v);
            if (v == initial.first) source.add(10);
          });
          await Future(() {});
          expect(emitted, [...initial, 10]);
        });

        test(
            'keeps order when an event is added while draining buffered events',
            () async {
          transformed.listen((v) {
            emitted.add(v);
            if (v == 10) source.add(20);
          });
          source.add(10);
          await Future(() {});
          expect(emitted, [...initial, 10, 20]);
        });

        test('delivers initial to every listener from the same tick', () async {
          final other = <int>[];
          transformed
            ..listen(emitted.add)
            ..listen(other.add);
          source.add(10);
          await Future(() {});
          expect(emitted, [...initial, 10]);
          expect(other, [...initial, 10]);
        });

        test('does not deliver initial or earlier events to a later listener',
            () async {
          transformed.listen(emitted.add);
          await Future(() {});
          final later = <int>[];
          transformed.listen(later.add);
          source.add(10);
          await Future(() {});
          expect(later, [10]);
          expect(emitted, [...initial, 10]);
        });
      });
    }

    test('startWithMany pulls initial values lazily [$streamType]', () async {
      Iterable<int> naturals() sync* {
        var i = 0;
        while (true) {
          if (i == 100) throw StateError('pulled more values than needed');
          yield ++i;
        }
      }

      final source = createController<int>(streamType);
      expect(await source.stream.startWithMany(naturals()).take(3).toList(),
          [1, 2, 3]);
    });
  }
}
