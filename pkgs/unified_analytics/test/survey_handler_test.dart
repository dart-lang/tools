// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

import 'package:unified_analytics/src/survey_handler.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  group('Unit testing function checkSurveyDate:', () {
    final DateTime date = DateTime(2023, 5, 1);
    // Two surveys created, one that is within the survey date
    // range, and one that is not
    final Survey validSurvey = Survey(
      'uniqueId',
      'url',
      DateTime(2023, 1, 1),
      DateTime(2023, 12, 31),
      'description',
      10,
      'moreInfoUrl',
      0.1,
      <Condition>[],
    );
    final Survey invalidSurvey = Survey(
      'uniqueId',
      'url',
      DateTime(2022, 1, 1),
      DateTime(2022, 12, 31),
      'description',
      10,
      'moreInfoUrl',
      0.1,
      <Condition>[],
    );

    test('expired survey', () {
      final Clock clock = Clock.fixed(date);
      withClock(clock, () {
        expect(checkSurveyDate(invalidSurvey), false);
      });
    });

    test('valid survey', () {
      final Clock clock = Clock.fixed(date);
      withClock(clock, () {
        expect(checkSurveyDate(validSurvey), true);
      });
    });
  });

  group('Unit testing function parseSurveysFromJson', () {
    final String validContents = '''
[
	{
		"uniqueId": "xxxxx",
		"url": "xxxxx",
		"startDate": "2023-06-01T09:00:00-07:00",
		"endDate": "2023-06-30T09:00:00-07:00",
		"description": "xxxxxxx",
		"dismissForDays": "10",
		"moreInfoURL": "xxxxxx",
		"samplingRate": "0.1",
		"conditions": [
			{
				"field": "logFileStats.recordCount",
				"operator": ">=",
				"value": 1000
			},
			{
				"field": "logFileStats.toolCount",
				"operator": "<",
				"value": 3
			}
		]
	}
]
''';
    final String invalidContents = '''
[
	{
		"uniqueId": "xxxxx",
		"url": "xxxxx",
		"startDate": "2023-06-01T09:00:00-07:00",
		"endDate": "2023-06-30T09:00:00-07:00",
		"description": "xxxxxxx",
		"dismissForDays": "10",
		"moreInfoURL": "xxxxxx",
		"samplingRate": "0.1",
		"conditions": [
			{
				"field": "logFileStats.recordCount",
				"operator": ">=",
				"value": "1000xxxx"
			}
		]
	}
]
''';

    test('valid json', () {
      withClock(Clock.fixed(DateTime(2023, 6, 15)), () {
        final List<Survey> parsedSurveys =
            parseSurveysFromJson(jsonDecode(validContents));

        expect(parsedSurveys.length, 1);
        expect(parsedSurveys.first.conditionList.length, 2);

        final Condition firstCondition =
            parsedSurveys.first.conditionList.first;
        final Condition secondCondition = parsedSurveys.first.conditionList[1];

        expect(firstCondition.field, 'logFileStats.recordCount');
        expect(firstCondition.operatorString, '>=');
        expect(firstCondition.value, 1000);

        expect(secondCondition.field, 'logFileStats.toolCount');
        expect(secondCondition.operatorString, '<');
        expect(secondCondition.value, 3);
      });
    });

    test('invalid json', () {
      withClock(Clock.fixed(DateTime(2023, 6, 15)), () {
        final List<Survey> parsedSurveys =
            parseSurveysFromJson(jsonDecode(invalidContents));

        expect(parsedSurveys.length, 0,
            reason: 'The condition value is not a '
                'proper integer so it should error returning no surveys');
      });
    });
  });

  group('Testing with FakeSurveyHandler', () {
    late Analytics analytics;
    late Directory homeDirectory;
    late FileSystem fs;

    setUp(() {
      fs = MemoryFileSystem.test(style: FileSystemStyle.posix);
      homeDirectory = fs.directory('home');

      final Analytics initialAnalytics = Analytics.test(
        tool: DashTool.flutterTool,
        homeDirectory: homeDirectory,
        measurementId: 'measurementId',
        apiSecret: 'apiSecret',
        dartVersion: 'dartVersion',
        fs: fs,
        platform: DevicePlatform.macos,
      );
      initialAnalytics.clientShowedMessage();
    });

    test('returns valid survey', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.test(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          measurementId: 'measurementId',
          apiSecret: 'apiSecret',
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            initializedSurveys: <Survey>[
              Survey(
                'uniqueId',
                'url',
                DateTime(2023, 1, 1),
                DateTime(2023, 12, 31),
                'description',
                10,
                'moreInfoUrl',
                0.1,
                <Condition>[
                  Condition('logFileStats.recordCount', '>=', 50),
                  Condition('logFileStats.toolCount', '>', 0),
                ],
              ),
            ],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (int i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final List<Survey> fetchedSurveys =
            await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 1);
      });
    });

    test('does not return expired survey', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.test(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          measurementId: 'measurementId',
          apiSecret: 'apiSecret',
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            initializedSurveys: <Survey>[
              Survey(
                'uniqueId',
                'url',
                DateTime(2022, 1, 1),
                DateTime(2022, 12, 31),
                'description',
                10,
                'moreInfoUrl',
                0.1,
                <Condition>[
                  Condition('logFileStats.recordCount', '>=', 50),
                  Condition('logFileStats.toolCount', '>', 0),
                ],
              ),
            ],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (int i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final List<Survey> fetchedSurveys =
            await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 0);
      });
    });

    test('returns valid survey from json', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.test(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          measurementId: 'measurementId',
          apiSecret: 'apiSecret',
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromString(content: '''
[
    {
        "uniqueId": "uniqueId123",
        "url": "url123",
        "startDate": "2023-01-01T09:00:00-07:00",
        "endDate": "2023-12-31T09:00:00-07:00",
	"description": "description123",
	"dismissForDays": "10",
	"moreInfoURL": "moreInfoUrl123",
	"samplingRate": "0.1",
	"conditions": [
	    {
	        "field": "logFileStats.recordCount",
	        "operator": ">=",
	        "value": 50
      }
	]
    }
]
'''),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (int i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final List<Survey> fetchedSurveys =
            await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 1);

        final Survey survey = fetchedSurveys.first;
        expect(survey.uniqueId, 'uniqueId123');
        expect(survey.url, 'url123');
        expect(survey.startDate.year, 2023);
        expect(survey.startDate.month, 1);
        expect(survey.startDate.day, 1);
        expect(survey.endDate.year, 2023);
        expect(survey.endDate.month, 12);
        expect(survey.endDate.day, 31);
        expect(survey.description, 'description123');
        expect(survey.dismissForDays, 10);
        expect(survey.moreInfoUrl, 'moreInfoUrl123');
        expect(survey.samplingRate, 0.1);
        expect(survey.conditionList.length, 1);

        final Condition condition = survey.conditionList.first;
        expect(condition.field, 'logFileStats.recordCount');
        expect(condition.operatorString, '>=');
        expect(condition.value, 50);
      });
    });

    test('no survey returned from malformed json', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.test(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          measurementId: 'measurementId',
          apiSecret: 'apiSecret',
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromString(content: '''
[
    {
        "uniqueId": "xxxxxx",
        "url": "xxxxx",
        "startDate": "NOT A REAL DATE",
        "endDate": "2023-12-31T09:00:00-07:00",
	"description": "xxxxxxx",
	"dismissForDays": "10BAD",
	"moreInfoURL": "xxxxxx",
	"samplingRate": "0.1",
	"conditions": [
	    {
	        "field": "logFileStats.recordCount",
	        "operator": ">=",
	        "value": 50
      }
	]
    }
]
'''),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (int i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final List<Survey> fetchedSurveys =
            await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 0);
      });
    });

    test('returns two valid survey from json', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.test(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          measurementId: 'measurementId',
          apiSecret: 'apiSecret',
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromString(content: '''
[
    {
        "uniqueId": "12345",
        "url": "xxxxx",
        "startDate": "2023-01-01T09:00:00-07:00",
        "endDate": "2023-12-31T09:00:00-07:00",
	"description": "xxxxxxx",
	"dismissForDays": "10",
	"moreInfoURL": "xxxxxx",
	"samplingRate": "0.1",
	"conditions": [
	    {
	        "field": "logFileStats.recordCount",
	        "operator": ">=",
	        "value": 50
      }
	]
    },
    {
        "uniqueId": "67890",
        "url": "xxxxx",
        "startDate": "2023-01-01T09:00:00-07:00",
        "endDate": "2023-12-31T09:00:00-07:00",
	"description": "xxxxxxx",
	"dismissForDays": "10",
	"moreInfoURL": "xxxxxx",
	"samplingRate": "0.1",
	"conditions": [
	    {
	        "field": "logFileStats.recordCount",
	        "operator": ">=",
	        "value": 50
      }
	]
    }
]
'''),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (int i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final List<Survey> fetchedSurveys =
            await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 2);

        final Survey firstSurvey = fetchedSurveys.first;
        final Survey secondSurvey = fetchedSurveys.last;

        expect(firstSurvey.uniqueId, '12345');
        expect(secondSurvey.uniqueId, '67890');
      });
    });
  });
}
