// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'enums.dart';

final class Event {
  final DashEvent eventName;
  final Map<String, Object?> eventData;

  /// Event that is emitted whenever a user has opted in
  /// or out of the analytics collection
  /// 
  /// [status] - boolean value where `true` indicates user is opting in
  Event.analyticsCollectionEnabled({required bool status})
      : eventName = DashEvent.analyticsCollectionEnabled,
        eventData = {'status': status};

  Event.clientNotification({
    required String duration,
    required String latency,
    required String method,
  })  : eventName = DashEvent.clientNotification,
        eventData = {
          'duration': duration,
          'latency': latency,
          'method': method,
        };

  // TODO(eliasyishak): potential refactor for this event
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
    required String contextsFromBothFiles,
    required String contextsFromOptionsFiles,
    required String contextsFromPackagesFiles,
    required String contextsWithoutFiles,
    required String immediateFileCount,
    required String immediateFileLineCount,
    required String numberOfContexts,
    required String transitiveFileCount,
    required String transitiveFileLineCount,
    required String transitiveFileUniqueCount,
    required String transitiveFileUniqueLineCount,
  })  : eventName = DashEvent.contextStructure,
        eventData = {
          'contextsFromBothFiles': contextsFromBothFiles,
          'contextsFromOptionsFiles': contextsFromOptionsFiles,
          'contextsFromPackagesFiles': contextsFromPackagesFiles,
          'contextsWithoutFiles': contextsWithoutFiles,
          'immediateFileCount': immediateFileCount,
          'immediateFileLineCount': immediateFileLineCount,
          'numberOfContexts': numberOfContexts,
          'transitiveFileCount': transitiveFileCount,
          'transitiveFileLineCount': transitiveFileLineCount,
          'transitiveFileUniqueCount': transitiveFileUniqueCount,
          'transitiveFileUniqueLineCount': transitiveFileUniqueLineCount,
        };

  Event.hotReloadTime({required int timeMs})
      : eventName = DashEvent.hotReloadTime,
        eventData = {'timeMs': timeMs};

  Event.lintUsageCounts({required String usageCounts})
      : eventName = DashEvent.lintUsageCounts,
        eventData = {
          'usageCounts': usageCounts,
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
    required String duration,
    required String method,
    required String pluginId,
  })  : eventName = DashEvent.pluginRequest,
        eventData = {
          'duration': duration,
          'method': method,
          'pluginId': pluginId,
        };

  // TODO(eliasyishak): potential refactor for this event
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

  // TODO(eliasyishak): potential refactor for this event
  Event.severityAdjustments({String? adjustmentCounts})
      : eventName = DashEvent.severityAdjustments,
        eventData = {
          if (adjustmentCounts != null) 'adjustmentCounts': adjustmentCounts,
        };
}
