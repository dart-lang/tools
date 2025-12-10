// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';
import 'package:watcher/src/event_batching.dart';
import 'package:watcher/src/testing.dart';

void main() {
  group('batchAndConvertEvents', () {
    setUp(() {
      overridableDateTimeNow = () => clock.now();
    });
    tearDown(() {
      overridableDateTimeNow = DateTime.now;
    });

    group('without buffering', () {
      test('splits into expected batches', () {
        var expectationsRan = false;
        fakeAsync((async) {
          final controller = StreamController<FileSystemEvent>();
          final stream =
              controller.stream.batchNearbyMicrotasksAndConvertEvents();
          final batchesFuture = stream.toList();

          // Send events in ten batches of size 1, 2, 3, ..., 10.
          for (var i = 0; i != 10; ++i) {
            for (var j = 0; j != i + 1; ++j) {
              controller.add(FileSystemCreateEvent('$i,$j', true));
            }
            async.elapse(const Duration(milliseconds: 1));
          }

          controller.close();
          batchesFuture.then((batches) {
            // Check for the exact expected batches.
            for (var i = 0; i != 10; ++i) {
              expect(batches[i].length, i + 1);
              for (var j = 0; j != i + 1; ++j) {
                expect(batches[i][j].path, '$i,$j');
              }
            }
            expectationsRan = true;
          });

          // Cause `batchesFuture` to complete.
          async.flushMicrotasks();
        });

        // Expectations are at the end of a fake async future, check it actually
        // completed.
        expect(expectationsRan, true);
      });
    });

    group('buffered by path', () {
      test('splits into expected batches', () {
        var expecationsRan = false;
        fakeAsync((async) {
          final controller = StreamController<FileSystemEvent>();
          final stream = controller.stream.batchBufferedByPathAndConvertEvents(
              duration: const Duration(milliseconds: 10));
          final batchesFuture = stream.toList();

          controller.add(FileSystemCreateEvent('1', true));
          controller.add(FileSystemCreateEvent('2', true));

          // Don't send "2" again, it should be emitted.
          async.elapse(const Duration(milliseconds: 10));
          controller.add(FileSystemCreateEvent('1', true));
          controller.add(FileSystemCreateEvent('3', true));
          controller.add(FileSystemCreateEvent('4', true));
          controller.add(FileSystemCreateEvent('5', true));

          // Don't send "1", "3" or "4" again, they should be emitted.
          async.elapse(const Duration(milliseconds: 10));
          controller.add(FileSystemCreateEvent('5', true));
          controller.add(FileSystemCreateEvent('6', true));
          controller.add(FileSystemCreateEvent('7', true));
          controller.add(FileSystemCreateEvent('8', true));
          controller.add(FileSystemCreateEvent('9', true));
          controller.add(FileSystemCreateEvent('10', true));

          // Everything except "9" and "10" should be emitted.
          async.elapse(const Duration(milliseconds: 10));
          controller.add(FileSystemCreateEvent('9', true));
          controller.add(FileSystemCreateEvent('10', true));

          // Close of the controller should force emit of "9" with the "10".
          async.elapse(const Duration(milliseconds: 10));
          controller.add(FileSystemCreateEvent('9', true));

          controller.close();
          batchesFuture.then((batches) {
            expect(batches.map((b) => b.map((e) => e.path).toList()).toList(), [
              ['2'],
              ['1', '1', '3', '4'],
              ['5', '5', '6', '7', '8'],
              ['9', '9', '9', '10', '10'],
            ]);
            expecationsRan = true;
          });

          // Cause `batchesFuture` to complete.
          async.flushMicrotasks();
        });

        // Expectations are at the end of a fake async future, check it actually
        // completed.
        expect(expecationsRan, true);
      });

      test('continues batching after pause', () async {
        var expectationsRan = false;

        fakeAsync((async) {
          final controller = StreamController<FileSystemEvent>();
          final stream = controller.stream.batchBufferedByPathAndConvertEvents(
              duration: const Duration(milliseconds: 5));
          final batchesFuture = stream.toList();

          controller.add(FileSystemCreateEvent('1', true));
          async.elapse(const Duration(milliseconds: 2));
          controller.add(FileSystemCreateEvent('1', true));
          async.elapse(const Duration(milliseconds: 10));
          controller.add(FileSystemCreateEvent('2', true));
          async.elapse(const Duration(milliseconds: 2));
          controller.add(FileSystemCreateEvent('2', true));
          async.elapse(const Duration(milliseconds: 10));

          controller.close();
          batchesFuture.then((batches) {
            expect(batches.map((b) => b.map((e) => e.path).toList()).toList(), [
              ['1', '1'],
              ['2', '2'],
            ]);
            expectationsRan = true;
          });

          // Cause `batchesFuture` to complete.
          async.flushMicrotasks();
        });

        // Expectations are at the end of a fake async future, check it actually
        // completed.
        expect(expectationsRan, true);
      });

      test('converts moves into separate create and delete',
          // Move events aren't used on MacOS, so the `Event` conversion rejects
          // them.
          skip: Platform.isMacOS, () {
        var expectationsRan = false;

        fakeAsync((async) {
          final controller = StreamController<FileSystemEvent>();
          final stream = controller.stream.batchBufferedByPathAndConvertEvents(
              duration: const Duration(milliseconds: 50));
          final batchesFuture = stream.toList();

          // Delete of a, delete of b, create of b, create of c should end up in
          // one batch.
          controller.add(FileSystemMoveEvent('a', false, 'b'));
          async.elapse(const Duration(milliseconds: 1));
          controller.add(FileSystemMoveEvent('b', false, 'c'));

          // Then a second batch with delete of c, create of d.
          async.elapse(const Duration(milliseconds: 100));
          controller.add(FileSystemMoveEvent('c', false, 'd'));

          controller.close();
          batchesFuture.then((batches) {
            expect(
                batches
                    .map((b) =>
                        b.map((e) => '${e.runtimeType} ${e.path}').toList())
                    .toList(),
                [
                  {
                    'FileSystemCreateEvent b',
                    'FileSystemCreateEvent c',
                    'FileSystemDeleteEvent a',
                    'FileSystemDeleteEvent b',
                  },
                  {
                    'FileSystemCreateEvent d',
                    'FileSystemDeleteEvent c',
                  },
                ]);
            expectationsRan = true;
          });

          // Cause `batchesFuture` to complete.
          async.flushMicrotasks();
        });

        // Expectations are at the end of a fake async future, check it actually
        // completed.
        expect(expectationsRan, true);
      });
    });
  });
}
