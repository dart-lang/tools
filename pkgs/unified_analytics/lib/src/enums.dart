// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Values for the event name to be sent to Google Analytics
///
/// The [label] for each enum value is what will be logged, the [description]
/// is here for documentation purposes
enum DashEvent {
  // Events that can be sent by all tools; these
  // events should not be tool specific; toolOwner
  // not necessary for these events
  analyticsCollectionEnabled(
    label: 'analytics_collection_enabled',
    description: 'The opt-in status for analytics collection',
  ),

  // Events for flutter_tools
  hotReloadTime(
    label: 'hot_reload_time',
    description: 'Hot reload duration',
    toolOwner: DashTool.flutterTools,
  ),

  // Events for language_server
  clientNotification(
    label: 'client_notification',
    description: 'Notifications sent from the client',
    toolOwner: DashTool.languageServer,
  ),
  clientRequest(
    label: 'client_request',
    description: 'Requests sent from the client',
    toolOwner: DashTool.languageServer,
  ),
  contextStructure(
    label: 'context_structure',
    description: 'Structure of the analysis contexts being analyzed',
    toolOwner: DashTool.languageServer,
  ),
  lintUsageCounts(
    label: 'lint_usage_counts',
    description: 'Number of times each lint is enabled',
    toolOwner: DashTool.languageServer,
  ),
  pluginRequest(
    label: 'plugin_request',
    description: 'Request responses from plugins',
    toolOwner: DashTool.languageServer,
  ),
  serverSession(
    label: 'server_session',
    description: 'Dart Analyzer Server session data',
    toolOwner: DashTool.languageServer,
  ),
  severityAdjustments(
    label: 'severity_adjustments',
    description: 'Number of times diagnostic severity is changed',
    toolOwner: DashTool.languageServer,
  ),
  ;

  final String label;
  final String description;
  final DashTool? toolOwner;
  const DashEvent({
    required this.label,
    required this.description,
    this.toolOwner,
  });
}

/// Officially-supported clients of this package.
///
/// All [label] values should use an underscore as a delimiter.
enum DashTool {
  dartTools(
    label: 'dart_tools',
    description: 'A CLI for Dart development',
  ),
  flutterTools(
    label: 'flutter_tools',
    description: 'Runs flutter applications from CLI',
  ),
  languageServer(
    label: 'language_server',
    description: 'The Dart language server for IDE and CLI support.',
  );

  final String label;
  final String description;
  const DashTool({
    required this.label,
    required this.description,
  });
}

/// Enumerate options for platform
enum DevicePlatform {
  windows('Windows'),
  macos('macOS'),
  linux('Linux'),
  ;

  final String label;
  const DevicePlatform(this.label);
}
