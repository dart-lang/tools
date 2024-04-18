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

import 'asserts.dart';
import 'config_handler.dart';
import 'constants.dart';
import 'enums.dart';
import 'event.dart';
import 'ga_client.dart';
import 'initializer.dart';
import 'log_handler.dart';
import 'survey_handler.dart';
import 'user_property.dart';
import 'utils.dart';

abstract class Analytics {
  /// The default factory constructor that will return an implementation
  /// of the [Analytics] abstract class using the [LocalFileSystem].
  ///
  /// If [enableAsserts] is set to `true`, then asserts for GA4 limitations
  /// will be enabled.
  ///
  /// [flutterChannel] and [flutterVersion] are nullable in case the client
  /// using this package is unable to resolve those values.
  ///
  /// An optional parameter [clientIde] is also available for dart and flutter
  /// tooling that are running from IDEs can be resolved. Such as "VSCode"
  /// running the flutter-tool.
  ///
  /// [enabledFeatures] is also an optional field that can be added to collect
  /// any features that are enabled for a user. For example,
  /// "enable-linux-desktop,cli-animations" are two features that can be enabled
  /// for the flutter-tool.
  factory Analytics({
    required DashTool tool,
    required String dartVersion,
    String? flutterChannel,
    String? flutterVersion,
    String? clientIde,
    String? enabledFeatures,
    bool enableAsserts = false,
  }) {
    // Create the instance of the file system so clients don't need
    // resolve on their own
    const FileSystem fs = LocalFileSystem();

    // Ensure that the home directory has permissions enabled to write
    final homeDirectory = getHomeDirectory(fs);
    if (homeDirectory == null ||
        !checkDirectoryForWritePermissions(homeDirectory)) {
      return const NoOpAnalytics();
    }

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
    final gaClient = GAClient(
      measurementId: kGoogleAnalyticsMeasurementId,
      apiSecret: kGoogleAnalyticsApiSecret,
    );

    final firstRun = runInitialization(homeDirectory: homeDirectory, fs: fs);

    return AnalyticsImpl(
      tool: tool,
      homeDirectory: homeDirectory,
      flutterChannel: flutterChannel,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      platform: platform,
      toolsMessageVersion: kToolsMessageVersion,
      fs: fs,
      gaClient: gaClient,
      surveyHandler: SurveyHandler(
        dismissedSurveyFile: fs.file(p.join(
          homeDirectory.path,
          kDartToolDirectoryName,
          kDismissedSurveyFileName,
        )),
      ),
      enableAsserts: enableAsserts,
      clientIde: clientIde,
      enabledFeatures: enabledFeatures,
      firstRun: firstRun,
    );
  }

  /// Factory constructor to return the [AnalyticsImpl] class with
  /// Google Analytics credentials that point to a test instance and
  /// not the production instance where live data will be sent.
  ///
  /// By default, [enableAsserts] is set to `true` to check against
  /// GA4 limitations.
  ///
  /// [flutterChannel] and [flutterVersion] are nullable in case the client
  /// using this package is unable to resolve those values.
  factory Analytics.development({
    required DashTool tool,
    required String dartVersion,
    String? flutterChannel,
    String? flutterVersion,
    String? clientIde,
    String? enabledFeatures,
    bool enableAsserts = true,
  }) {
    // Create the instance of the file system so clients don't need
    // resolve on their own
    const FileSystem fs = LocalFileSystem();

    // Ensure that the home directory has permissions enabled to write
    final homeDirectory = getHomeDirectory(fs);
    if (homeDirectory == null) {
      throw Exception('Unable to determine the home directory, '
          'ensure it is available in the environment');
    }
    if (!checkDirectoryForWritePermissions(homeDirectory)) {
      throw Exception('Permissions error on the home directory!');
    }

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
    const kTestMeasurementId = 'G-N1NXG28J5B';
    const kTestApiSecret = '4yT8__oER3Cd84dtx6r-_A';

    // Create the instance of the GA Client which will create
    // an [http.Client] to send requests
    final gaClient = GAClient(
      measurementId: kTestMeasurementId,
      apiSecret: kTestApiSecret,
    );

    final firstRun = runInitialization(homeDirectory: homeDirectory, fs: fs);

    return AnalyticsImpl(
      tool: tool,
      homeDirectory: homeDirectory,
      flutterChannel: flutterChannel,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      platform: platform,
      toolsMessageVersion: kToolsMessageVersion,
      fs: fs,
      gaClient: gaClient,
      surveyHandler: SurveyHandler(
        dismissedSurveyFile: fs.file(p.join(
          homeDirectory.path,
          kDartToolDirectoryName,
          kDismissedSurveyFileName,
        )),
      ),
      enableAsserts: enableAsserts,
      clientIde: clientIde,
      enabledFeatures: enabledFeatures,
      firstRun: firstRun,
    );
  }

  /// The shared identifier for Flutter and Dart related tooling using
  /// package:unified_analytics.
  String get clientId;

  /// Retrieves the consent message to prompt users with on first
  /// run or when the message has been updated.
  String get getConsentMessage;

  /// Returns true if it is OK to send an analytics message. Do not cache,
  /// as this depends on factors that can change, such as the configuration
  /// file contents.
  bool get okToSend;

  /// Returns a map object with all of the tools that have been parsed
  /// out of the configuration file.
  Map<String, ToolInfo> get parsedTools;

  /// Boolean that lets the client know if they should display the message.
  bool get shouldShowMessage;

  /// Boolean indicating whether or not telemetry is enabled.
  bool get telemetryEnabled;

  /// Returns a map representation of the [UserProperty] for the [Analytics]
  /// instance.
  ///
  /// This is what will get sent to Google Analytics with every request.
  Map<String, Map<String, Object?>> get userPropertyMap;

  /// Method to be invoked by the client using this package to confirm
  /// that the client has shown the message and that it can be added to
  /// the config file and start sending events the next time it starts up.
  void clientShowedMessage();

  /// Call this method when the tool using this package is closed.
  ///
  /// Prevents the tool from hanging when if there are still requests
  /// that need to be sent off.
  ///
  /// Providing [delayDuration] in milliseconds will allow the instance
  /// to wait the provided time before closing the http connection. Keeping
  /// the connection open for some time will allow any pending events that
  /// are waiting to be sent to the Google Analytics server. Default value
  /// of 250 ms applied.
  Future<void> close({int delayDuration = kDelayDuration});

  /// Method to fetch surveys from the endpoint [kContextualSurveyUrl].
  ///
  /// Any survey that is returned by this method has already passed
  /// the survey conditions specified in the remote survey metadata file.
  ///
  /// If the method returns an empty list, then there are no surveys to be
  /// shared with the user.
  Future<List<Survey>> fetchAvailableSurveys();

  /// Query the persisted event data stored on the user's machine.
  ///
  /// Returns null if there are no persisted logs.
  LogFileStats? logFileStats();

  /// Send preconfigured events using specific named constructors
  /// on the [Event] class.
  ///
  /// Example
  /// ```dart
  /// analytics.send(Event.memory(periodSec: 123));
  /// ```
  void send(Event event);

  /// Pass a boolean to either enable or disable telemetry and make
  /// the necessary changes in the persisted configuration file.
  ///
  /// Setting the telemetry status will also send an event to GA
  /// indicating the latest status of the telemetry from [reportingBool].
  Future<void> setTelemetry(bool reportingBool);

  /// Calling this will result in telemetry collection being suppressed for
  /// the current invocation.
  ///
  /// If you would like to permanently disable telemetry
  /// collection use:
  ///
  /// ```dart
  /// analytics.setTelemetry(false)
  /// ```
  void suppressTelemetry();

  /// Method to run after interacting with a [Survey] instance.
  ///
  /// Pass a [Survey] instance which can be retrieved from
  /// [Analytics.fetchAvailableSurveys].
  ///
  /// [surveyButton] is the button that was interacted with by the user.
  void surveyInteracted({
    required Survey survey,
    required SurveyButton surveyButton,
  });

  /// Method to be called after a survey has been shown to the user.
  ///
  /// Calling this will snooze the survey so it won't be shown immediately.
  ///
  /// The snooze period is defined by the [Survey.snoozeForMinutes] field.
  void surveyShown(Survey survey);

  /// Returns an instance of [FakeAnalytics] which can be used in tests to check
  /// for certain [Event] instances within [FakeAnalytics.sentEvents].
  @visibleForTesting
  static FakeAnalytics fake({
    required DashTool tool,
    required Directory homeDirectory,
    required String dartVersion,
    required MemoryFileSystem fs,
    String? flutterChannel,
    String? flutterVersion,
    String? clientIde,
    String? enabledFeatures,
    SurveyHandler? surveyHandler,
    GAClient? gaClient,
    DevicePlatform platform = DevicePlatform.linux,
    int toolsMessageVersion = kToolsMessageVersion,
    String toolsMessage = kToolsMessage,
    bool enableAsserts = true,
  }) {
    final firstRun = runInitialization(homeDirectory: homeDirectory, fs: fs);

    return FakeAnalytics._(
      tool: tool,
      homeDirectory: homeDirectory,
      flutterChannel: flutterChannel,
      toolsMessageVersion: toolsMessageVersion,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
      platform: platform,
      fs: fs,
      surveyHandler: surveyHandler ??
          FakeSurveyHandler.fromList(
            dismissedSurveyFile: fs.file(p.join(
              homeDirectory.path,
              kDartToolDirectoryName,
              kDismissedSurveyFileName,
            )),
            initializedSurveys: [],
          ),
      gaClient: gaClient ?? const FakeGAClient(),
      clientIde: clientIde,
      enabledFeatures: enabledFeatures,
      firstRun: firstRun,
      enableAsserts: enableAsserts,
    );
  }
}

class AnalyticsImpl implements Analytics {
  final DashTool tool;
  final FileSystem fs;
  final int toolsMessageVersion;
  final ConfigHandler _configHandler;
  final GAClient _gaClient;
  final SurveyHandler _surveyHandler;
  final File _clientIdFile;
  final UserProperty _userProperty;
  final LogHandler _logHandler;

  /// Tells the client if they need to show a message to the
  /// user; this will return true if it is the first time the
  /// package is being used for a developer or if the consent
  /// message has been updated by the package.
  bool _showMessage = false;

  /// When set to `true`, various assert statements will be enabled
  /// to ensure usage of this class is within GA4 limitations.
  final bool _enableAsserts;

  /// Telemetry suppression flag that is set via [Analytics.suppressTelemetry].
  bool _telemetrySuppressed = false;

  /// Indicates if this is the first run for a given tool.
  bool _firstRun = false;

  /// The list of futures that will contain all of the send events
  /// from the [GAClient].
  final _futures = <Future<Response>>[];

  /// Internal value for the client id which will be lazily loaded.
  String? _clientId;

  /// Internal collection of [Event]s that have been sent
  /// for errors encountered within package:unified_analytics.
  ///
  /// Stores each of the events that have been sent to GA4 so that the
  /// same error doesn't get sent twice.
  final Set<Event> _sentErrorEvents = {};

  AnalyticsImpl({
    required this.tool,
    required Directory homeDirectory,
    required String? flutterChannel,
    required String? flutterVersion,
    required String? clientIde,
    required String? enabledFeatures,
    required String dartVersion,
    required DevicePlatform platform,
    required this.toolsMessageVersion,
    required this.fs,
    required GAClient gaClient,
    required SurveyHandler surveyHandler,
    required bool enableAsserts,
    required bool firstRun,
  })  : _gaClient = gaClient,
        _surveyHandler = surveyHandler,
        _enableAsserts = enableAsserts,
        _clientIdFile = fs.file(p.join(
          homeDirectory.path,
          kDartToolDirectoryName,
          kClientIdFileName,
        )),
        _userProperty = UserProperty(
          sessionFile: fs.file(p.join(
            homeDirectory.path,
            kDartToolDirectoryName,
            kSessionFileName,
          )),
          flutterChannel: flutterChannel,
          host: platform.label,
          flutterVersion: flutterVersion,
          dartVersion: dartVersion,
          tool: tool.label,
          // We truncate this to a maximum of 36 characters since this can
          // a very long string for some operating systems
          hostOsVersion:
              truncateStringToLength(io.Platform.operatingSystemVersion, 36),
          locale: io.Platform.localeName,
          clientIde: clientIde,
          enabledFeatures: enabledFeatures,
        ),
        _configHandler = ConfigHandler(
          fs: fs,
          homeDirectory: homeDirectory,
          configFile: fs.file(p.join(
            homeDirectory.path,
            kDartToolDirectoryName,
            kConfigFileName,
          )),
        ),
        _logHandler = LogHandler(
          logFile: fs.file(p.join(
            homeDirectory.path,
            kDartToolDirectoryName,
            kLogFileName,
          )),
        ) {
    // Initialize date formatting for `package:intl` within constructor
    // so clients using this package won't need to
    initializeDateFormatting();

    // This initializer class will let the instance know
    // if it was the first run; if it is, nothing will be sent
    // on the first run
    if (firstRun) {
      _showMessage = true;
      _firstRun = true;
    } else {
      _showMessage = false;
      _firstRun = false;
    }

    // Check if the tool has already been onboarded, and if it
    // has, check if the latest message version is greater to
    // prompt the client to show a message
    //
    // If the tool has not been added to the config file, then
    // we will show the message as well
    final currentVersion =
        _configHandler.parsedTools[tool.label]?.versionNumber ?? -1;
    if (currentVersion < toolsMessageVersion) {
      _showMessage = true;

      // If the message version has been updated, it will be considered
      // as if it was a first run and any events attempting to get sent
      // will be blocked
      _firstRun = true;
    }
  }

  @override
  String get clientId {
    if (!_clientIdFile.existsSync()) {
      createClientIdFile(clientIdFile: _clientIdFile);
    }
    _clientId ??= _clientIdFile.readAsStringSync();

    return _clientId!;
  }

  @override
  String get getConsentMessage {
    // The command to swap in the consent message
    final commandString =
        tool == DashTool.flutterTool || tool == DashTool.devtools
            ? 'flutter'
            : 'dart';

    return kToolsMessage
        .replaceAll('{{ toolDescription }}', tool.description)
        .replaceAll('{{ toolName }}', commandString);
  }

  /// Checking the [telemetryEnabled] boolean reflects what the
  /// config file reflects.
  ///
  /// Checking the [_showMessage] boolean indicates if the consent
  /// message has been shown for the user, this boolean is set to `true`
  /// when the tool using this package invokes the [clientShowedMessage]
  /// method.
  ///
  /// If the user has suppressed telemetry [_telemetrySuppressed] will
  /// return `true` to prevent events from being sent for current invocation.
  ///
  /// Checking if it is the first time a tool is running with this package
  /// as indicated by [_firstRun].
  @override
  bool get okToSend =>
      telemetryEnabled && !_showMessage && !_telemetrySuppressed && !_firstRun;

  @override
  Map<String, ToolInfo> get parsedTools => _configHandler.parsedTools;

  @override
  bool get shouldShowMessage => _showMessage;

  @override
  bool get telemetryEnabled => _configHandler.telemetryEnabled;

  @override
  Map<String, Map<String, Object?>> get userPropertyMap =>
      _userProperty.preparePayload();

  @override
  void clientShowedMessage() {
    // Check the tool needs to be added to the config file
    if (!_configHandler.parsedTools.containsKey(tool.label)) {
      _configHandler.addTool(
        tool: tool.label,
        versionNumber: toolsMessageVersion,
      );
    }

    // When the tool already exists but the consent message version
    // has been updated
    if (_configHandler.parsedTools[tool.label]!.versionNumber <
        toolsMessageVersion) {
      _configHandler.incrementToolVersion(
        tool: tool.label,
        newVersionNumber: toolsMessageVersion,
      );
    }
    _showMessage = false;
  }

  @override
  Future<void> close({int delayDuration = kDelayDuration}) async {
    // Collect any errors encountered and send
    _sendPendingErrorEvents();

    await Future.wait(_futures).timeout(
      Duration(milliseconds: delayDuration),
      onTimeout: () => [],
    );
    _gaClient.close();
  }

  @override
  Future<List<Survey>> fetchAvailableSurveys() async {
    final surveysToShow = <Survey>[];
    if (!okToSend) return surveysToShow;

    final logFileStats = _logHandler.logFileStats();

    // Call for surveys that have already been dismissed from
    // persisted survey ids on disk
    final persistedSurveyMap = _surveyHandler.fetchPersistedSurveys();

    for (final survey in await _surveyHandler.fetchSurveyList()) {
      // If the survey has listed the tool running this package in the exclude
      // list, it will not be returned
      if (survey.excludeDashToolList.contains(tool)) continue;

      // Apply the survey's sample rate; if the generated value from
      // the client id and survey's uniqueId are less, it will not get
      // sent to the user
      if (survey.samplingRate < sampleRate(clientId, survey.uniqueId)) {
        continue;
      }

      // If the survey has been permanently dismissed or has temporarily
      // been snoozed, skip it
      if (surveySnoozedOrDismissed(survey, persistedSurveyMap)) continue;

      // Counter to check each survey condition, if all are met, then
      // this integer will be equal to the number of conditions in
      // [Survey.conditionList]
      var conditionsMet = 0;
      if (logFileStats != null) {
        for (final condition in survey.conditionList) {
          // Retrieve the value from the [LogFileStats] with
          // the label provided in the condtion
          final logFileStatsValue =
              logFileStats.getValueByString(condition.field);

          if (logFileStatsValue == null) continue;

          switch (condition.operatorString) {
            case '>=':
              if (logFileStatsValue >= condition.value) conditionsMet++;
            case '<=':
              if (logFileStatsValue <= condition.value) conditionsMet++;
            case '>':
              if (logFileStatsValue > condition.value) conditionsMet++;
            case '<':
              if (logFileStatsValue < condition.value) conditionsMet++;
            case '==':
              if (logFileStatsValue == condition.value) conditionsMet++;
            case '!=':
              if (logFileStatsValue != condition.value) conditionsMet++;
          }
        }
      }

      if (conditionsMet == survey.conditionList.length) {
        surveysToShow.add(survey);
      }
    }

    return surveysToShow;
  }

  @override
  LogFileStats? logFileStats() => _logHandler.logFileStats();

  @override
  void send(Event event) {
    if (!okToSend) return;

    // Construct the body of the request
    final body = generateRequestBody(
      clientId: clientId,
      eventName: event.eventName,
      eventData: event.eventData,
      userProperty: _userProperty,
    );

    if (_enableAsserts) checkBody(body);

    _logHandler.save(data: body);

    final gaClientFuture = _gaClient.sendData(body);
    _futures.add(gaClientFuture);
    gaClientFuture.whenComplete(() => _futures.remove(gaClientFuture));
  }

  @override
  Future<void> setTelemetry(bool reportingBool) {
    _configHandler.setTelemetry(reportingBool);

    // Creation of the [Event] for opting out
    final collectionEvent =
        Event.analyticsCollectionEnabled(status: reportingBool);

    // The body of the request that will be sent to GA4
    final Map<String, Object?> body;

    if (reportingBool) {
      // Recreate the session and client id file; no need to
      // recreate the log file since it will only receives events
      // to persist from events sent
      createClientIdFile(clientIdFile: _clientIdFile);
      createSessionFile(sessionFile: _userProperty.sessionFile);

      // Reread the client ID string so an empty string is not being
      // sent to GA4 since the persisted files are cleared when a user
      // decides to opt out of telemetry collection
      _clientId = _clientIdFile.readAsStringSync();

      // We must construct the body at this point after we have read in the
      // new client id string that was generated
      body = generateRequestBody(
        clientId: clientId,
        eventName: collectionEvent.eventName,
        eventData: collectionEvent.eventData,
        userProperty: _userProperty,
      );

      _logHandler.save(data: body);
    } else {
      // Construct the body of the request to signal
      // telemetry status toggling
      body = generateRequestBody(
        clientId: clientId,
        eventName: collectionEvent.eventName,
        eventData: collectionEvent.eventData,
        userProperty: _userProperty,
      );

      // For opted out users, data in the persisted files is cleared
      _userProperty.sessionFile.writeAsStringSync('');
      _logHandler.logFile.writeAsStringSync('');
      _clientIdFile.writeAsStringSync('');

      _clientId = '';
    }

    // Pass to the google analytics client to send with a
    // timeout incase http clients hang
    return _gaClient.sendData(body).timeout(
          const Duration(milliseconds: kDelayDuration),
          onTimeout: () => Response('', 200),
        );
  }

  @override
  void suppressTelemetry() => _telemetrySuppressed = true;

  @override
  void surveyInteracted({
    required Survey survey,
    required SurveyButton surveyButton,
  }) {
    // Any action, except for 'snooze' will permanently dismiss a given survey
    final permanentlyDismissed = surveyButton.action == 'snooze' ? false : true;
    _surveyHandler.dismiss(survey, permanentlyDismissed);
    send(Event.surveyAction(
      surveyId: survey.uniqueId,
      status: surveyButton.action,
    ));
  }

  @override
  void surveyShown(Survey survey) {
    _surveyHandler.dismiss(survey, false);
    send(Event.surveyShown(surveyId: survey.uniqueId));
  }

  /// Send any pending error events, useful for tests to avoid closing
  /// the connection.
  ///
  /// In the main implementation, [AnalyticsImpl], error events are only
  /// sent on exit when [close] is invoked. This helper method can instead
  /// have those error events sent immediately to help with tests that check
  /// [FakeAnalytics.sentEvents].
  void _sendPendingErrorEvents() {
    // Collect any errors encountered and send
    final errorEvents = {..._userProperty.errorSet, ..._logHandler.errorSet};
    errorEvents
        .where((event) =>
            event.eventName == DashEvent.analyticsException &&
            !_sentErrorEvents.contains(event))
        .forEach(send);

    // Ensure the same event doesn't get sent again
    _sentErrorEvents.addAll(errorEvents);

    // Clear error sets
    _userProperty.errorSet.clear();
    _logHandler.errorSet.clear();
  }
}

/// This fake instance of [Analytics] is intended to be used by clients of
/// this package for testing purposes. It exposes a list [sentEvents] that
/// keeps track of all events that have been sent.
///
/// This is useful for confirming that events are being sent for a given
/// workflow. Invoking the [send] method on this instance will not make any
/// network requests to Google Analytics.
class FakeAnalytics extends AnalyticsImpl {
  /// Use this list to check for events that have been emitted when
  /// invoking the send method
  final List<Event> sentEvents = [];

  /// Class to use when you want to see which events were sent
  FakeAnalytics._({
    required super.tool,
    required super.homeDirectory,
    required super.dartVersion,
    required super.platform,
    required super.fs,
    required super.surveyHandler,
    required super.firstRun,
    super.flutterChannel,
    super.flutterVersion,
    super.clientIde,
    super.enabledFeatures,
    super.toolsMessageVersion = kToolsMessageVersion,
    super.gaClient = const FakeGAClient(),
    super.enableAsserts = true,
  });

  /// Getter to reference the private [UserProperty].
  UserProperty get userProperty => _userProperty;

  @override
  void send(Event event) {
    if (!okToSend) return;

    // Construct the body of the request
    final body = generateRequestBody(
      clientId: clientId,
      eventName: event.eventName,
      eventData: event.eventData,
      userProperty: _userProperty,
    );

    if (_enableAsserts) checkBody(body);

    _logHandler.save(data: body);

    // Using this list to validate that events are being sent
    // for internal methods in the `Analytics` instance
    sentEvents.add(event);
  }

  /// Public instance method to invoke private method that sends any
  /// pending error events.
  ///
  /// If this is never invoked, any pending error events will be sent
  /// when invoking the [close] method.
  void sendPendingErrorEvents() => _sendPendingErrorEvents();
}

/// An implementation that will never send events.
///
/// This is for clients that opt to either not send analytics, or will migrate
/// to use [AnalyticsImpl] at a later time.
class NoOpAnalytics implements Analytics {
  /// The hard-coded client ID value for each NoOp instance.
  static String get staticClientId => 'xxxx-xxxx';

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

  const NoOpAnalytics();

  @override
  String get clientId => staticClientId;

  @override
  void clientShowedMessage() {}

  @override
  Future<void> close({int delayDuration = kDelayDuration}) async {}

  @override
  Future<List<Survey>> fetchAvailableSurveys() async => const <Survey>[];

  @override
  LogFileStats? logFileStats() => null;

  @override
  Future<Response>? send(Event event) => null;

  @override
  Future<void> setTelemetry(bool reportingBool) async {}

  @override
  void suppressTelemetry() {}

  @override
  void surveyInteracted({
    required Survey survey,
    required SurveyButton surveyButton,
  }) {}

  @override
  void surveyShown(Survey survey) {}
}
