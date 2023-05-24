// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:unified_analytics/src/asserts.dart';

void main() {
  test('Failure if client_id top level key is missing', () {
    final Map<String, Object?> body = {};

    final String expectedErrorMessage = 'client_id missing from top level keys';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure if events top level key is missing', () {
    final Map<String, Object?> body = {'client_id': 'xxxxxxx'};

    final String expectedErrorMessage = 'events missing from top level keys';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure if user_properties top level key is missing', () {
    final Map<String, Object?> body = {'client_id': 'xxxxxxx', 'events': []};

    final String expectedErrorMessage =
        'user_properties missing from top level keys';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure if more than 25 events found in events list', () {
    final Map<String, Object?> body = {
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[],
      'user_properties': <String, Object?>{}
    };

    // Add more than the 25 allowed events
    for (int i = 0; i < 30; i++) {
      (body['events'] as List).add({'name': i});
    }

    final String expectedErrorMessage = '25 is the max number of events';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when event name is greater than 40 chars', () {
    final Map<String, Object?> body = {
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

    final String expectedErrorMessage = 'Limit event names to 40 chars or less';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when event name has invalid chars', () {
    final Map<String, Object?> body = {
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time!!',
          'params': {'time_ms': 133, 'count': 1999000}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final String expectedErrorMessage =
        'Event name can only have alphanumeric chars and underscores';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when event name does not start with alphabetic char', () {
    final Map<String, Object?> body = {
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': '2hot_reload_time',
          'params': {'time_ms': 133, 'count': 1999000}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final String expectedErrorMessage =
        'Event name first char must be alphabetic char';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when an event has more than 25 event params', () {
    final Map<String, Object?> body = {
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          // 'params': {...} SUBBING THIS VALUE OUT 30 Maps
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final Map<String, Object?> params = {};
    for (int i = 0; i < 30; i++) {
      params['$i'] = i;
    }

    // Add the params to the first event in the body
    (body['events'] as List).first['params'] = params;

    final String expectedErrorMessage =
        'Limit params for each event to less than 25';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when an value for event params is not a supported type (list)',
      () {
    final Map<String, Object?> body = {
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

    final String expectedErrorMessage =
        'Values for event params have to be String, int, double, or bool';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when an value for event params is not a supported type (map)',
      () {
    final Map<String, Object?> body = {
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

    final String expectedErrorMessage =
        'Values for event params have to be String, int, double, or bool';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when event param name is more than 40 chars', () {
    final Map<String, Object?> body = {
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {'time_mstime_mstime_mstime_mstime_mstime_ms': 133}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final String expectedErrorMessage =
        'Limit event param names to 40 chars or less';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure for event param name that has invalid chars', () {
    final Map<String, Object?> body = {
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {'time_ns!': 133}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final String expectedErrorMessage =
        'Event param name can only have alphanumeric chars and underscores';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test(
      'Failure for event param name that does not start with an alphabetic char',
      () {
    final Map<String, Object?> body = {
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {'22time_ns': 133}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    final String expectedErrorMessage =
        'Event param name first char must be alphabetic char';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure for event param values that are greater than 100 chars', () {
    final Map<String, Object?> body = {
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

    final String expectedErrorMessage =
        'Limit characters in event param value to 100 chars or less';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when body has more than 25 user properties', () {
    final Map<String, Object?> body = {
      'client_id': 'xxxxxxx',
      'events': <Map<String, Object?>>[
        {
          'name': 'hot_reload_time',
          'params': {'time_ns': 123}
        }
      ],
      'user_properties': <String, Object?>{}
    };

    for (int i = 0; i < 30; i++) {
      (body['user_properties']! as Map<String, Object?>)['$i'] = i;
    }

    final String expectedErrorMessage = 'Limit user properties to 25 or less';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when user properties names are greater than 24 chars', () {
    final Map<String, Object?> body = {
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

    final String expectedErrorMessage =
        'Limit user property names to 24 chars or less';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });

  test('Failure when user properties values are greater than 36 chars', () {
    final Map<String, Object?> body = {
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

    final String expectedErrorMessage =
        'Limit user property values to 36 chars or less';
    expect(
        () => checkBody(body),
        throwsA(predicate(
            (AnalyticsException e) => e.message == expectedErrorMessage,
            expectedErrorMessage)));
  });
}
