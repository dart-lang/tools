// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'enums.dart';

class Event {
  final DashEvent eventName;
  final Map<String, Object?> eventData;

  /// Event that is emitted whenever a user has opted in
  /// or out of the analytics collection
  Event.analyticsCollectionEnabled({required bool status})
      : eventName = DashEvent.analyticsCollectionEnabled,
        eventData = {'status': status};

  Event.memoryInfo({
    String? rss,
    int? periodSec,
    double? mbPerSec,
  })  : eventName = DashEvent.memoryInfo,
        eventData = {
          if (rss != null) 'rss': rss,
          if (periodSec != null) 'periodSec': periodSec,
          if (mbPerSec != null) 'mbPerSec': mbPerSec
        };
}
