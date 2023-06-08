// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart';

import 'asserts.dart';
import 'enums.dart';
import 'ga_client.dart';
import 'log_handler.dart';
import 'user_property.dart';
import 'utils.dart';

class Events {
  final GAClient _gaClient;
  final bool _okToSend;
  final String _clientId;
  final UserProperty _userProperty;
  final bool _enableAsserts;
  final LogHandler _logHandler;

  Events({
    required GAClient gaClient,
    required bool okToSend,
    required String clientId,
    required UserProperty userProperty,
    required bool enableAsserts,
    required LogHandler logHandler,
  })  : _gaClient = gaClient,
        _okToSend = okToSend,
        _clientId = clientId,
        _userProperty = userProperty,
        _enableAsserts = enableAsserts,
        _logHandler = logHandler {
    print(okToSend);
  }

  Future<Response>? memoryEvent({
    String? rss,
    int? periodSec,
    double? mbPerSec,
  }) =>
      _sendEvent(eventName: DashEvent.memoryInfo, eventData: {
        if (rss != null) 'rss': rss,
        if (periodSec != null) 'periodSec': periodSec,
        if (mbPerSec != null) 'mbPerSec': mbPerSec
      });

  Future<Response>? _sendEvent({
    required DashEvent eventName,
    Map<String, Object?> eventData = const {},
  }) {
    if (!_okToSend) return null;

    // Construct the body of the request
    final body = generateRequestBody(
      clientId: _clientId,
      eventName: eventName,
      eventData: eventData,
      userProperty: _userProperty,
    );

    if (_enableAsserts) checkBody(body);

    _logHandler.save(data: body);

    // Pass to the google analytics client to send
    return _gaClient.sendData(body);
  }
}
