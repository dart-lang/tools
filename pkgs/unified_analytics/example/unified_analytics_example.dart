// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unified_analytics/unified_analytics.dart';

final String measurementId = 'G-N1NXG28J5B';
final String apiSecret = '4yT8__oER3Cd84dtx6r-_A';

// Globally instantiate the analytics class at the entry
// point of the tool
final Analytics analytics = Analytics(
  tool: DashTool.flutterTools,
  flutterChannel: 'ey-test-channel',
  flutterVersion: 'Flutter 3.6.0-7.0.pre.47',
  dartVersion: 'Dart 2.19.0',
);

void main() {
  DateTime start = DateTime.now();
  print('###### START ###### $start');

  // Confirm to analytics instance that the message was shown;
  // simplified for this example, tools using this package will
  // invoke this method after confirming they have showed the
  // message
  analytics.clientShowedMessage();

  print(analytics.telemetryEnabled);
  // [eventData] is an optional map to add relevant data
  // for the [eventName] being sent
  analytics.sendEvent(
    eventName: DashEvent.hotReloadTime,
    eventData: <String, int>{'time_ns': 345},
  );
  print(analytics.logFileStats());
  analytics.close();

  DateTime end = DateTime.now();
  print(
      '###### DONE ###### ${DateTime.now()} ${end.difference(start).inMilliseconds}ms');
}
