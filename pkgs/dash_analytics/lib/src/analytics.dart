// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as p;

import 'config_handler.dart';
import 'constants.dart';
import 'enums.dart';
import 'ga_client.dart';
import 'initializer.dart';
import 'log_handler.dart';
import 'session.dart';
import 'user_property.dart';
import 'utils.dart';

abstract class Analytics {
  /// The default factory constructor that will return an implementation
  /// of the [Analytics] abstract class using the [LocalFileSystem]
  factory Analytics({
    required DashTool tool,
    required String measurementId,
    required String apiSecret,
    String? flutterChannel,
    String? flutterVersion,
    required String dartVersion,
  }) {
    // Create the instance of the file system so clients don't need
    // resolve on their own
    const FileSystem fs = LocalFileSystem();

    // Resolve the OS using dart:io
    final DevicePlatform platform;
    if (io.Platform.operatingSystem == 'linux') {
      platform = DevicePlatform.linux;
    } else if (io.Platform.operatingSystem == 'macos') {
      platform = DevicePlatform.macos;
    } else {
      platform = DevicePlatform.windows;
    }

    return AnalyticsImpl(
      tool: tool.label,
      homeDirectory: getHomeDirectory(fs),
      measurementId: measurementId,
      apiSecret: apiSecret,
      flutterChannel: flutterChannel,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      platform: platform,
      toolsMessage: kToolsMessage,
      toolsMessageVersion: kToolsMessageVersion,
      fs: fs,
    );
  }

  /// Factory constructor to return the [AnalyticsImpl] class with a
  /// [MemoryFileSystem] to use for testing
  factory Analytics.test({
    required String tool,
    required Directory homeDirectory,
    required String measurementId,
    required String apiSecret,
    String? flutterChannel,
    String? flutterVersion,
    required String dartVersion,
    int toolsMessageVersion = kToolsMessageVersion,
    String toolsMessage = kToolsMessage,
    FileSystem? fs,
    required DevicePlatform platform,
  }) =>
      TestAnalytics(
        tool: tool,
        homeDirectory: homeDirectory,
        measurementId: measurementId,
        apiSecret: apiSecret,
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        toolsMessage: toolsMessage,
        flutterVersion: flutterVersion,
        dartVersion: dartVersion,
        platform: platform,
        fs: fs ??
            MemoryFileSystem.test(
              style: io.Platform.isWindows
                  ? FileSystemStyle.windows
                  : FileSystemStyle.posix,
            ),
      );

  /// Returns a map object with all of the tools that have been parsed
  /// out of the configuration file
  Map<String, ToolInfo> get parsedTools;

  /// Boolean that lets the client know if they should display the message
  bool get shouldShowMessage;

  /// Boolean indicating whether or not telemetry is enabled
  bool get telemetryEnabled;

  /// Returns the message that should be displayed to the users if
  /// [shouldShowMessage] returns true
  String get toolsMessage;

  /// Returns a map representation of the [UserProperty] for the [Analytics] instance
  ///
  /// This is what will get sent to Google Analytics with every request
  Map<String, Map<String, Object?>> get userPropertyMap;

  /// Call this method when the tool using this package is closed
  ///
  /// Prevents the tool from hanging when if there are still requests
  /// that need to be sent off
  void close();

  /// Query the persisted event data stored on the user's machine
  ///
  /// Returns null if there are no persisted logs
  LogFileStats? logFileStats();

  /// API to send events to Google Analytics to track usage
  Future<Response>? sendEvent({
    required DashEvent eventName,
    required Map<String, Object?> eventData,
  });

  /// Pass a boolean to either enable or disable telemetry and make
  /// the necessary changes in the persisted configuration file
  Future<void> setTelemetry(bool reportingBool);
}

class AnalyticsImpl implements Analytics {
  final FileSystem fs;
  late final ConfigHandler _configHandler;
  late bool _showMessage;
  late final GAClient _gaClient;
  late final String _clientId;
  late final UserProperty userProperty;
  late final LogHandler _logHandler;

  @override
  final String toolsMessage;

  AnalyticsImpl({
    required String tool,
    required Directory homeDirectory,
    required String measurementId,
    required String apiSecret,
    String? flutterChannel,
    String? flutterVersion,
    required String dartVersion,
    required DevicePlatform platform,
    required this.toolsMessage,
    required int toolsMessageVersion,
    required this.fs,
  }) {
    // This initializer class will let the instance know
    // if it was the first run; if it is, nothing will be sent
    // on the first run
    final Initializer initializer = Initializer(
      fs: fs,
      tool: tool,
      homeDirectory: homeDirectory,
      toolsMessageVersion: toolsMessageVersion,
      toolsMessage: toolsMessage,
    );
    initializer.run();
    _showMessage = initializer.firstRun;

    // Create the config handler that will parse the config file
    _configHandler = ConfigHandler(
      fs: fs,
      homeDirectory: homeDirectory,
      initializer: initializer,
    );

    // Initialize the config handler class and check if the
    // tool message and version have been updated from what
    // is in the current file; if there is a new message version
    // make the necessary updates
    if (!_configHandler.parsedTools.containsKey(tool)) {
      _configHandler.addTool(tool: tool);
      _showMessage = true;
    }
    if (_configHandler.parsedTools[tool]!.versionNumber < toolsMessageVersion) {
      _configHandler.incrementToolVersion(tool: tool);
      _showMessage = true;
    }
    _clientId = fs
        .file(p.join(
            homeDirectory.path, kDartToolDirectoryName, kClientIdFileName))
        .readAsStringSync();

    // Create the instance of the GA Client which will create
    // an [http.Client] to send requests
    _gaClient = GAClient(
      measurementId: measurementId,
      apiSecret: apiSecret,
    );

    // Initialize the user property class that will be attached to
    // each event that is sent to Google Analytics -- it will be responsible
    // for getting the session id or rolling the session if the duration
    // exceeds [kSessionDurationMinutes]
    userProperty = UserProperty(
      session: Session(homeDirectory: homeDirectory, fs: fs),
      flutterChannel: flutterChannel,
      host: platform.label,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      tool: tool,
    );

    // Initialize the log handler to persist events that are being sent
    _logHandler = LogHandler(fs: fs, homeDirectory: homeDirectory);
  }

  @override
  Map<String, ToolInfo> get parsedTools => _configHandler.parsedTools;

  @override
  bool get shouldShowMessage => _showMessage;

  @override
  bool get telemetryEnabled => _configHandler.telemetryEnabled;

  @override
  Map<String, Map<String, Object?>> get userPropertyMap =>
      userProperty.preparePayload();

  @override
  void close() => _gaClient.close();

  @override
  LogFileStats? logFileStats() => _logHandler.logFileStats();

  @override
  Future<Response>? sendEvent({
    required DashEvent eventName,
    required Map<String, Object?> eventData,
  }) {
    if (!telemetryEnabled) return null;

    // Construct the body of the request
    final Map<String, Object?> body = generateRequestBody(
      clientId: _clientId,
      eventName: eventName,
      eventData: eventData,
      userProperty: userProperty,
    );

    _logHandler.save(data: body);

    // Pass to the google analytics client to send
    return _gaClient.sendData(body);
  }

  @override
  Future<void> setTelemetry(bool reportingBool) =>
      _configHandler.setTelemetry(reportingBool);
}

/// This class extends [AnalyticsImpl] and subs out any methods that
/// are not suitable for tests; the following have been altered from the
/// default implementation. All other methods are included
///
/// - `sendEvent(...)` has been altered to prevent data from being sent to GA
/// during testing
class TestAnalytics extends AnalyticsImpl {
  TestAnalytics({
    required super.tool,
    required super.homeDirectory,
    required super.measurementId,
    required super.apiSecret,
    super.flutterChannel,
    super.flutterVersion,
    required super.dartVersion,
    required super.platform,
    required super.toolsMessage,
    required super.toolsMessageVersion,
    required super.fs,
  });

  @override
  Future<Response>? sendEvent({
    required DashEvent eventName,
    required Map<String, Object?> eventData,
  }) {
    if (!telemetryEnabled) return null;

    // Calling the [generateRequestBody] method will ensure that the
    // session file is getting updated without actually making any
    // POST requests to Google Analytics
    final Map<String, Object?> body = generateRequestBody(
      clientId: _clientId,
      eventName: eventName,
      eventData: eventData,
      userProperty: userProperty,
    );

    _logHandler.save(data: body);

    return null;
  }
}
