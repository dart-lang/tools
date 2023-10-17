// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:unified_analytics/src/asserts.dart';

void main() {
  test('Failure if client_id top level key is missing', () {
    final body = <String, Object?>{};

    final expectedErrorMessage = 'client_id missing from top level keys';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure if events top level key is missing', () {
    final body = <String, Object?>{'client_id': 'xxxxxxx'};

    final expectedErrorMessage = 'events missing from top level keys';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure if user_properties top level key is missing', () {
    final body = <String, Object?>{'client_id': 'xxxxxxx', 'events': []};

    final expectedErrorMessage = 'user_properties missing from top level keys';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure if more than 25 events found in events list', () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[],
      'user_properties': <String, Object?>{}
    };

    // Add more than the 25 allowed events
    for (var i = 0; i < 30; i++) {
      (body['events'] as List).add({'name': i});
    }

    final expectedErrorMessage = '25 is the max number of events';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when event name is greater than 40 chars', () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name':
              'hot_reload_timehot_reload_timehot_reload_timehot_reload_time',
          'params': {'time_ms': 133, 'count': 1999000}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final expectedErrorMessage = 'Limit event names to 40 chars or less\n'
        'Event name: '
        '"hot_reload_timehot_reload_timehot_reload_timehot_reload_time"'
        ' is too long';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when event name has invalid chars', () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time!!',
          'params': {'time_ms': 133, 'count': 1999000}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final expectedErrorMessage =
        'Event name can only have alphanumeric chars and underscores\n'
        'Event name: "hot_reload_time!!" contains invalid characters';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when event name does not start with alphabetic char', () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': '2hot_reload_time',
          'params': {'time_ms': 133, 'count': 1999000}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final expectedErrorMessage =
        'Event name first char must be alphabetic char\n'
        'Event name: "2hot_reload_time" must begin with a valid character';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when an event has more than 25 event params', () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          // 'params': {...} SUBBING THIS VALUE OUT 30 Maps
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final params = <String, Object?>{};
    for (var i = 0; i < 30; i++) {
      params['$i'] = i;
    }

    // Add the params to the first event in the body
    ((body['events'] as List).first as Map)['params'] = params;

    final expectedErrorMessage = 'Limit params for each event to less than 25\n'
        'Event: "hot_reload_time" has too many parameters';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when an value for event params is not a supported type (list)',
      () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {
            'time_ms': 133,
            // Lists and Maps are not supported
            'count': <int>[1999000],
          }
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final expectedErrorMessage =
        'Values for event params have to be String, int, double, or bool\n'
        'Value for "count" is not a valid type for event: "hot_reload_time"';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when an value for event params is not a supported type (map)',
      () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {
            'time_ms': 133,
            // Lists and Maps are not supported
            'count': <int, int>{5: 20},
          }
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final expectedErrorMessage =
        'Values for event params have to be String, int, double, or bool\n'
        'Value for "count" is not a valid type for event: "hot_reload_time"';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when event param name is more than 40 chars', () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {'time_mstime_mstime_mstime_mstime_mstime_ms': 133}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final expectedErrorMessage = 'Limit event param names to 40 chars or less\n'
        'The key: "time_mstime_mstime_mstime_mstime_mstime_ms" '
        'under the event: "hot_reload_time" is too long';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure for event param name that has invalid chars', () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {'time_ns!': 133}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final expectedErrorMessage =
        'Event param name can only have alphanumeric chars and underscores\n'
        'The key: "time_ns!" under the event: "hot_reload_time" contains '
        'invalid characters';

    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test(
    'Failure for event param name that does not start with an alphabetic char',
    () {
      final body = <String, Object?>{
        'client_id': 'xxxxxxx',
        'events': <Map<String, Object?>>[
          {
            'name': 'hot_reload_time',
            'params': {'22time_ns': 133}
          }
        ],
        'user_properties': <String, Object?>{}
      };

      final expectedErrorMessage =
          'Event param name first char must be alphabetic char\n'
          'The key: "22time_ns" under the event: "hot_reload_time" must begin '
          'in a valid character';
      expect(
          () => checkBody(body),
          throwsA(predicate(
              (AnalyticsException e) => e.message == expectedErrorMessage,
              expectedErrorMessage)));
    },
  );

  test('Failure for event param values that are greater than 100 chars', () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {
            'time_ns': 'dsfjlksdjfajlfdsfjlks'
                'djfajlfdsfjlksdjfajlfdsfjlksdjfaj'
                'lfdsfjlksdjfajlfdsfjlksdjfajlfdsf'
                'jlksdjfajlfdsfjlksdjfajlf'
          }
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final expectedErrorMessage =
        'Limit characters in event param value to 100 chars or less\n'
        'Value for "time_ns" is too long, value="'
        'dsfjlksdjfajlfdsfjlks'
        'djfajlfdsfjlksdjfajlfdsfjlksdjfaj'
        'lfdsfjlksdjfajlfdsfjlksdjfajlfdsf'
        'jlksdjfajlfdsfjlksdjfajlf"';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when body has more than 25 user properties', () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {'time_ns': 123}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    for (var i = 0; i < 30; i++) {
      (body['user_properties']! as Map<String, Object?>)['$i'] = i;
    }

    final expectedErrorMessage = 'Limit user properties to 25 or less';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when user properties names are greater than 24 chars', () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {'time_ns': 123}
        }
      ],
      'user_properties': <String, Object?>{
        'testtesttesttesttesttesttest': <String, Object?>{}, // TOO LONG
      }
    };

    final expectedErrorMessage =
        'Limit user property names to 24 chars or less\n'
        'The user property key: "testtesttesttesttesttesttest" is too long';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when user properties values are greater than 36 chars', () {
    final body = <String, Object?>{
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {'time_ns': 123}
        }
      ],
      'user_properties': <String, Object?>{
        'test': <String, Object?>{
          'value': 'testtesttesttesttesttesttesttesttesttest' // TOO LONG
        },
      }
    };

    final expectedErrorMessage =
        'Limit user property values to 36 chars or less\n'
        'For the user property key "test", the value '
        '"testtesttesttesttesttesttesttesttesttest" is too long';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Successful body passes all asserts', () {
    final body = <String, Object?>{
      'client_id': '46cc0ba6-f604-4fd9-aa2f-8a20beb24cd4',
      'events': [
        {
          'name': 'testing',
          'params': {'time_ns': 345}
        }
      ],
      'user_properties': {
        'session_id': {'value': 1673466750423},
        'flutter_channel': {'value': 'ey-test-channel'},
        'host': {'value': 'macos'},
        'flutter_version': {'value': 'Flutter 3.6.0-7.0.pre.47'},
        'dart_version': {'value': 'Dart 2.19.0'},
        'tool': {'value': 'flutter-tools'},
        'local_time': {'value': '2023-01-11 14:53:31.471816 -0500'}
      }
    };

    expect(() => checkBody(body), returnsNormally);
  });
}
