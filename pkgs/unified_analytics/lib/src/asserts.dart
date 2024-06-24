// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Matches only alphabetic characters.
final RegExp alphabeticPattern = RegExp(r'^[A-Za-z]+$');

/// Matches strings that contain alphanumeric characters and underscores.
final RegExp alphaNumericPattern = RegExp(r'^[A-Za-z0-9_]+$');

/// Checks that the body of the request being sent to
/// GA4 is within the limitations.
///
/// Limitations can be found:
/// https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events?client_type=gtag#limitations
void checkBody(Map<String, Object?> body) {
  // Ensure we have the correct top level keys
  if (!body.keys.contains('client_id')) {
    throw AnalyticsException('client_id missing from top level keys');
  }
  if (!body.keys.contains('events')) {
    throw AnalyticsException('events missing from top level keys');
  }
  if (!body.keys.contains('user_properties')) {
    throw AnalyticsException('user_properties missing from top level keys');
  }

  final events = body['events'] as List;
  final userProperties = body['user_properties'] as Map<String, Object?>;

  // GA4 Limitation:
  // Requests can have a maximum of 25 events
  if (events.length > 25) {
    throw AnalyticsException('25 is the max number of events');
  }

  // Checks for each event object
  for (final eventMap in events.cast<Map<String, Object?>>()) {
    final eventName = eventMap['name'] as String;

    // GA4 Limitation:
    // Event names must be 40 characters or fewer, may only contain
    // alpha-numeric characters and underscores, and must start
    // with an alphabetic character
    if (eventName.length > 40) {
      throw AnalyticsException(
        'Limit event names to 40 chars or less\n'
        'Event name: "$eventName" is too long',
      );
    }
    if (!alphaNumericPattern.hasMatch(eventName)) {
      throw AnalyticsException(
        'Event name can only have alphanumeric chars and underscores\n'
        'Event name: "$eventName" contains invalid characters',
      );
    }
    if (!alphabeticPattern.hasMatch(eventName[0])) {
      throw AnalyticsException(
        'Event name first char must be alphabetic char\n'
        'Event name: "$eventName" must begin with a valid character',
      );
    }

    final eventParams = eventMap['params'] as Map<String, Object?>;

    // GA4 Limitation:
    // Events can have a maximum of 25 parameters
    if (eventParams.length > 25) {
      throw AnalyticsException(
        'Limit params for each event to less than 25\n'
        'Event: "$eventName" has too many parameters',
      );
    }

    // Loop through each of the event parameters
    for (final entry in eventParams.entries) {
      final key = entry.key;
      final value = entry.value;

      // GA4 Limitation:
      // Ensure that each value for the event params is one
      // of the following types:
      // `String`, `int`, `double`, or `bool`
      if (!(value is String ||
          value is int ||
          value is double ||
          value is bool)) {
        throw AnalyticsException(
          'Values for event params have to be String, int, double, or bool\n'
          'Value for "$key" is not a valid type for event: "$eventName"',
        );
      }

      // GA4 Limitation:
      // Parameter names (including item parameters) must be 40 characters
      // or fewer, may only contain alpha-numeric characters and underscores,
      // and must start with an alphabetic character
      if (key.length > 40) {
        throw AnalyticsException(
          'Limit event param names to 40 chars or less\n'
          'The key: "$key" under the event: "$eventName" is too long',
        );
      }
      if (!alphaNumericPattern.hasMatch(key)) {
        throw AnalyticsException(
          'Event param name can only have alphanumeric chars and underscores\n'
          'The key: "$key" under the event: "$eventName" contains '
          'invalid characters',
        );
      }
      if (!alphabeticPattern.hasMatch(key[0])) {
        throw AnalyticsException(
          'Event param name first char must be alphabetic char\n'
          'The key: "$key" under the event: "$eventName" must begin '
          'in a valid character',
        );
      }

      // GA4 Limitation:
      // Parameter values (including item parameter values) must be 100
      // characters or fewer
      if (value.runtimeType == String) {
        value as String;
        if (value.length > 100) {
          throw AnalyticsException(
            'Limit characters in event param value to 100 chars or less\n'
            'Value for "$key" is too long, value="$value"',
          );
        }
      }
    }
  }

  // GA4 Limitation:
  // Events can have a maximum of 25 user properties
  if (userProperties.length > 25) {
    throw AnalyticsException('Limit user properties to 25 or less');
  }

  // Checks for each user property item
  for (final entry in userProperties.entries) {
    final key = entry.key;
    final value = entry.value as Map<String, Object?>;

    // GA4 Limitation:
    // User property names must be 24 characters or fewer
    if (key.length > 24) {
      throw AnalyticsException('Limit user property names to 24 chars or less\n'
          'The user property key: "$key" is too long');
    }

    // GA4 Limitation:
    // User property values must be 36 characters or fewer
    final userPropValue = value['value'];
    if (userPropValue is String && userPropValue.length > 36) {
      throw AnalyticsException(
        'Limit user property values to 36 chars or less\n'
        'For the user property key "$key", the value "${value['value']}" '
        'is too long',
      );
    }
  }
}

class AnalyticsException implements Exception {
  final String message;

  AnalyticsException(this.message);

  @override
  String toString() => 'AnalyticsException: $message';
}
