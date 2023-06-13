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

  Event.clientNotification({
    String? duration,
    String? latency,
    String? method,
  })  : eventName = DashEvent.clientNotification,
        eventData = {
          if (duration != null) 'duration': duration,
          if (latency != null) 'latency': latency,
          if (method != null) 'method': method,
        };

  Event.clientRequest({
    String? added,
    String? command,
    String? duration,
    String? excluded,
    String? files,
    String? included,
    String? kind,
    String? latency,
    String? method,
    String? openWorkspacePaths,
    String? removed,
  })  : eventName = DashEvent.clientRequest,
        eventData = {
          if (added != null) 'added': added,
          if (command != null) 'command': command,
          if (duration != null) 'duration': duration,
          if (excluded != null) 'excluded': excluded,
          if (files != null) 'files': files,
          if (included != null) 'included': included,
          if (kind != null) 'kind': kind,
          if (latency != null) 'latency': latency,
          if (method != null) 'method': method,
          if (openWorkspacePaths != null)
            'openWorkspacePaths': openWorkspacePaths,
          if (removed != null) 'removed': removed,
        };

  Event.contextStructure({
    String? contextsFromBothFiles,
    String? contextsFromOptionsFiles,
    String? contextsFromPackagesFiles,
    String? contextsWithoutFiles,
    String? immediateFileCount,
    String? immediateFileLineCount,
    String? numberOfContexts,
    String? transitiveFileCount,
    String? transitiveFileLineCount,
    String? transitiveFileUniqueCount,
    String? transitiveFileUniqueLineCount,
  })  : eventName = DashEvent.contextStructure,
        eventData = {
          if (contextsFromBothFiles != null)
            'contextsFromBothFiles': contextsFromBothFiles,
          if (contextsFromOptionsFiles != null)
            'contextsFromOptionsFiles': contextsFromOptionsFiles,
          if (contextsFromPackagesFiles != null)
            'contextsFromPackagesFiles': contextsFromPackagesFiles,
          if (contextsWithoutFiles != null)
            'contextsWithoutFiles': contextsWithoutFiles,
          if (immediateFileCount != null)
            'immediateFileCount': immediateFileCount,
          if (immediateFileLineCount != null)
            'immediateFileLineCount': immediateFileLineCount,
          if (numberOfContexts != null) 'numberOfContexts': numberOfContexts,
          if (transitiveFileCount != null)
            'transitiveFileCount': transitiveFileCount,
          if (transitiveFileLineCount != null)
            'transitiveFileLineCount': transitiveFileLineCount,
          if (transitiveFileUniqueCount != null)
            'transitiveFileUniqueCount': transitiveFileUniqueCount,
          if (transitiveFileUniqueLineCount != null)
            'transitiveFileUniqueLineCount': transitiveFileUniqueLineCount,
        };

  Event.hotReloadTime({int? timeMs})
      : eventName = DashEvent.hotReloadTime,
        eventData = {if (timeMs != null) 'timeMs': timeMs};

  Event.lintUsageCounts({String? usageCounts})
      : eventName = DashEvent.lintUsageCounts,
        eventData = {
          if (usageCounts != null) 'usageCounts': usageCounts,
        };

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

  Event.pluginRequest({
    String? duration,
    String? method,
    String? pluginId,
  })  : eventName = DashEvent.pluginRequest,
        eventData = {
          if (duration != null) 'duration': duration,
          if (method != null) 'method': method,
          if (pluginId != null) 'pluginId': pluginId,
        };

  Event.serverSession({
    String? clientId,
    String? clientVersion,
    int? duration,
    String? flags,
    String? parameters,
    String? plugins,
  })  : eventName = DashEvent.serverSession,
        eventData = {
          if (clientId != null) 'clientId': clientId,
          if (clientVersion != null) 'clientVersion': clientVersion,
          if (duration != null) 'duration': duration,
          if (flags != null) 'flags': flags,
          if (parameters != null) 'parameters': parameters,
          if (plugins != null) 'plugins': plugins,
        };

  Event.severityAdjustments({String? adjustmentCounts})
      : eventName = DashEvent.severityAdjustments,
        eventData = {
          if (adjustmentCounts != null) 'adjustmentCounts': adjustmentCounts,
        };
}
