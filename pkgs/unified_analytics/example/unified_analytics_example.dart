// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unified_analytics/unified_analytics.dart';

// Globally instantiate the analytics class at the entry
// point of the tool
//
// Development constructor used here so we don't push
// to production when running
final Analytics analytics = Analytics.development(
  tool: DashTool.flutterTool,
  flutterChannel: 'ey-test-channel',
  flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
  dartVersion: 'Dart 2.19.0',
);

// Timing a process and sending the event
void main() {
  DateTime start = DateTime.now();

  // Each client using this package will have it's own
  // method to show the message but the below is a trivial
  // example of how to properly initialize the analytics instance
  if (analytics.shouldShowMessage) {
    // Simulates displaying the message, this will vary from
    // client to client; ie. stdout, popup in IDE, etc.
    print(analytics.getConsentMessage);

    // After receiving confirmation that the message has been
    // displayed, invoking the below method will successfully
    // onboard the tool into the config file and allow for
    // events to be sent on the next creation of the analytics
    // instance
    //
    // The rest of the example below assumes that the tool has
    // already been onboarded in a previous run
    analytics.clientShowedMessage();
  }

  print('Current is opted in: ${analytics.telemetryEnabled}');

  // Example of long running process
  int count = 0;
  for (int i = 0; i < 2000; i++) {
    count += i;
  }

  // Calculate the metric to send
  final int runTime = DateTime.now().difference(start).inMilliseconds;
  // Generate the body for the event data
  final Map<String, int> eventData = {
    'time_ms': runTime,
    'count': count,
  };
  // Choose one of the enum values for [DashEvent] which should
  // have all possible events; if not there, open an issue for the
  // team to add
  final DashEvent eventName =
      DashEvent.hotReloadTime; // Select appropriate DashEvent enum value

  // Make a call to the [Analytics] api to send the data
  analytics.sendEvent(
    eventName: eventName,
    eventData: eventData,
  );

  // Close the client connection on exit
  analytics.close();
}
