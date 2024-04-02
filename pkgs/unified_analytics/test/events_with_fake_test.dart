// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:unified_analytics/src/constants.dart';
import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/src/survey_handler.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  // The fake analytics instance can be used to ensure events
  // are being sent when invoking methods on the `Analytics` instance

  late FakeAnalytics fakeAnalytics;
  late MemoryFileSystem fs;
  late Directory homeDirectory;
  late File dismissedSurveyFile;

  /// Survey to load into the fake instance to fetch
  ///
  /// The 1.0 sample rate means that this will always show
  /// up from the method to fetch available surveys
  final testSurvey = Survey(
    uniqueId: 'uniqueId',
    startDate: DateTime(2022, 1, 1),
    endDate: DateTime(2022, 12, 31),
    description: 'description',
    snoozeForMinutes: 10,
    samplingRate: 1.0, // 100% sample rate
    excludeDashToolList: [],
    conditionList: <Condition>[],
    buttonList: [
      SurveyButton(
        buttonText: 'buttonText',
        action: 'accept',
        promptRemainsVisible: false,
      ),
      SurveyButton(
        buttonText: 'buttonText',
        action: 'dismiss',
        promptRemainsVisible: false,
      ),
    ],
  );

  setUp(() async {
    fs = MemoryFileSystem.test(style: FileSystemStyle.posix);
    homeDirectory = fs.directory('home');
    dismissedSurveyFile = fs.file(p.join(
      homeDirectory.path,
      kDartToolDirectoryName,
      kDismissedSurveyFileName,
    ));

    final initialAnalytics = Analytics.fake(
      tool: DashTool.flutterTool,
      homeDirectory: homeDirectory,
      dartVersion: 'dartVersion',
      toolsMessageVersion: 1,
      fs: fs,
      platform: DevicePlatform.macos,
    );
    initialAnalytics.clientShowedMessage();

    // Recreate a second instance since events cannot be sent on
    // the first run
    withClock(Clock.fixed(DateTime(2022, 3, 3)), () {
      final toolsMessageVersion = kToolsMessageVersion;
      fakeAnalytics = Analytics.fake(
        tool: DashTool.flutterTool,
        homeDirectory: homeDirectory,
        dartVersion: 'dartVersion',
        platform: DevicePlatform.macos,
        fs: fs,
        toolsMessageVersion: toolsMessageVersion,
        surveyHandler: FakeSurveyHandler.fromList(
          dismissedSurveyFile: dismissedSurveyFile,
          initializedSurveys: [testSurvey],
        ),
      );
    });
  });

  test('event sent when survey shown', () async {
    final surveyList = await fakeAnalytics.fetchAvailableSurveys();
    expect(surveyList.length, 1);
    expect(fakeAnalytics.sentEvents.length, 0);

    final survey = surveyList.first;
    expect(survey.uniqueId, 'uniqueId');

    // Simulate the survey being shown
    fakeAnalytics.surveyShown(survey);

    expect(fakeAnalytics.sentEvents.length, 1);
    expect(fakeAnalytics.sentEvents.last.eventName, DashEvent.surveyShown);
    expect(fakeAnalytics.sentEvents.last.eventData, {'surveyId': 'uniqueId'});
  });

  test('event sent when survey accepted', () async {
    final surveyList = await fakeAnalytics.fetchAvailableSurveys();
    expect(surveyList.length, 1);
    expect(fakeAnalytics.sentEvents.length, 0);

    final survey = surveyList.first;
    expect(survey.uniqueId, 'uniqueId');

    // Simulate the survey being shown
    //
    // The first button is the accept button
    fakeAnalytics.surveyInteracted(
      survey: survey,
      surveyButton: survey.buttonList.first,
    );

    expect(fakeAnalytics.sentEvents.length, 1);
    expect(fakeAnalytics.sentEvents.last.eventName, DashEvent.surveyAction);
    expect(fakeAnalytics.sentEvents.last.eventData,
        {'surveyId': 'uniqueId', 'status': 'accept'});
  });

  test('event sent when survey rejected', () async {
    final surveyList = await fakeAnalytics.fetchAvailableSurveys();
    expect(surveyList.length, 1);
    expect(fakeAnalytics.sentEvents.length, 0);

    final survey = surveyList.first;
    expect(survey.uniqueId, 'uniqueId');

    // Simulate the survey being shown
    //
    // The last button is the reject button
    fakeAnalytics.surveyInteracted(
      survey: survey,
      surveyButton: survey.buttonList.last,
    );

    expect(fakeAnalytics.sentEvents.length, 1);
    expect(fakeAnalytics.sentEvents.last.eventName, DashEvent.surveyAction);
    expect(fakeAnalytics.sentEvents.last.eventData,
        {'surveyId': 'uniqueId', 'status': 'dismiss'});
  });
}
