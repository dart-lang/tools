// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:unified_analytics/src/constants.dart';
import 'package:unified_analytics/src/enums.dart' show DashEvent;
import 'package:unified_analytics/src/ga_client.dart';
import 'package:unified_analytics/src/survey_handler.dart';
import 'package:unified_analytics/src/utils.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  final envVar = DashEnvVar.suppressAnalytics.name;

  group('areAnalyticsSuppressedIn', () {
    test('returns defaultValue when the variable is unset', () {
      expect(areAnalyticsSuppressedIn({}), isFalse);
      expect(areAnalyticsSuppressedIn({}, defaultValue: true), isTrue);
    });

    test('returns true for "true"', () {
      expect(areAnalyticsSuppressedIn({envVar: 'true'}), isTrue);
    });

    test('returns false for "false", even when defaultValue is true', () {
      expect(
        areAnalyticsSuppressedIn({envVar: 'false'}, defaultValue: true),
        isFalse,
      );
    });

    // Pins down the current strict parsing: anything other than exactly
    // "true" or "false" falls back to defaultValue.
    for (final value in ['TRUE', 'True', '1', 'yes', 'garbage', '']) {
      test('falls back to defaultValue for "$value"', () {
        expect(areAnalyticsSuppressedIn({envVar: value}), isFalse);
        expect(
          areAnalyticsSuppressedIn({envVar: value}, defaultValue: true),
          isTrue,
        );
      });
    }

    test('ignores unrelated variables', () {
      expect(areAnalyticsSuppressedIn({'OTHER': 'true'}), isFalse);
    });
  });

  group('Analytics with DASH__SUPPRESS_ANALYTICS', () {
    late MemoryFileSystem fs;
    late Directory home;

    final testEvent = Event.hotReloadTime(timeMs: 50);

    setUp(() {
      fs = MemoryFileSystem.test(
        style: io.Platform.isWindows
            ? FileSystemStyle.windows
            : FileSystemStyle.posix,
      );
      home = fs.directory('home');

      // Complete the first run and show the consent message so that later
      // instances would normally be allowed to send.
      createAnalytics({}).clientShowedMessage();
    });

    FakeAnalytics createAnalytics(
      Map<String, String> environment, {
      SurveyHandler? surveyHandler,
      GAClient? gaClient,
      bool isExternal = true,
    }) => Analytics.fake(
      tool: DashTool.flutterTool,
      homeDirectory: home,
      dartVersion: 'dartVersion',
      fs: fs,
      environment: environment,
      surveyHandler: surveyHandler,
      gaClient: gaClient,
      isExternal: isExternal,
    );

    final testSurvey = Survey(
      uniqueId: 'uniqueId',
      startDate: DateTime(2023, 1, 1),
      endDate: DateTime(2023, 12, 31),
      description: 'description',
      snoozeForMinutes: 10,
      samplingRate: 1.0,
      excludeDashToolList: const [],
      conditionList: const [],
      buttonList: const [],
    );

    SurveyHandler createSurveyHandler() => FakeSurveyHandler.fromList(
      dismissedSurveyFile: home
          .childDirectory(kDartToolDirectoryName)
          .childFile(kDismissedSurveyFileName),
      initializedSurveys: [testSurvey],
    );

    test('okToSend is true when the variable is unset', () {
      expect(createAnalytics(const {}).okToSend, isTrue);
    });

    test('okToSend is true when the variable is "false"', () {
      expect(createAnalytics({envVar: 'false'}).okToSend, isTrue);
    });

    test('okToSend is false when the variable is "true"', () {
      expect(createAnalytics({envVar: 'true'}).okToSend, isFalse);
    });

    test(
      'okToSend is false for internal builds when the variable is "true"',
      () {
        // Internal builds skip the consent and config checks, so the variable
        // is the only thing that can stop them from sending.
        expect(createAnalytics(const {}, isExternal: false).okToSend, isTrue);
        expect(
          createAnalytics({envVar: 'true'}, isExternal: false).okToSend,
          isFalse,
        );
      },
    );

    test('send records and logs nothing', () {
      final analytics = createAnalytics({envVar: 'true'});
      analytics.send(testEvent);

      expect(analytics.sentEvents, isEmpty);
      expect(analytics.logFileStats(), isNull);
    });

    test('send works normally when the variable is unset', () {
      final analytics = createAnalytics(const {});
      analytics.send(testEvent);

      expect(analytics.sentEvents, [testEvent]);
      expect(analytics.logFileStats(), isNotNull);
    });

    test('combines with suppressTelemetry', () {
      final analytics = createAnalytics({envVar: 'true'})..suppressTelemetry();
      expect(analytics.okToSend, isFalse);

      analytics.send(testEvent);
      expect(analytics.sentEvents, isEmpty);
    });

    test('fetchAvailableSurveys returns no surveys', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        // Control: the same survey is returned when not suppressed.
        final unsuppressed = createAnalytics(
          const {},
          surveyHandler: createSurveyHandler(),
        );
        expect(await unsuppressed.fetchAvailableSurveys(), hasLength(1));

        final suppressedEnvironment = {envVar: 'true'};
        final suppressed = createAnalytics(
          suppressedEnvironment,
          surveyHandler: createSurveyHandler(),
        );
        expect(await suppressed.fetchAvailableSurveys(), isEmpty);
      });
    });

    test('surveyShown and surveyInteracted send no events', () {
      withClock(Clock.fixed(DateTime(2023, 3, 3)), () {
        final suppressedEnvironment = {envVar: 'true'};
        final analytics = createAnalytics(
          suppressedEnvironment,
          surveyHandler: createSurveyHandler(),
        );

        analytics.surveyShown(testSurvey);
        analytics.surveyInteracted(
          survey: testSurvey,
          surveyButton: SurveyButton(
            buttonText: 'buttonText',
            action: 'accept',
            promptRemainsVisible: false,
          ),
        );

        expect(analytics.sentEvents, isEmpty);
      });
    });

    test('close sends no pending error events', () async {
      // Create a log file with malformed records so that reading it records
      // an error event to send on close.
      final logFile = home
          .childDirectory(kDartToolDirectoryName)
          .childFile(kLogFileName);
      logFile.writeAsStringSync('{{}\n{{}\n');
      createAnalytics(const {}).send(testEvent);

      // Control: without suppression, close sends the error event.
      final unsuppressed = createAnalytics(const {});
      unsuppressed.logFileStats();
      await unsuppressed.close();
      expect(
        unsuppressed.sentEvents.map((e) => e.eventName),
        contains(DashEvent.analyticsException),
      );

      final suppressed = createAnalytics({envVar: 'true'});
      suppressed.logFileStats();
      await suppressed.close();
      expect(suppressed.sentEvents, isEmpty);
    });

    // In a normal run the variable is unset, so this test only proves
    // something when the suite runs with DASH__SUPPRESS_ANALYTICS=true
    // exported.
    test('Analytics.fake ignores the real process environment by default', () {
      final analytics = Analytics.fake(
        tool: DashTool.flutterTool,
        homeDirectory: home,
        dartVersion: 'dartVersion',
        fs: fs,
      );

      expect(analytics.okToSend, isTrue);
    });

    group('setTelemetry', () {
      late _RecordingGAClient gaClient;

      setUp(() => gaClient = _RecordingGAClient());
      tearDown(() => gaClient.close());

      test('sends the status event when the variable is unset', () async {
        final analytics = createAnalytics(const {}, gaClient: gaClient);

        await analytics.setTelemetry(false);

        expect(gaClient.sentBodies, hasLength(1));
        expect(gaClient.sentBodies.single['events'], [
          containsPair('name', DashEvent.analyticsCollectionEnabled.label),
        ]);
      });

      test('opting out sends nothing but updates the configuration', () async {
        final analytics = createAnalytics({envVar: 'true'}, gaClient: gaClient);

        await analytics.setTelemetry(false);

        expect(gaClient.sentBodies, isEmpty);
        expect(analytics.telemetryEnabled, isFalse);
      });

      test('opting in sends and logs nothing but updates the '
          'configuration', () async {
        final analytics = createAnalytics({envVar: 'true'}, gaClient: gaClient);

        await analytics.setTelemetry(false);
        await analytics.setTelemetry(true);

        expect(gaClient.sentBodies, isEmpty);
        expect(analytics.telemetryEnabled, isTrue);
        expect(analytics.clientId, isNotEmpty);
        expect(analytics.logFileStats(), isNull);
      });
    });

    test('Analytics.fake follows the real process environment when passed '
        'Platform.environment', () {
      final analytics = createAnalytics(io.Platform.environment);

      expect(analytics.okToSend, !areAnalyticsSuppressed());
    });
  });
}

/// A [GAClient] that records request bodies instead of sending them.
class _RecordingGAClient extends GAClient {
  _RecordingGAClient() : super(measurementId: 'test', apiSecret: 'test');

  final List<Map<String, Object?>> sentBodies = [];

  @override
  Future<http.Response> sendData(Map<String, Object?> body) {
    sentBodies.add(body);
    return Future.value(http.Response('', 200));
  }
}
