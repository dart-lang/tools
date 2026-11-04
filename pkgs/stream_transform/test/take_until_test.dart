// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stream_transform/stream_transform.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  for (var streamType in streamTypes) {
    group('takeUntil on Stream type [$streamType]', () {
      late StreamController<int> values;
      late List<int> emittedValues;
      late bool valuesCanceled;
      late bool isDone;
      late List<String> errors;
      late Stream<int> transformed;
      late StreamSubscription<int> subscription;
      late Completer<void> closeTrigger;

      setUp(() {
        valuesCanceled = false;
        values = createController(streamType)
          ..onCancel = () {
            valuesCanceled = true;
          };
        emittedValues = [];
        errors = [];
        isDone = false;
        closeTrigger = Completer();
        transformed = values.stream.takeUntil(closeTrigger.future);
      });

      void listen() {
        subscription = transformed
            .listen(emittedValues.add, onError: errors.add, onDone: () {
          isDone = true;
        });
      }

      // Automatically listen to stream.
      group('', () {
        setUp(listen);

        test('forwards cancellation', () async {
          await subscription.cancel();
          expect(valuesCanceled, true);
        });

        test('lets values through before trigger', () async {
          values
            ..add(1)
            ..add(2);
          await Future(() {});
          expect(emittedValues, [1, 2]);
        });

        test('forwards errors', () async {
          values.addError('error');
          await Future(() {});
          expect(errors, ['error']);
        });

        test('sends done if original strem ends', () async {
          await values.close();
          expect(isDone, true);
        });

        test('sends done when trigger fires', () async {
          closeTrigger.complete();
          await Future(() {});
          expect(isDone, true);
        });

        test('forwards errors from the close trigger', () async {
          closeTrigger.completeError('sad');
          await Future(() {});
          expect(errors, ['sad']);
          expect(isDone, true);
        });

        test('ignores errors from the close trigger after stream closed',
            () async {
          await values.close();
          closeTrigger.completeError('sad');
          await Future(() {});
          expect(errors, <Object>[]);
        });

        test('cancels value subscription when trigger fires', () async {
          closeTrigger.complete();
          await Future(() {});
          expect(valuesCanceled, true);
        });

        test('cancels value subscription when trigger completes with error',
            () async {
          closeTrigger.completeError('sad');
          await Future(() {});
          expect(valuesCanceled, true);
          expect(errors, ['sad']);
          expect(isDone, true);
        });

        test('ignores source events after trigger completes with error',
            () async {
          closeTrigger.completeError('sad');
          await Future(() {});
          values.add(1);
          await Future(() {});
          expect(emittedValues, isEmpty);
        });

        // Broadcast controllers ignore the future returned by `onCancel`, so
        // the cancel future can only be observed with a single subscription
        // controller.
        if (streamType == 'single subscription') {
          test('waits for value subscription cancel before closing', () async {
            var cancelDone = Completer<void>();
            values.onCancel = () => cancelDone.future;
            closeTrigger.complete();
            await Future(() {});
            expect(isDone, false);
            cancelDone.complete();
            await Future(() {});
            expect(isDone, true);
          });

          test(
              'forwards trigger error before cancelling', () async {
            var cancelDone = Completer<void>();
            values.onCancel = () => cancelDone.future;
            closeTrigger.completeError('sad');
            await Future(() {});
            expect(errors, ['sad']);
            expect(isDone, false);
            cancelDone.complete();
            await Future(() {});
            expect(errors, ['sad']);
            expect(isDone, true);
          });

          test('forwards errors from value subscription cancel', () async {
            values.onCancel = () => Future<void>.error('cancel failed');
            closeTrigger.completeError('sad');
            await Future(() {});
            expect(errors, ['sad', 'cancel failed']);
            expect(isDone, true);
          });

          test('cancel during trigger cancel gets error', () async {
            var cancelCompleter = Completer<void>();
            values.onCancel = () => cancelCompleter.future;
            closeTrigger.complete('done');
            await Future(() {});
            expect(isDone, false);
            var cancelFuture = subscription.cancel()..ignore();
            await Future(() {});
            expect(isDone, false);
            cancelCompleter.completeError('cancel failed');
            await expectLater(cancelFuture, throwsA('cancel failed'));
          });
        }
        
        if (streamType == 'broadcast') {
          test('multiple listeners all get values', () async {
            var otherValues = <Object>[];
            transformed.listen(otherValues.add);
            values
              ..add(1)
              ..add(2);
            await Future(() {});
            expect(emittedValues, [1, 2]);
            expect(otherValues, [1, 2]);
          });

          test('multiple listeners get done when trigger fires', () async {
            var otherDone = false;
            transformed.listen(null, onDone: () => otherDone = true);
            closeTrigger.complete();
            await Future(() {});
            expect(otherDone, true);
            expect(isDone, true);
          });

          test('multiple listeners get done when values end', () async {
            var otherDone = false;
            transformed.listen(null, onDone: () => otherDone = true);
            await values.close();
            expect(otherDone, true);
            expect(isDone, true);
          });

          test('can cancel and relisten before trigger fires', () async {
            values.add(1);
            await Future(() {});
            await subscription.cancel();
            values.add(2);
            await Future(() {});
            subscription = transformed.listen(emittedValues.add);
            values.add(3);
            await Future(() {});
            expect(emittedValues, [1, 3]);
          });
        }
      });
      // Trigger before listen.
      if (streamType == 'broadcast') {
        test('trigger before listen', () async {
          closeTrigger.complete();
          await Future(() {});
          expect(values.hasListener, false);
          expect(isDone, false);
          listen();
          expect(values.hasListener, false);
          await Future(() {});
          expect(isDone, true);
        });
      } else {
        test('trigger before listen, no trigger error', () async {
          // Stream is never listened to and never cancelled.
          values.onCancel = () => Future<void>.error('cancel failed');
          values.addError('error event');

          closeTrigger.complete();
          await Future(() {});
          expect(errors, isEmpty);
          expect(isDone, false);
          listen();
          expect(values.hasListener, false);
          await Future(() {});
          expect(errors, isEmpty);
          expect(isDone, true);
        });

        test('trigger before listen, trigger error', () async {
          // Stream is never listened to and never cancelled.
          values.onCancel = () => Future<void>.error('cancel failed');
          values.addError('error event');

          closeTrigger.completeError('trigger error');
          await Future(() {});
          expect(errors, isEmpty);
          expect(isDone, false);
          listen();
          expect(values.hasListener, false);
          await Future(() {});
          expect(errors, ['trigger error']);
          expect(isDone, true);
        });
      }
    });
  }
}

