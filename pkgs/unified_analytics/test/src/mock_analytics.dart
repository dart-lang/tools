// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart';

import 'package:unified_analytics/src/analytics.dart';
import 'package:unified_analytics/src/asserts.dart';
import 'package:unified_analytics/src/event.dart';
import 'package:unified_analytics/src/ga_client.dart';
import 'package:unified_analytics/src/log_handler.dart';
import 'package:unified_analytics/src/utils.dart';

class MockAnalytics extends AnalyticsImpl {
  final List<Event> sentEvents = [];
  final LogHandler _logHandler;
  final FakeGAClient _gaClient;
  final String _clientId = 'hard-coded-client-id';

  /// Class to use when you want to see which events were sent
  MockAnalytics({
    required super.tool,
    required super.homeDirectory,
    required super.dartVersion,
    required super.platform,
    required super.toolsMessageVersion,
    required super.fs,
    required super.gaClient,
    required super.surveyHandler,
    required super.enableAsserts,
    super.flutterChannel,
    super.flutterVersion,
  })  : _logHandler = LogHandler(fs: fs, homeDirectory: homeDirectory),
        _gaClient = FakeGAClient();

  @override
  Future<Response>? send(Event event) {
    if (!okToSend) return null;

    // Construct the body of the request
    final body = generateRequestBody(
      clientId: _clientId,
      eventName: event.eventName,
      eventData: event.eventData,
      userProperty: userProperty,
    );

    checkBody(body);

    _logHandler.save(data: body);

    // Using this list to validate that events are being sent
    // for internal methods in the `Analytics` instance
    sentEvents.add(event);
    return _gaClient.sendData(body);
  }
}
