// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:unified_analytics/src/constants.dart';

import 'package:unified_analytics/src/survey_handler.dart';
import 'package:unified_analytics/src/utils.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  group('Unit testing function checkSurveyDate:', () {
    final date = DateTime(2023, 5, 1);
    // Two surveys created, one that is within the survey date
    // range, and one that is not
    final validSurvey = Survey(
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
    final invalidSurvey = Survey(
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
      final clock = Clock.fixed(date);
      withClock(clock, () {
        expect(checkSurveyDate(invalidSurvey), false);
      });
    });

    test('valid survey', () {
      final clock = Clock.fixed(date);
      withClock(clock, () {
        expect(checkSurveyDate(validSurvey), true);
      });
    });
  });

  group('Unit testing function parseSurveysFromJson', () {
    final validContents = '''
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
    // The value for the condition is not a valid integer
    final invalidContents = '''
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
        final parsedSurveys =
            parseSurveysFromJson(jsonDecode(validContents) as List);

        expect(parsedSurveys.length, 1);
        expect(parsedSurveys.first.conditionList.length, 2);

        final firstCondition = parsedSurveys.first.conditionList.first;
        final secondCondition = parsedSurveys.first.conditionList[1];

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
        final parsedSurveys =
            parseSurveysFromJson(jsonDecode(invalidContents) as List);

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
    late File clientIdFile;

    setUp(() {
      fs = MemoryFileSystem.test(style: FileSystemStyle.posix);
      homeDirectory = fs.directory('home');

      // Write the client ID file out so that we don't get
      // a randomly assigned id for this test generated within
      // the analytics constructor
      clientIdFile = fs.file(p.join(
        homeDirectory.path,
        kDartToolDirectoryName,
        kClientIdFileName,
      ));
      clientIdFile.createSync(recursive: true);
      clientIdFile.writeAsStringSync('string1');

      final initialAnalytics = Analytics.test(
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
                1.0,
                <Condition>[
                  Condition('logFileStats.recordCount', '>=', 50),
                  Condition('logFileStats.toolCount', '>', 0),
                ],
              ),
            ],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

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
        for (var i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

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
	"samplingRate": "1.0",
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
        for (var i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 1);

        final survey = fetchedSurveys.first;
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
        expect(survey.samplingRate, 1.0);
        expect(survey.conditionList.length, 1);

        final condition = survey.conditionList.first;
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
        for (var i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

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
	"samplingRate": "1.0",
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
	"samplingRate": "1.0",
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
        for (var i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 2);

        final firstSurvey = fetchedSurveys.first;
        final secondSurvey = fetchedSurveys.last;

        expect(firstSurvey.uniqueId, '12345');
        expect(secondSurvey.uniqueId, '67890');
      });
    });

    test('valid survey not returned if opted out', () async {
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
                1.0,
                <Condition>[
                  Condition('logFileStats.recordCount', '>=', 50),
                  Condition('logFileStats.toolCount', '>', 0),
                ],
              ),
            ],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        // Setting to false will prevent anything from getting returned
        await analytics.setTelemetry(false);
        var fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 0);

        // Setting telemetry back to true should enable the surveys to get
        // returned again; we will also need to send the fake events again
        // because on opt out, the log file will get cleared and one of
        // the conditions for the fake survey loaded is that we need
        // at least 50 records for one of the conditions
        await analytics.setTelemetry(true);
        for (var i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }
        fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 1);
      });
    });

    test('Unit testing the sampleRate method', () {
      // These strings had a predetermined output from the utility function
      final string1 = 'string1';
      final string2 = 'string2';

      expect(sampleRate(string1, string2), 0.17);
    });

    test('Sampling rate correctly returns a valid survey', () async {
      // This test will use a predefined client ID string of `string1`
      // which has been set in the setup along with a predefined
      // string for the survey ID of `string2` to get a sample rate value
      //
      // The combination of `string1` and `string2` will return 0.17
      // from the sampleRate utility function so we have set the threshold
      // to be 0.6 which should return surveys
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        final survey = Survey(
          'string2',
          'url',
          DateTime(2023, 1, 1),
          DateTime(2023, 12, 31),
          'description',
          10,
          'moreInfoUrl',
          0.6,
          <Condition>[
            Condition('logFileStats.recordCount', '>=', 50),
            Condition('logFileStats.toolCount', '>', 0),
          ],
        );
        analytics = Analytics.test(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          measurementId: 'measurementId',
          apiSecret: 'apiSecret',
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            initializedSurveys: <Survey>[survey],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(survey.samplingRate, 0.6);
        expect(fetchedSurveys.length, 1);
      });
    });

    test('Sampling rate filters out a survey', () async {
      // We will reduce the survey's sampling rate to be 0.3 which is
      // less than value returned from the predefined client ID and
      // survey sample
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        final survey = Survey(
          'string2',
          'url',
          DateTime(2023, 1, 1),
          DateTime(2023, 12, 31),
          'description',
          10,
          'moreInfoUrl',
          0.15,
          <Condition>[
            Condition('logFileStats.recordCount', '>=', 50),
            Condition('logFileStats.toolCount', '>', 0),
          ],
        );
        analytics = Analytics.test(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          measurementId: 'measurementId',
          apiSecret: 'apiSecret',
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            initializedSurveys: <Survey>[survey],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          await analytics.sendEvent(
              eventName: DashEvent.analyticsCollectionEnabled);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(survey.samplingRate, 0.15);
        expect(fetchedSurveys.length, 0);
      });
    });
  });
}
