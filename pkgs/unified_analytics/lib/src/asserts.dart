/// Checks that the body of the request being sent to
/// GA4 is within the limitations
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

  final List events = body['events'] as List;
  final Map<String, Object?> userProperties =
      body['user_properties'] as Map<String, Object?>;

  // GA4 Limitation:
  // Requests can have a maximum of 25 events
  if (events.length > 25) {
    throw AnalyticsException('25 is the max number of events');
  }

  // Checks for each event object
  for (Map<String, Object?> eventMap in events) {
    final String eventName = eventMap['name'] as String;

    // GA4 Limitation:
    // Event names must be 40 characters or fewer, may only contain
    // alpha-numeric characters and underscores, and must start
    // with an alphabetic character
    if (eventName.length > 40) {
      throw AnalyticsException('Limit event names to 40 chars or less');
    }
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(eventName)) {
      throw AnalyticsException(
          'Event name can only have alphanumeric chars and underscores');
    }
    if (!RegExp(r'^[A-Za-z]+$').hasMatch(eventName[0])) {
      throw AnalyticsException('Event name first char must be alphabetic char');
    }

    final Map<String, Object?> eventParams =
        eventMap['params'] as Map<String, Object?>;

    // GA4 Limitation:
    // Events can have a maximum of 25 parameters
    if (eventParams.length > 25) {
      throw AnalyticsException('Limit params for each event to less than 25');
    }

    // Loop through each of the event parameters
    eventParams.forEach((key, value) {
      // GA4 Limitation:
      // Ensure that each value for the event params is one
      // of the following types:
      // `String`, `int`, `double`, or `bool`
      if (!(value is String ||
          value is int ||
          value is double ||
          value is bool)) {
        throw AnalyticsException(
            'Values for event params have to be String, int, double, or bool');
      }

      // GA4 Limitation:
      // Parameter names (including item parameters) must be 40 characters
      // or fewer, may only contain alpha-numeric characters and underscores,
      // and must start with an alphabetic character
      if (key.length > 40) {
        throw AnalyticsException('Limit event param names to 40 chars or less');
      }
      if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(key)) {
        throw AnalyticsException(
            'Event param name can only have alphanumeric chars and underscores');
      }
      if (!RegExp(r'^[A-Za-z]+$').hasMatch(key[0])) {
        throw AnalyticsException(
            'Event param name first char must be alphabetic char');
      }

      // GA4 Limitation:
      // Parameter values (including item parameter values) must be 100
      // characters or fewer
      if (value.runtimeType == String) {
        value as String;
        if (value.length > 100) {
          throw AnalyticsException(
              'Limit characters in event param value to 100 chars or less');
        }
      }
    });
  }

  // GA4 Limitation:
  // Events can have a maximum of 25 user properties
  if (userProperties.length > 25) {
    throw AnalyticsException('Limit user properties to 25 or less');
  }

  // Checks for each user property item
  userProperties.forEach((key, value) {
    value as Map<String, Object?>;

    // GA4 Limitation:
    // User property names must be 24 characters or fewer
    if (key.length > 24) {
      throw AnalyticsException('Limit user property names to 24 chars or less');
    }

    // GA4 Limitation:
    // User property values must be 36 characters or fewer
    if (value['value'].runtimeType == String) {
      if ((value['value'] as String).length > 36) {
        throw AnalyticsException(
            'Limit user property values to 36 chars or less');
      }
    }
  });
}

class AnalyticsException implements Exception {
  final String message;

  AnalyticsException(this.message);
}
