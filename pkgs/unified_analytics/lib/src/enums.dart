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
    toolOwner: DashTool.flutterTool,
  ),

  // Events for language_server
  clientNotification(
    label: 'client_notification',
    description: 'Notifications sent from the client',
  ),
  clientRequest(
    label: 'client_request',
    description: 'Requests sent from the client',
  ),
  contextStructure(
    label: 'context_structure',
    description: 'Structure of the analysis contexts being analyzed',
  ),
  lintUsageCounts(
    label: 'lint_usage_counts',
    description: 'Number of times each lint is enabled',
  ),
  pluginRequest(
    label: 'plugin_request',
    description: 'Request responses from plugins',
  ),
  serverSession(
    label: 'server_session',
    description: 'Dart Analyzer Server session data',
  ),
  severityAdjustments(
    label: 'severity_adjustments',
    description: 'Number of times diagnostic severity is changed',
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

/// Officially-supported clients of this package as logical
/// tools, grouped by user point of view.  Derived directly
/// from the PDD.
enum DashTool {
  androidStudioPlugins(
    label: 'android-studio-plugins',
    description: 'Android Studio IDE plugins for Dart and Flutter',
  ),
  dartTool(
    label: 'dart-tool',
    description: 'Dart CLI developer tool',
  ),
  @Deprecated('From a prerelease version of analytics; do not use.')
  dartTools(
    label: 'dart_tools',
    description: 'A CLI for Dart development',
  ),
  devtools(
    label: 'devtools',
    description: 'DevTools debugging and performance tools',
  ),
  flutterTool(
    label: 'flutter-tool',
    description: 'Flutter CLI developer tool',
  ),
  @Deprecated('From a prerelease version of analytics; do not use.')
  flutterTools(
    label: 'flutter_tools',
    description: 'Runs flutter applications from CLI',
  ),
  intellijPlugins(
    label: 'intellij-plugins',
    description: 'IntelliJ IDE plugins for Dart and Flutter',
  ),
  vscodePlugins(
    label: 'vscode-plugins',
    description: 'VS Code IDE plugins for Dart and Flutter',
  );

  /// String used as the control flag and the value of the tool key in
  /// analytics.
  final String label;

  /// The "notice string", a human-readable description of the logical tool
  /// grouping.
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
