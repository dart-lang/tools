/// Checks that the body of the request being sent to
/// GA4 is within the limitations
///
/// Limitations can be found:
/// https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events?client_type=gtag#limitations
void checkBody(Map<String, Object?> body) {
  final List events = body['events'] as List;
  final Map<String, Object?> userProperties =
      body['user_properties'] as Map<String, Object?>;

  // Ensure we have the correct top level keys
  assert(body.keys.contains('client_id') == true,
      'client_id key not found in body of request');
  assert(body.keys.contains('events') == true,
      'events key not found in body of request');
  assert(body.keys.contains('user_properties') == true,
      'user_properties key not found in body of request');

  // GA4 Limitation:
  // Requests can have a maximum of 25 events
  assert(events.length <= 25, 'Limit event params to 25 or less');

  // Checks for each event object
  for (Map<String, Object?> eventMap in events) {
    // GA4 Limitation:
    // Event names must be 40 characters or fewer, may only contain
    // alpha-numeric characters and underscores, and must start
    // with an alphabetic character
    assert((eventMap['name'] as String).length <= 40,
        'Limit event names to 40 chars or less');
    assert(RegExp(r'^[A-Za-z0-9_]+$').hasMatch(eventMap['name'] as String),
        'Event name can only have alphanumeric chars and underscores');
    assert(RegExp(r'^[A-Za-z]+$').hasMatch((eventMap['name'] as String)[0]),
        'Event name first char must be alphabetic char');

    // GA4 Limitation:
    // Events can have a maximum of 25 parameters
    assert((eventMap['params'] as Map<String, Object?>).length <= 25,
        'Limit params for each event to less than 25');

    // Loop through each of the event parameters
    (eventMap['params'] as Map<String, Object?>).forEach((key, value) {
      // GA4 Limitation:
      // Ensure that each value for the event params is one
      // of the following types:
      // `String`, `int`, `double`, or `bool`
      assert(
          value is String || value is int || value is double || value is bool,
          'Values for event params have to be String, int, double, or bool');

      // GA4 Limitation:
      // Parameter names (including item parameters) must be 40 characters
      // or fewer, may only contain alpha-numeric characters and underscores,
      // and must start with an alphabetic character
      assert(key.length <= 40, 'Limit event param names to 40 chars or less');
      assert(RegExp(r'^[A-Za-z0-9_]+$').hasMatch(key),
          'Event param name can only have alphanumeric chars and underscores');
      assert(RegExp(r'^[A-Za-z]+$').hasMatch(key[0]),
          'Event param name first char must be alphabetic char');

      // GA4 Limitation:
      // Parameter values (including item parameter values) must be 100
      // characters or fewer
      if (value.runtimeType == String) {
        value as String;
        assert(value.length <= 100,
            'Limit characters in event param value to 100 chars or less');
      }
    });
  }

  // GA4 Limitation:
  // Events can have a maximum of 25 user properties
  assert(userProperties.length <= 25, 'Limit user properties to 25 or less');

  // Checks for each user property item
  userProperties.forEach((key, value) {
    value as Map<String, Object?>;

    // GA4 Limitation:
    // User property names must be 24 characters or fewer
    assert(key.length <= 24, 'Limit user property names to 24 chars or less');

    // GA4 Limitation:
    // User property values must be 36 characters or fewer
    if (value['value'].runtimeType == String) {
      assert((value['value'] as String).length <= 36,
          'Limit user property values to 36 chars or less');
    }
  });
}
