// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:http/http.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meta/meta.dart';
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
  // TODO: (eliasyishak) enable again once revision has landed;
  //  also remove all instances of [pddFlag]

  // /// The default factory constructor that will return an implementation
  // /// of the [Analytics] abstract class using the [LocalFileSystem]
  // factory Analytics({
  //   required DashTool tool,
  //   required String dartVersion,
  //   String? flutterChannel,
  //   String? flutterVersion,
  // }) {
  //   // Create the instance of the file system so clients don't need
  //   // resolve on their own
  //   const FileSystem fs = LocalFileSystem();

  //   // Resolve the OS using dart:io
  //   final DevicePlatform platform;
  //   if (io.Platform.operatingSystem == 'linux') {
  //     platform = DevicePlatform.linux;
  //   } else if (io.Platform.operatingSystem == 'macos') {
  //     platform = DevicePlatform.macos;
  //   } else {
  //     platform = DevicePlatform.windows;
  //   }

  //   // Create the instance of the GA Client which will create
  //   // an [http.Client] to send requests
  //   final GAClient gaClient = GAClient(
  //     measurementId: kGoogleAnalyticsMeasurementId,
  //     apiSecret: kGoogleAnalyticsApiSecret,
  //   );

  //   return AnalyticsImpl(
  //     tool: tool,
  //     homeDirectory: getHomeDirectory(fs),
  //     flutterChannel: flutterChannel,
  //     flutterVersion: flutterVersion,
  //     dartVersion: dartVersion,
  //     platform: platform,
  //     toolsMessageVersion: kToolsMessageVersion,
  //     fs: fs,
  //     gaClient: gaClient,
  //   );
  // }

  // TODO: (eliasyishak) remove this contructor once revision has landed

  /// Prevents the unapproved files for logging and session handling
  /// from being saved on to the developer's disk until privacy revision
  /// has landed
  factory Analytics({
    required DashTool tool,
    required String dartVersion,
    String? flutterChannel,
    String? flutterVersion,
    FileSystem? fsOverride,
    Directory? homeOverride,
    DevicePlatform? platformOverride,
  }) {
    // Create the instance of the file system so clients don't need
    // resolve on their own
    final FileSystem fs = fsOverride ?? LocalFileSystem();

    // Resolve the OS using dart:io
    final DevicePlatform platform;
    if (io.Platform.operatingSystem == 'linux') {
      platform = DevicePlatform.linux;
    } else if (io.Platform.operatingSystem == 'macos') {
      platform = DevicePlatform.macos;
    } else {
      platform = DevicePlatform.windows;
    }

    // Create the instance of the GA Client which will create
    // an [http.Client] to send requests
    //
    // When a [fsOverride] is passed in, we can assume to
    // use the fake Google Analytics client
    final GAClient gaClient = fsOverride != null
        ? FakeGAClient()
        : GAClient(
            measurementId: kGoogleAnalyticsMeasurementId,
            apiSecret: kGoogleAnalyticsApiSecret,
          );

    return AnalyticsImpl(
      tool: tool,
      homeDirectory: homeOverride ?? getHomeDirectory(fs),
      flutterChannel: flutterChannel,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      platform: platformOverride ?? platform,
      toolsMessageVersion: kToolsMessageVersion,
      fs: fs,
      gaClient: gaClient,
      pddFlag: true,
    );
  }

  /// Factory constructor to return the [AnalyticsImpl] class with
  /// Google Analytics credentials that point to a test instance and
  /// not the production instance where live data will be sent
  factory Analytics.development({
    required DashTool tool,
    required String dartVersion,
    String? flutterChannel,
    String? flutterVersion,
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

    // Credentials defined below for the test Google Analytics instance
    const String kTestMeasurementId = 'G-N1NXG28J5B';
    const String kTestApiSecret = '4yT8__oER3Cd84dtx6r-_A';

    // Create the instance of the GA Client which will create
    // an [http.Client] to send requests
    final GAClient gaClient = GAClient(
      measurementId: kTestMeasurementId,
      apiSecret: kTestApiSecret,
    );

    return AnalyticsImpl(
      tool: tool,
      homeDirectory: getHomeDirectory(fs),
      flutterChannel: flutterChannel,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      platform: platform,
      toolsMessageVersion: kToolsMessageVersion,
      fs: fs,
      gaClient: gaClient,
    );
  }

  /// Factory constructor to return the [AnalyticsImpl] class with a
  /// [MemoryFileSystem] to use for testing
  @visibleForTesting
  factory Analytics.test({
    required DashTool tool,
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
        flutterChannel: flutterChannel,
        toolsMessageVersion: toolsMessageVersion,
        flutterVersion: flutterVersion,
        dartVersion: dartVersion,
        platform: platform,
        fs: fs ??
            MemoryFileSystem.test(
              style: io.Platform.isWindows
                  ? FileSystemStyle.windows
                  : FileSystemStyle.posix,
            ),
        gaClient: FakeGAClient(),
      );

  /// Retrieves the consent message to prompt users with on first
  /// run or when the message has been updated
  String get getConsentMessage;

  /// Returns true if it is OK to send an analytics message.   Do not cache,
  /// as this depends on factors that can change, such as the configuration
  /// file contents.
  bool get okToSend;

  /// Returns a map object with all of the tools that have been parsed
  /// out of the configuration file
  Map<String, ToolInfo> get parsedTools;

  /// Boolean that lets the client know if they should display the message
  bool get shouldShowMessage;

  /// Boolean indicating whether or not telemetry is enabled
  bool get telemetryEnabled;

  /// Returns a map representation of the [UserProperty] for the [Analytics] instance
  ///
  /// This is what will get sent to Google Analytics with every request
  Map<String, Map<String, Object?>> get userPropertyMap;

  /// Method to be invoked by the client using this package to confirm
  /// that the client has shown the message and that it can be added to
  /// the config file and start sending events the next time it starts up
  void clientShowedMessage();

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
    Map<String, Object?> eventData = const {},
  });

  /// Pass a boolean to either enable or disable telemetry and make
  /// the necessary changes in the persisted configuration file
  ///
  /// Setting the telemetry status will also send an event to GA
  /// indicating the latest status of the telemetry from [reportingBool]
  Future<void> setTelemetry(bool reportingBool);
}

class AnalyticsImpl implements Analytics {
  final DashTool tool;
  final FileSystem fs;
  late final ConfigHandler _configHandler;
  final GAClient _gaClient;
  late final String _clientId;
  late final UserProperty userProperty;
  late final LogHandler _logHandler;
  final int toolsMessageVersion;

  /// Tells the client if they need to show a message to the
  /// user; this will return true if it is the first time the
  /// package is being used for a developer or if the consent
  /// message has been updated by the package
  late bool _showMessage;

  /// This will be switch to true once it has been confirmed by the
  /// client using this package that they have shown this message
  /// to the developer
  ///
  /// If the tool using this package as already shown the consent message
  /// and it has been added to the config file, it will be set as true
  ///
  /// It will also be set to true once the tool using this package has
  /// invoked [clientShowedMessage]
  ///
  /// If this is false, all events will be blocked from being sent
  bool _clientShowedMessage = false;

  AnalyticsImpl({
    required this.tool,
    required Directory homeDirectory,
    String? flutterChannel,
    String? flutterVersion,
    required String dartVersion,
    required DevicePlatform platform,
    required this.toolsMessageVersion,
    required this.fs,
    required gaClient,
    bool pddFlag = false,
  }) : _gaClient = gaClient {
    // Initialize date formatting for `package:intl` within constructor
    // so clients using this package won't need to
    initializeDateFormatting();

    // This initializer class will let the instance know
    // if it was the first run; if it is, nothing will be sent
    // on the first run
    final Initializer initializer = Initializer(
      fs: fs,
      tool: tool.label,
      homeDirectory: homeDirectory,
      toolsMessageVersion: toolsMessageVersion,
      pddFlag: pddFlag,
    );
    initializer.run();
    _showMessage = initializer.firstRun;

    // Create the config handler that will parse the config file
    _configHandler = ConfigHandler(
      fs: fs,
      homeDirectory: homeDirectory,
      initializer: initializer,
    );

    // If the tool has already been added to the config file
    // we can assume that the client has successfully shown
    // the consent message
    if (_configHandler.parsedTools.containsKey(tool.label)) {
      _clientShowedMessage = true;
    }

    // Check if the tool has already been onboarded, and if it
    // has, check if the latest message version is greater to
    // prompt the client to show a message
    //
    // If the tool has not been added to the config file, then
    // we will show the message as well
    final int currentVersion =
        _configHandler.parsedTools[tool.label]?.versionNumber ?? -1;
    if (currentVersion < toolsMessageVersion) {
      _showMessage = true;
    }

    _clientId = fs
        .file(p.join(
            homeDirectory.path, kDartToolDirectoryName, kClientIdFileName))
        .readAsStringSync();

    // Create the session instance that will be responsible for managing
    // all the sessions across every client tool using this pakage
    final Session session;
    if (pddFlag) {
      session = NoopSession();
    } else {
      session = Session(homeDirectory: homeDirectory, fs: fs);
    }

    // Initialize the user property class that will be attached to
    // each event that is sent to Google Analytics -- it will be responsible
    // for getting the session id or rolling the session if the duration
    // exceeds [kSessionDurationMinutes]
    userProperty = UserProperty(
      session: session,
      flutterChannel: flutterChannel,
      host: platform.label,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      tool: tool.label,
    );

    // Initialize the log handler to persist events that are being sent
    if (pddFlag) {
      _logHandler = NoopLogHandler();
    } else {
      _logHandler = LogHandler(fs: fs, homeDirectory: homeDirectory);
    }
  }

  @override
  String get getConsentMessage =>
      kToolsMessage.replaceAll('[tool name]', tool.description);

  /// Checking the [telemetryEnabled] boolean reflects what the
  /// config file reflects
  ///
  /// Checking the [_showMessage] boolean indicates if this the first
  /// time the tool is using analytics or if there has been an update
  /// the messaging found in constants.dart - in both cases, analytics
  /// will not be sent until the second time the tool is used
  ///
  /// Additionally, if the client has not invoked `clientShowedMessage`,
  /// then no events shall be sent.
  @override
  bool get okToSend =>
      telemetryEnabled && !_showMessage && _clientShowedMessage;

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
  void clientShowedMessage() {
    if (!_configHandler.parsedTools.containsKey(tool.label)) {
      _configHandler.addTool(
        tool: tool.label,
        versionNumber: toolsMessageVersion,
      );
      _showMessage = true;
    }
    if (_configHandler.parsedTools[tool.label]!.versionNumber <
        toolsMessageVersion) {
      _configHandler.incrementToolVersion(
        tool: tool.label,
        newVersionNumber: toolsMessageVersion,
      );
      _showMessage = true;
    }
    _clientShowedMessage = true;
  }

  @override
  void close() => _gaClient.close();

  @override
  LogFileStats? logFileStats() => _logHandler.logFileStats();

  @override
  Future<Response>? sendEvent({
    required DashEvent eventName,
    Map<String, Object?> eventData = const {},
  }) {
    if (!okToSend) return null;

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
  Future<void> setTelemetry(bool reportingBool) {
    _configHandler.setTelemetry(reportingBool);

    // Construct the body of the request to signal
    // telemetry status toggling
    //
    // We use don't use the sendEvent method because it may
    // be blocked by the [telemetryEnabled] getter
    final Map<String, Object?> body = generateRequestBody(
      clientId: _clientId,
      eventName: DashEvent.analyticsCollectionEnabled,
      eventData: {'status': reportingBool},
      userProperty: userProperty,
    );

    _logHandler.save(data: body);

    // Pass to the google analytics client to send
    return _gaClient.sendData(body);
  }
}

/// An implementation that will never send events.
///
/// This is for clients that opt to either not send analytics, or will migrate
/// to use [AnalyticsImpl] at a later time.
class NoOpAnalytics implements Analytics {
  const NoOpAnalytics._();

  factory NoOpAnalytics() => const NoOpAnalytics._();

  @override
  final String getConsentMessage = '';

  @override
  final bool okToSend = false;

  @override
  final Map<String, ToolInfo> parsedTools = const <String, ToolInfo>{};

  @override
  final bool shouldShowMessage = false;

  @override
  final bool telemetryEnabled = false;

  @override
  final Map<String, Map<String, Object?>> userPropertyMap =
      const <String, Map<String, Object?>>{};

  @override
  void clientShowedMessage() {}

  @override
  void close() {}

  @override
  LogFileStats? logFileStats() => null;

  @override
  Future<Response>? sendEvent({
    required DashEvent eventName,
    Map<String, Object?> eventData = const {},
  }) =>
      null;

  @override
  Future<void> setTelemetry(bool reportingBool) async {}
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
    super.flutterChannel,
    super.flutterVersion,
    required super.dartVersion,
    required super.platform,
    required super.toolsMessageVersion,
    required super.fs,
    required super.gaClient,
  });

  @override
  Future<Response>? sendEvent({
    required DashEvent eventName,
    Map<String, Object?> eventData = const {},
  }) {
    if (!okToSend) return null;

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
