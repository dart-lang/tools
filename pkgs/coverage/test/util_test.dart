// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:coverage/src/util.dart';
import 'package:test/test.dart';

const _failCount = 5;
const _delay = Duration(milliseconds: 10);

void main() {
  test('retry', () async {
    var count = 0;
    final stopwatch = Stopwatch()..start();

    Future failCountTimes() async {
      expect(stopwatch.elapsed, greaterThanOrEqualTo(_delay * count));

      while (count < _failCount) {
        count++;
        throw 'not yet!';
      }
      return 42;
    }

    final value = await retry(failCountTimes, _delay) as int;

    expect(value, 42);
    expect(count, _failCount);
    expect(stopwatch.elapsed, greaterThanOrEqualTo(_delay * count));
  });

  group('retry with timeout', () {
    test('if it finishes', () async {
      var count = 0;
      final stopwatch = Stopwatch()..start();

      Future failCountTimes() async {
        expect(stopwatch.elapsed, greaterThanOrEqualTo(_delay * count));

        while (count < _failCount) {
          count++;
          throw 'not yet!';
        }
        return 42;
      }

      final safeTimoutDuration = _delay * _failCount * 2;
      final value = await retry(
        failCountTimes,
        _delay,
        timeout: safeTimoutDuration,
      ) as int;

      expect(value, 42);
      expect(count, _failCount);
      expect(stopwatch.elapsed, greaterThanOrEqualTo(_delay * count));
    });

    test('if it does not finish', () async {
      var count = 0;
      final stopwatch = Stopwatch()..start();

      var caught = false;
      var countAfterError = 0;

      Future failCountTimes() async {
        if (caught) {
          countAfterError++;
        }
        expect(stopwatch.elapsed, greaterThanOrEqualTo(_delay * count));

        count++;
        throw 'never';
      }

      final unsafeTimeoutDuration = _delay * (_failCount / 2);

      try {
        await retry(failCountTimes, _delay, timeout: unsafeTimeoutDuration);
      } on StateError catch (e) {
        expect(e.message, 'Failed to complete within 25ms');
        caught = true;

        expect(countAfterError, 0,
            reason: 'Execution should stop after a timeout');

        await Future<dynamic>.delayed(_delay * 3);

        expect(countAfterError, 0, reason: 'Even after a delay');
      }

      expect(caught, isTrue);
    });
  });

  group('extractObservatoryUri', () {
    test('returns null when not found', () {
      expect(extractObservatoryUri('foo bar baz'), isNull);
    });

    test('returns null for an incorrectly formatted URI', () {
      const msg = 'Observatory listening on :://';
      expect(extractObservatoryUri(msg), null);
    });

    test('returns URI at end of string', () {
      const msg = 'Observatory listening on http://foo.bar:9999/';
      expect(extractObservatoryUri(msg), Uri.parse('http://foo.bar:9999/'));
    });

    test('returns URI with auth token at end of string', () {
      const msg = 'Observatory listening on http://foo.bar:9999/cG90YXRv/';
      expect(extractObservatoryUri(msg),
          Uri.parse('http://foo.bar:9999/cG90YXRv/'));
    });

    test('return URI embedded within string', () {
      const msg = '1985-10-26 Observatory listening on http://foo.bar:9999/ **';
      expect(extractObservatoryUri(msg), Uri.parse('http://foo.bar:9999/'));
    });

    test('return URI with auth token embedded within string', () {
      const msg =
          '1985-10-26 Observatory listening on http://foo.bar:9999/cG90YXRv/ **';
      expect(extractObservatoryUri(msg),
          Uri.parse('http://foo.bar:9999/cG90YXRv/'));
    });
  });
}
