// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'analytics.dart';
import 'enums.dart';

class AnalyticsImpl extends AnalyticsImplNoEvents {
  /// The [Analytics] implementation that includes the
  /// events that will be sent by tools using this package
  ///
  /// Using pre-defined events with preconfigured parameters
  /// ensures that events being sent are standardized and
  /// can be audited by referencing the APIs in this file
  AnalyticsImpl({
    required super.tool,
    required super.homeDirectory,
    String? flutterChannel,
    String? flutterVersion,
    required super.dartVersion,
    required super.platform,
    required super.toolsMessageVersion,
    required super.fs,
    required super.gaClient,
    required super.enableAsserts,
  });

  Future<void> sendMemoryEvent({
    String? rss,
    int? periodSec,
    double? mbPerSec,
  }) async {
    await sendEvent(eventName: DashEvent.memoryInfo, eventData: {
      if (rss != null) 'rss': rss,
      if (periodSec != null) 'periodSec': periodSec,
      if (mbPerSec != null) 'mbPerSec': mbPerSec
    });
  }
}
