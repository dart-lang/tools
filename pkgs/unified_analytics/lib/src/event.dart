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

  /// Event that is emitted periodically to report the performance of the
  /// analysis server's handling of a specific kind of notification from the
  /// client.
  ///
  /// [duration] - json encoded percentile values indicating how long it took
  ///     from the time the server started handling the notification until the
  ///     server had finished handling the notification
  ///
  /// [latency] - json encoded percentile values indicating how long it took
  ///     from the time the notification was sent until the server started
  ///     handling it
  ///
  /// [method] - the name of the notification method that was sent
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

  /// Event that is emitted periodically to report the performance of the
  /// analysis server's handling of a specific kind of request from the client.
  ///
  /// [duration] - json encoded percentile values indicating how long it took
  ///     from the time the server started handling the request until the server
  ///     had send a response
  ///
  /// [latency] - json encoded percentile values indicating how long it took
  ///     from the time the request was sent until the server started handling
  ///     it
  ///
  /// [method] - the name of the request method that was sent
  ///
  /// If the method is `workspace/didChangeWorkspaceFolders`, then the following
  /// parameters should be included:
  ///
  /// [added] - json encoded percentile values indicating the number of folders
  ///     that were added
  ///
  /// [removed] - json encoded percentile values indicating the number of
  ///     folders that were removed
  ///
  /// If the method is `initialized`, then the following parameters should be
  /// included:
  ///
  /// [openWorkspacePaths] - json encoded percentile values indicating the
  ///     number of workspace paths that were opened
  ///
  /// If the method is `analysis.setAnalysisRoots`, then the following
  /// parameters should be included:
  ///
  /// [included] - json encoded percentile values indicating the number of
  ///     analysis roots in the included list
  ///
  /// [excluded] - json encoded percentile values indicating the number of
  ///     analysis roots in the excluded list
  ///
  /// If the method is `analysis.setPriorityFiles`, then the following
  /// parameters should be included:
  ///
  /// [files] - json encoded percentile values indicating the number of priority
  ///     files
  ///
  Event.clientRequest({
    String? added,
    required String duration,
    String? excluded,
    String? files,
    String? included,
    required String latency,
    required String method,
    String? openWorkspacePaths,
    String? removed,
  })  : eventName = DashEvent.clientRequest,
        eventData = {
          if (added != null) 'added': added,
          'duration': duration,
          if (excluded != null) 'excluded': excluded,
          if (files != null) 'files': files,
          if (included != null) 'included': included,
          'latency': latency,
          'method': method,
          if (openWorkspacePaths != null)
            'openWorkspacePaths': openWorkspacePaths,
          if (removed != null) 'removed': removed,
        };

  /// Event that is emitted periodically to report the number of times a given
  /// command has been executed.
  ///
  /// [count] - the number of times the command was executed
  ///
  /// [name] - the name of the command that was executed
  ///
  /// [flags] - the set of names for flags and options provided to the command.
  ///    Does not include values provided by users for options.
  ///
  /// [enabledExperiments] - the set of Dart language experiments enabled when
  ///    running the command.
  ///
  /// [exitCode] - the process exit code set as a result of running the command.
  Event.commandExecuted({
    required int count,
    required String name,
    List<String>? flags,
    List<String>? enabledExperiments,
    int? exitCode,
  })  : eventName = DashEvent.commandExecuted,
        eventData = {
          'count': count,
          'name': name,
          if (flags != null) 'flags': flags,
          if (enableExperiments != null)
            'enabledExperiments': enabledExperiments,
          if (exitCode != null) 'exitCode': exitCode,
        };

  /// Event that is emitted on shutdown to report the structure of the analysis
  /// contexts created immediately after startup.
  ///
  /// [contextsFromBothFiles] - the number of contexts that were created because
  ///     of both a package config and an analysis options file.
  ///
  /// [contextsFromOptionsFiles] - the number of contexts that were created
  ///     because of an analysis options file
  ///
  /// [contextsFromPackagesFiles] - the number of contexts that were created
  ///     because of a package config file
  ///
  /// [contextsWithoutFiles] - the number of contexts that were created because
  ///     of the lack of either a package config or an analysis options file.
  ///
  /// [immediateFileCount] - the number of files in one of the analysis contexts
  ///
  /// [immediateFileLineCount] - the number of lines in the immediate files
  ///
  /// [numberOfContexts] - the number of analysis context created
  ///
  /// [transitiveFileCount] - the number of files reachable from the files in
  ///     each analysis context, where files can be counted multiple times if
  ///     they are reachable from multiple contexts
  ///
  /// [transitiveFileLineCount] - the number of lines in the transitive files,
  ///     where files can be counted multiple times if they are reachable from
  ///     multiple contexts
  ///
  /// [transitiveFileUniqueCount] - the number of unique files reachable from
  ///     the files in each analysis context
  ///
  /// [transitiveFileUniqueLineCount] - the number of lines in the unique
  ///     transitive files
  Event.contextStructure({
    required int contextsFromBothFiles,
    required int contextsFromOptionsFiles,
    required int contextsFromPackagesFiles,
    required int contextsWithoutFiles,
    required int immediateFileCount,
    required int immediateFileLineCount,
    required int numberOfContexts,
    required int transitiveFileCount,
    required int transitiveFileLineCount,
    required int transitiveFileUniqueCount,
    required int transitiveFileUniqueLineCount,
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

  /// Event that is emitted periodically to report the number of times each lint
  /// has been enabled.
  ///
  /// [count] - the number of contexts in which the lint was enabled
  ///
  /// [name] - the name of the lint
  Event.lintUsageCount({
    required int count,
    required String name,
  })  : eventName = DashEvent.lintUsageCount,
        eventData = {
          'count': count,
          'name': name,
        };

  /// Event that is emitted periodically to report the amount of memory being
  /// used.
  ///
  /// [rss] - the resident set size in megabytes
  ///
  /// If this is not the first time memory has been reported for this session,
  /// then the following parameters should be included:
  ///
  /// [periodSec] - the number of seconds since the last memory usage data was
  ///     gathered
  ///
  /// [mbPerSec] - the number of megabytes of memory that were added or
  ///     subtracted per second since the last report
  Event.memoryInfo({
    required int rss,
    int? periodSec,
    double? mbPerSec,
  })  : eventName = DashEvent.memoryInfo,
        eventData = {
          'rss': rss,
          if (periodSec != null) 'periodSec': periodSec,
          if (mbPerSec != null) 'mbPerSec': mbPerSec
        };

  /// Event that is emitted periodically to report the performance of plugins
  /// when handling requests.
  ///
  /// [duration] - json encoded percentile values indicating how long it took
  ///     from the time the request was sent to the plugin until the response
  ///     was processed by the server
  ///
  /// [method] - the name of the request sent to the plugin
  ///
  /// [pluginId] - the id of the plugin whose performance is being reported
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

  /// Event that is emitted periodically to report the frequency with which a
  /// given plugin has been used.
  ///
  /// [count] - the number of times plugins usage was changed, which will always
  ///     be at least one
  ///
  /// [enabled] - json encoded percentile values indicating the number of
  ///     contexts for which the plugin was enabled
  ///
  /// [pluginId] - the id of the plugin associated with the data
  Event.pluginUse({
    required int count,
    required String enabled,
    required String pluginId,
  })  : eventName = DashEvent.pluginUse,
        eventData = {
          'count': count,
          'enabled': enabled,
          'pluginId': pluginId,
        };

  /// Event that is emitted on shutdown to report information about the whole
  /// session for which the analysis server was running.
  ///
  /// [clientId] - the id of the client that started the server
  ///
  /// [clientVersion] - the version of the client that started the server
  ///
  /// [duration] - the number of milliseconds for which the server was running
  ///
  /// [flags] - the flags passed to the analysis server on startup, without any
  ///     argument values for flags that take values, or an empty string if
  ///     there were no arguments
  ///
  /// [parameters] - the names of the parameters passed to the `initialize`
  ///     request, or an empty string if the `initialize` request was not sent
  ///     or if there were no parameters given
  Event.serverSession({
    required String clientId,
    required String clientVersion,
    required int duration,
    required String flags,
    required String parameters,
  })  : eventName = DashEvent.serverSession,
        eventData = {
          'clientId': clientId,
          'clientVersion': clientVersion,
          'duration': duration,
          'flags': flags,
          'parameters': parameters,
        };

  /// Event that is emitted periodically to report the number of times the
  /// severity of a diagnostic was changed in the analysis options file.
  ///
  /// [diagnostic] - the name of the diagnostic whose severity was changed
  ///
  /// [adjustments] - json encoded map of severities to the number of times the
  ///     diagnostic's severity was changed to the key
  Event.severityAdjustment({
    required String diagnostic,
    required String adjustments,
  })  : eventName = DashEvent.severityAdjustment,
        eventData = {
          'diagnostic': diagnostic,
          'adjustments': adjustments,
        };

  /// Event that is emitted when `pub get` is run.
  ///
  /// [packageName] - the name of the package that was resolved
  ///
  /// [version] - the resolved, canonicalized package version
  ///
  /// [dependencyKind] - the kind of dependency that resulted in this package
  ///     being resolved (e.g., direct, transitive, or dev dependencies).
  Event.pubGet({
    required String packageName,
    required String version,
    required String dependencyType,
  })  : eventName = DashEvent.pubGet,
        eventData = {
          'packageName': packageName,
          'version': version,
          'dependencyType': dependencyType,
        };
}
