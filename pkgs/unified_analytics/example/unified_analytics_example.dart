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
  clientIde: 'VSCode',
  dartVersion: 'Dart 2.19.0',
  // This can be set to true while testing to validate
  // against GA4 usage limitations (character limits, etc.)
  enableAsserts: false,
  enabledFeatures: 'feature-1,feature-2',
);

// Timing a process and sending the event
void main() async {
  final start = DateTime.now();

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

  print('Current user ${analytics.clientId} '
      'is opted in: ${analytics.telemetryEnabled}');

  // Example of long running process
  await Future<void>.delayed(const Duration(milliseconds: 100));

  // Calculate the metric to send
  final runTime = DateTime.now().difference(start).inMilliseconds;

  // Create the event that will be sent for the hot reload time
  // as an example
  final hotReloadEvent = Event.hotReloadTime(timeMs: runTime);

  // Make a call to the [Analytics] api to send the data
  analytics.send(hotReloadEvent);

  // Close the client connection on exit
  await analytics.close();
}
