// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/src/survey_handler.dart';
import 'package:unified_analytics/unified_analytics.dart';

import 'src/fake_analytics.dart';

void main() {
  // The fake analytics instance can be used to ensure events
  // are being sent when invoking methods on the `Analytics` instance

  late FakeAnalytics fakeAnalytics;
  late FileSystem fs;
  late Directory homeDirectory;

  /// Survey to load into the fake instance to fetch
  ///
  /// The 1.0 sample rate means that this will always show
  /// up from the method to fetch available surveys
  final testSurvey = Survey(
    uniqueId: 'uniqueId',
    startDate: DateTime(2022, 1, 1),
    endDate: DateTime(2022, 12, 31),
    description: 'description',
    dismissForMinutes: 10,
    samplingRate: 1.0, // 100% sample rate
    conditionList: <Condition>[],
    surveyButtonList: [],
  );

  /// Test event that will need to be sent since surveys won't
  /// be fetched until at least one event is logged in the persisted
  /// log file on disk
  final testEvent = Event.hotReloadTime(timeMs: 10);

  setUp(() async {
    fs = MemoryFileSystem.test(style: FileSystemStyle.posix);
    homeDirectory = fs.directory('home');

    final initialAnalytics = Analytics.test(
      tool: DashTool.flutterTool,
      homeDirectory: homeDirectory,
      measurementId: 'measurementId',
      apiSecret: 'apiSecret',
      dartVersion: 'dartVersion',
      toolsMessageVersion: 1,
      fs: fs,
      platform: DevicePlatform.macos,
    );
    initialAnalytics.clientShowedMessage();

    // Recreate a second instance since events cannot be sent on
    // the first run
    withClock(Clock.fixed(DateTime(2022, 3, 3)), () {
      fakeAnalytics = FakeAnalytics(
        tool: DashTool.flutterTool,
        homeDirectory: homeDirectory,
        dartVersion: 'dartVersion',
        platform: DevicePlatform.macos,
        toolsMessageVersion: 1,
        fs: fs,
        surveyHandler: FakeSurveyHandler.fromList(
          homeDirectory: homeDirectory,
          fs: fs,
          initializedSurveys: [testSurvey],
        ),
        enableAsserts: true,
      );
    });
  });

  test('event sent when survey shown', () async {
    // Fire off the test event to allow surveys to be fetched
    await fakeAnalytics.send(testEvent);

    final surveyList = await fakeAnalytics.fetchAvailableSurveys();
    expect(surveyList.length, 1);
    expect(fakeAnalytics.sentEvents.length, 1,
        reason: 'Only one event sent from the test event above');

    final survey = surveyList.first;
    expect(survey.uniqueId, 'uniqueId');

    // Simulate the survey being shown
    fakeAnalytics.surveyShown(survey);

    expect(fakeAnalytics.sentEvents.length, 2);
    expect(fakeAnalytics.sentEvents.last.eventName, DashEvent.surveyShown);
    expect(fakeAnalytics.sentEvents.last.eventData, {'surveyId': 'uniqueId'});
  });

  test('event sent when survey accepted', () async {
    // Fire off the test event to allow surveys to be fetched
    await fakeAnalytics.send(testEvent);

    final surveyList = await fakeAnalytics.fetchAvailableSurveys();
    expect(surveyList.length, 1);
    expect(fakeAnalytics.sentEvents.length, 1,
        reason: 'Only one event sent from the test event above');

    final survey = surveyList.first;
    expect(survey.uniqueId, 'uniqueId');

    // Simulate the survey being shown
    fakeAnalytics.dismissSurvey(survey: survey, surveyAccepted: true);

    expect(fakeAnalytics.sentEvents.length, 2);
    expect(fakeAnalytics.sentEvents.last.eventName, DashEvent.surveyAction);
    expect(fakeAnalytics.sentEvents.last.eventData,
        {'surveyId': 'uniqueId', 'status': 'accepted'});
  });

  test('event sent when survey rejected', () async {
    // Fire off the test event to allow surveys to be fetched
    await fakeAnalytics.send(testEvent);

    final surveyList = await fakeAnalytics.fetchAvailableSurveys();
    expect(surveyList.length, 1);
    expect(fakeAnalytics.sentEvents.length, 1,
        reason: 'Only one event sent from the test event above');

    final survey = surveyList.first;
    expect(survey.uniqueId, 'uniqueId');

    // Simulate the survey being shown
    fakeAnalytics.dismissSurvey(survey: survey, surveyAccepted: false);

    expect(fakeAnalytics.sentEvents.length, 2);
    expect(fakeAnalytics.sentEvents.last.eventName, DashEvent.surveyAction);
    expect(fakeAnalytics.sentEvents.last.eventData,
        {'surveyId': 'uniqueId', 'status': 'dismissed'});
  });
}
