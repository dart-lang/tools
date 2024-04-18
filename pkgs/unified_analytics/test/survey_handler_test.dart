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
import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/src/survey_handler.dart';
import 'package:unified_analytics/src/utils.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  final testEvent = Event.hotReloadTime(timeMs: 10);

  group('Unit testing function sampleRate:', () {
    // Set a string that can be used in place of a survey's unique ID
    final iterations = 1000;
    final uuid = Uuid(123);
    final uniqueSurveyId = uuid.generateV4();

    // Set how much the actual sampled rate can be (allowing 5% of variability)
    final marginOfError = 0.05;

    test('Unit testing the sampleRate method', () {
      // These strings had a predetermined output from the utility function
      final string1 = 'string1';
      final string2 = 'string2';
      expect(sampleRate(string1, string2), 0.40);
    });

    test('Simulating with various sample rates', () {
      final sampleRateToTestList = [
        0.10,
        0.25,
        0.50,
        0.75,
        0.80,
        0.95,
      ];
      for (final sampleRateToTest in sampleRateToTestList) {
        var count = 0;
        for (var i = 0; i < iterations; i++) {
          // Regenerate the client id to simulate a unique user
          final generatedClientId = uuid.generateV4();
          if (sampleRate(uniqueSurveyId, generatedClientId) <=
              sampleRateToTest) {
            count += 1;
          }
        }

        final actualSampledRate = count / iterations;
        final actualMarginOfError =
            (sampleRateToTest - actualSampledRate).abs();

        expect(actualMarginOfError < marginOfError, true,
            reason: 'Failed on sample rate = $sampleRateToTest with'
                ' actual rate $actualMarginOfError '
                'and a margin of error = $marginOfError');
      }
    });
  });

  group('Unit testing function checkSurveyDate:', () {
    final date = DateTime(2023, 5, 1);
    // Two surveys created, one that is within the survey date
    // range, and one that is not
    final validSurvey = Survey(
      uniqueId: 'uniqueId',
      startDate: DateTime(2023, 1, 1),
      endDate: DateTime(2023, 12, 31),
      description: 'description',
      snoozeForMinutes: 10,
      samplingRate: 1.0,
      excludeDashToolList: [],
      conditionList: <Condition>[],
      buttonList: [],
    );
    final invalidSurvey = Survey(
      uniqueId: 'uniqueId',
      startDate: DateTime(2022, 1, 1),
      endDate: DateTime(2022, 12, 31),
      description: 'description',
      snoozeForMinutes: 10,
      samplingRate: 1.0,
      excludeDashToolList: [],
      conditionList: <Condition>[],
      buttonList: [],
    );

    test('expired survey', () {
      final clock = Clock.fixed(date);
      withClock(clock, () {
        expect(SurveyHandler.checkSurveyDate(invalidSurvey), false);
      });
    });

    test('valid survey', () {
      final clock = Clock.fixed(date);
      withClock(clock, () {
        expect(SurveyHandler.checkSurveyDate(validSurvey), true);
      });
    });
  });

  group('Unit testing function parseSurveysFromJson', () {
    final validContents = '''
[
  {
    "uniqueId": "xxxxx",
    "startDate": "2023-06-01T09:00:00-07:00",
    "endDate": "2023-06-30T09:00:00-07:00",
    "description": "xxxxxxx",
    "snoozeForMinutes": "10",
    "samplingRate": "1.0",
    "excludeDashTools": [],
    "conditions": [
      {
        "field": "logFileStats.recordCount",
        "operator": ">=",
        "value": 1000
      },
      {
        "field": "logFileStats.toolCount.flutter-tool",
        "operator": "<",
        "value": 3
      }
    ],
    "buttons": [
        {
            "buttonText": "Take Survey",
            "action": "accept",
            "url": "https://google.qualtrics.com/jfe/form/SV_5gsB2EuG324y2",
            "promptRemainsVisible": false
        }
    ]
  }
]
''';

    // The value for the condition is not a valid integer
    final invalidConditionValueContents = '''
[
  {
    "uniqueId": "xxxxx",
    "startDate": "2023-06-01T09:00:00-07:00",
    "endDate": "2023-06-30T09:00:00-07:00",
    "description": "xxxxxxx",
    "snoozeForMinutes": "10",
    "samplingRate": "1.0",
    "excludeDashTools": [],
    "conditions": [
      {
        "field": "logFileStats.recordCount",
        "operator": ">=",
        "value": "1000xxxx"
      }
    ],
    "buttons": [
        {
            "buttonText": "Take Survey",
            "action": "accept",
            "url": "https://google.qualtrics.com/jfe/form/SV_5gsB2EuG324y2",
            "promptRemainsVisible": false
        }
    ]
  }
]
''';

    // Using a dash tool in the excludeDashTools array that is not a valid
    // DashTool label
    final invalidDashToolContents = '''
[
  {
    "uniqueId": "xxxxx",
    "startDate": "2023-06-01T09:00:00-07:00",
    "endDate": "2023-06-30T09:00:00-07:00",
    "description": "xxxxxxx",
    "snoozeForMinutes": "10",
    "samplingRate": "1.0",
    "excludeDashTools": [
      "not-a-valid-dash-tool"
    ],
    "conditions": [
      {
        "field": "logFileStats.recordCount",
        "operator": ">=",
        "value": 1000
      },
      {
        "field": "logFileStats.toolCount.flutter-tool",
        "operator": "<",
        "value": 3
      }
    ],
    "buttons": [
        {
            "buttonText": "Take Survey",
            "action": "accept",
            "url": "https://google.qualtrics.com/jfe/form/SV_5gsB2EuG324y2",
            "promptRemainsVisible": false
        }
    ]
  }
]
''';

    test('valid json', () {
      withClock(Clock.fixed(DateTime(2023, 6, 15)), () {
        final parsedSurveys = SurveyHandler.parseSurveysFromJson(
            jsonDecode(validContents) as List);

        expect(parsedSurveys.length, 1);
        expect(parsedSurveys.first.conditionList.length, 2);

        final firstCondition = parsedSurveys.first.conditionList.first;
        final secondCondition = parsedSurveys.first.conditionList[1];

        expect(firstCondition.field, 'logFileStats.recordCount');
        expect(firstCondition.operatorString, '>=');
        expect(firstCondition.value, 1000);

        expect(secondCondition.field, 'logFileStats.toolCount.flutter-tool');
        expect(secondCondition.operatorString, '<');
        expect(secondCondition.value, 3);

        expect(parsedSurveys.first.buttonList.length, 1);
        expect(
            parsedSurveys.first.buttonList.first.promptRemainsVisible, false);
      });
    });

    test('invalid condition json', () {
      withClock(Clock.fixed(DateTime(2023, 6, 15)), () {
        final parsedSurveys = SurveyHandler.parseSurveysFromJson(
            jsonDecode(invalidConditionValueContents) as List);

        expect(parsedSurveys.length, 0,
            reason: 'The condition value is not a '
                'proper integer so it should error returning no surveys');
      });
    });

    test('invalid dash tool json', () {
      withClock(Clock.fixed(DateTime(2023, 6, 15)), () {
        final parsedSurveys = SurveyHandler.parseSurveysFromJson(
            jsonDecode(invalidDashToolContents) as List);

        expect(parsedSurveys.length, 0,
            reason: 'The dash tool in the exclude array is not valid '
                'so it should error returning no surveys');
      });
    });
  });

  group('Testing with FakeSurveyHandler', () {
    late Analytics analytics;
    late Directory homeDirectory;
    late MemoryFileSystem fs;
    late File clientIdFile;
    late File dismissedSurveyFile;

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

      // Assign the json file that will hold the persisted surveys
      dismissedSurveyFile = fs.file(p.join(
        homeDirectory.path,
        kDartToolDirectoryName,
        kDismissedSurveyFileName,
      ));

      // Setup two tools to be onboarded with this package so
      // that we can simulate two different tools interacting with
      // surveys
      //
      // This is especially useful when testing the "excludeDashTools" array
      // to prevent certain tools from getting a survey from this package
      final initialAnalyticsFlutter = Analytics.fake(
        tool: DashTool.flutterTool,
        homeDirectory: homeDirectory,
        dartVersion: 'dartVersion',
        fs: fs,
        platform: DevicePlatform.macos,
      );
      final initialAnalyticsDart = Analytics.fake(
        tool: DashTool.dartTool,
        homeDirectory: homeDirectory,
        dartVersion: 'dartVersion',
        fs: fs,
        platform: DevicePlatform.macos,
      );
      initialAnalyticsFlutter.clientShowedMessage();
      initialAnalyticsDart.clientShowedMessage();
    });

    test('returns valid survey', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[
              Survey(
                uniqueId: 'uniqueId',
                startDate: DateTime(2023, 1, 1),
                endDate: DateTime(2023, 12, 31),
                description: 'description',
                snoozeForMinutes: 10,
                samplingRate: 1.0,
                excludeDashToolList: [],
                conditionList: <Condition>[
                  Condition('logFileStats.recordCount', '>=', 50),
                  Condition('logFileStats.toolCount.flutter-tool', '>', 0),
                ],
                buttonList: [
                  SurveyButton(
                    buttonText: 'buttonText',
                    action: 'accept',
                    url: 'http://example.com',
                    promptRemainsVisible: false,
                  ),
                ],
              ),
            ],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          analytics.send(testEvent);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 1);

        final survey = fetchedSurveys.first;
        expect(survey.conditionList.length, 2);
        expect(survey.buttonList.length, 1);
      });
    });

    test('does not return expired survey', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[
              Survey(
                uniqueId: 'uniqueId',
                startDate: DateTime(2022, 1, 1),
                endDate: DateTime(2022, 12, 31),
                description: 'description',
                snoozeForMinutes: 10,
                samplingRate: 1.0,
                excludeDashToolList: [],
                conditionList: <Condition>[
                  Condition('logFileStats.recordCount', '>=', 50),
                  Condition('logFileStats.toolCount.flutter-tool', '>', 0),
                ],
                buttonList: [],
              ),
            ],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          analytics.send(testEvent);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 0);
      });
    });

    test('does not return survey if opted out of telemetry', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[
              Survey(
                uniqueId: 'uniqueId',
                startDate: DateTime(2023, 1, 1),
                endDate: DateTime(2023, 12, 31),
                description: 'description',
                snoozeForMinutes: 10,
                samplingRate: 1.0,
                excludeDashToolList: [],
                conditionList: <Condition>[
                  Condition('logFileStats.recordCount', '>=', 50),
                  Condition('logFileStats.toolCount.flutter-tool', '>', 0),
                ],
                buttonList: [],
              ),
            ],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          analytics.send(testEvent);
        }

        await analytics.setTelemetry(false);
        expect(analytics.okToSend, false);

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 0);
      });
    });

    test('returns valid survey from json', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromString(
              dismissedSurveyFile: dismissedSurveyFile, content: '''
[
    {
        "uniqueId": "uniqueId123",
        "startDate": "2023-01-01T09:00:00-07:00",
        "endDate": "2023-12-31T09:00:00-07:00",
        "description": "description123",
        "snoozeForMinutes": "10",
        "samplingRate": "1.0",
        "excludeDashTools": [],
        "conditions": [
            {
                "field": "logFileStats.recordCount",
                "operator": ">=",
                "value": 50
            }
        ],
        "buttons": [
            {
                "buttonText": "Take Survey",
                "action": "accept",
                "url": "https://google.qualtrics.com/jfe/form/SV_5gsB2EuG324y2",
                "promptRemainsVisible": false
            },
            {
                "buttonText": "Dismiss",
                "action": "dismiss",
                "url": null,
                "promptRemainsVisible": false
            },
            {
                "buttonText": "More Info",
                "action": "snooze",
                "url": "https://docs.flutter.dev/reference/crash-reporting",
                "promptRemainsVisible": true
            }
        ]
    }
]
'''),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          analytics.send(testEvent);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 1);

        final survey = fetchedSurveys.first;
        expect(survey.uniqueId, 'uniqueId123');
        expect(survey.startDate.year, 2023);
        expect(survey.startDate.month, 1);
        expect(survey.startDate.day, 1);
        expect(survey.endDate.year, 2023);
        expect(survey.endDate.month, 12);
        expect(survey.endDate.day, 31);
        expect(survey.description, 'description123');
        expect(survey.snoozeForMinutes, 10);
        expect(survey.samplingRate, 1.0);
        expect(survey.conditionList.length, 1);

        final condition = survey.conditionList.first;
        expect(condition.field, 'logFileStats.recordCount');
        expect(condition.operatorString, '>=');
        expect(condition.value, 50);

        final buttonList = survey.buttonList;
        expect(buttonList.length, 3);
        expect(buttonList.first.buttonText, 'Take Survey');
        expect(buttonList.first.action, 'accept');
        expect(buttonList.first.url,
            'https://google.qualtrics.com/jfe/form/SV_5gsB2EuG324y2');
        expect(buttonList.first.promptRemainsVisible, false);

        expect(buttonList.elementAt(1).buttonText, 'Dismiss');
        expect(buttonList.elementAt(1).action, 'dismiss');
        expect(buttonList.elementAt(1).url, isNull);
        expect(buttonList.elementAt(1).promptRemainsVisible, false);

        expect(buttonList.last.buttonText, 'More Info');
        expect(buttonList.last.action, 'snooze');
        expect(buttonList.last.url,
            'https://docs.flutter.dev/reference/crash-reporting');
        expect(buttonList.last.promptRemainsVisible, true);
      });
    });

    test('no survey returned from malformed json', () async {
      // The date is not valid for the start date
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromString(
              dismissedSurveyFile: dismissedSurveyFile, content: '''
[
    {
        "uniqueId": "uniqueId123",
        "startDate": "NOT A REAL DATE",
        "endDate": "2023-07-30T09:00:00-07:00",
        "description": "Help improve Flutter's release builds with this 3-question survey!",
        "snoozeForMinutes": "7200",
        "samplingRate": "0.1",
        "excludeDashTools": [],
        "conditions": [
            {
                "field": "logFileStats.recordCount",
                "operator": ">=",
                "value": 50
            }
        ],
        "buttons": [
            {
                "buttonText": "Take Survey",
                "action": "accept",
                "url": "https://google.qualtrics.com/jfe/form/SV_5gsB2EuG5Et5Yy2",
                "promptRemainsVisible": false
            },
            {
                "buttonText": "Dismiss",
                "action": "dismiss",
                "url": null,
                "promptRemainsVisible": false
            },
            {
                "buttonText": "More Info",
                "action": "snooze",
                "url": "https://docs.flutter.dev/reference/crash-reporting",
                "promptRemainsVisible": false
            }
        ]
    }
]
'''),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          analytics.send(testEvent);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 0);
      });
    });

    test('returns two valid survey from json', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromString(
              dismissedSurveyFile: dismissedSurveyFile, content: '''
[
    {
        "uniqueId": "12345",
        "startDate": "2023-01-01T09:00:00-07:00",
        "endDate": "2023-12-31T09:00:00-07:00",
        "description": "xxxxxxx",
        "snoozeForMinutes": "10",
        "samplingRate": "1.0",
        "excludeDashTools": [],
        "conditions": [
            {
                "field": "logFileStats.recordCount",
                "operator": ">=",
                "value": 50
            }
        ], 
        "buttons": []
    },
    {
        "uniqueId": "67890",
        "startDate": "2023-01-01T09:00:00-07:00",
        "endDate": "2023-12-31T09:00:00-07:00",
        "description": "xxxxxxx",
        "snoozeForMinutes": "10",
        "samplingRate": "1.0",
        "excludeDashTools": [],
        "conditions": [
            {
                "field": "logFileStats.recordCount",
                "operator": ">=",
                "value": 50
            }
        ],
        "buttons": [
            {
                "buttonText": "More Info",
                "action": "snooze",
                "url": "https://docs.flutter.dev/reference/crash-reporting",
                "promptRemainsVisible": true
            }
        ]
    }
]
'''),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          analytics.send(testEvent);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 2);

        final firstSurvey = fetchedSurveys.first;
        final secondSurvey = fetchedSurveys.last;

        expect(firstSurvey.uniqueId, '12345');
        expect(secondSurvey.uniqueId, '67890');

        final secondSurveyButtons = secondSurvey.buttonList;
        expect(secondSurveyButtons.length, 1);
        expect(secondSurveyButtons.first.buttonText, 'More Info');
        expect(secondSurveyButtons.first.action, 'snooze');
        expect(secondSurveyButtons.first.url,
            'https://docs.flutter.dev/reference/crash-reporting');
        expect(secondSurveyButtons.first.promptRemainsVisible, true);
      });
    });

    test('valid survey not returned if opted out', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[
              Survey(
                uniqueId: 'uniqueId',
                startDate: DateTime(2023, 1, 1),
                endDate: DateTime(2023, 12, 31),
                description: 'description',
                snoozeForMinutes: 10,
                samplingRate: 1.0,
                excludeDashToolList: [],
                conditionList: <Condition>[
                  Condition('logFileStats.recordCount', '>=', 50),
                  Condition('logFileStats.toolCount.flutter-tool', '>', 0),
                ],
                buttonList: [],
              ),
            ],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          analytics.send(testEvent);
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
          analytics.send(testEvent);
        }
        fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 1);
      });
    });

    test('Sampling rate correctly returns a valid survey', () async {
      // This test will use a predefined client ID string of `string1`
      // which has been set in the setup along with a predefined
      // string for the survey ID of `string2` to get a sample rate value
      //
      // The combination of `string1` and `string2` will return 0.40
      // from the sampleRate utility function so we have set the threshold
      // to be 0.6 which should return surveys
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        final survey = Survey(
          uniqueId: 'string2',
          startDate: DateTime(2023, 1, 1),
          endDate: DateTime(2023, 12, 31),
          description: 'description',
          snoozeForMinutes: 10,
          samplingRate: 0.6,
          excludeDashToolList: [],
          conditionList: <Condition>[
            Condition('logFileStats.recordCount', '>=', 50),
            Condition('logFileStats.toolCount.flutter-tool', '>', 0),
          ],
          buttonList: [],
        );
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[survey],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          analytics.send(testEvent);
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
          uniqueId: 'string2',
          startDate: DateTime(2023, 1, 1),
          endDate: DateTime(2023, 12, 31),
          description: 'description',
          snoozeForMinutes: 10,
          samplingRate: 0.15,
          excludeDashToolList: [],
          conditionList: <Condition>[
            Condition('logFileStats.recordCount', '>=', 50),
            Condition('logFileStats.toolCount.flutter-tool', '>', 0),
          ],
          buttonList: [],
        );
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[survey],
          ),
        );

        // Simulate 60 events to send so that the first condition is satisified
        for (var i = 0; i < 60; i++) {
          analytics.send(testEvent);
        }

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(survey.samplingRate, 0.15);
        expect(fetchedSurveys.length, 0);
      });
    });

    test('Snoozing survey is successful with snooze timeout from survey',
        () async {
      expect(dismissedSurveyFile.readAsStringSync(), '{}',
          reason: 'Should be an empty object');

      // Initialize the survey class that we will use for this test
      final minutesToSnooze = 30;
      final surveyToLoad = Survey(
        uniqueId: 'uniqueId',
        startDate: DateTime(2023, 1, 1),
        endDate: DateTime(2023, 12, 31),
        description: 'description',
        snoozeForMinutes:
            minutesToSnooze, // Initialized survey with `minutesToSnooze`
        samplingRate: 1.0,
        excludeDashToolList: [],
        conditionList: <Condition>[],
        buttonList: [],
      );

      await withClock(Clock.fixed(DateTime(2023, 3, 3, 12, 0)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[surveyToLoad],
          ),
        );

        final fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 1);

        final survey = fetchedSurveys.first;
        expect(survey.snoozeForMinutes, minutesToSnooze);

        // We will snooze the survey now and it should not show up
        // if we fetch surveys again before the minutes to snooze time
        // has finished
        analytics.surveyShown(survey);
      });

      // This analytics instance will be simulated to be shortly after the first
      // snooze, but before the snooze period has elapsed
      await withClock(Clock.fixed(DateTime(2023, 3, 3, 12, 15)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[surveyToLoad],
          ),
        );

        final fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 0,
            reason: 'The snooze period has not elapsed yet');
      });

      // This analytics instance will be simulated to be after the snooze period
      await withClock(Clock.fixed(DateTime(2023, 3, 3, 12, 35)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[surveyToLoad],
          ),
        );

        final fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 1,
            reason: 'The snooze period has elapsed');
      });
    });

    test('Dimissing permanently is successful', () async {
      final minutesToSnooze = 10;
      final surveyToLoad = Survey(
        uniqueId: 'uniqueId',
        startDate: DateTime(2023, 1, 1),
        endDate: DateTime(2023, 12, 31),
        description: 'description',
        snoozeForMinutes: minutesToSnooze,
        samplingRate: 1.0,
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

      await withClock(Clock.fixed(DateTime(2023, 3, 3, 12, 0)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[surveyToLoad],
          ),
        );

        final fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 1);

        // Dismissing permanently will ensure that this survey is not
        // shown again
        final survey = fetchedSurveys.first;
        analytics.surveyInteracted(
          survey: survey,
          surveyButton: survey.buttonList.first,
        );
      });

      // Moving out a week
      await withClock(Clock.fixed(DateTime(2023, 3, 10, 12, 0)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[surveyToLoad],
          ),
        );

        final fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 0);
      });
    });

    test('malformed persisted json file for surveys', () async {
      // When the survey handler encounters an error when parsing the
      // persisted json file, it will reset it using the static method
      // under the [Initializer] class and reset it to be an empty json object
      final minutesToSnooze = 10;
      final surveyToLoad = Survey(
        uniqueId: 'uniqueId',
        startDate: DateTime(2023, 1, 1),
        endDate: DateTime(2023, 12, 31),
        description: 'description',
        snoozeForMinutes: minutesToSnooze,
        samplingRate: 1.0,
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

      await withClock(Clock.fixed(DateTime(2023, 3, 3, 12, 0)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[surveyToLoad],
          ),
        );

        final fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 1);

        // Dismissing permanently will ensure that this survey is not
        // shown again
        final survey = fetchedSurveys.first;
        expect(survey.buttonList.length, 2);
        analytics.surveyInteracted(
          survey: survey,
          surveyButton: survey.buttonList.first,
        );
      });

      // Purposefully write invalid json into the persisted file
      dismissedSurveyFile.writeAsStringSync('{');

      // Moving out a week
      await withClock(Clock.fixed(DateTime(2023, 3, 10, 12, 0)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[surveyToLoad],
          ),
        );

        final fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 1);
      });
    });

    test('persisted json file goes missing handled', () async {
      // If the persisted json file with the dismissed surveys is missing
      // there should be error handling to recreate the file again with
      // an empty json object
      final minutesToSnooze = 10;
      final surveyToLoad = Survey(
        uniqueId: 'uniqueId',
        startDate: DateTime(2023, 1, 1),
        endDate: DateTime(2023, 12, 31),
        description: 'description',
        snoozeForMinutes: minutesToSnooze,
        samplingRate: 1.0,
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

      await withClock(Clock.fixed(DateTime(2023, 3, 3, 12, 0)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[surveyToLoad],
          ),
        );

        final fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 1);

        // Dismissing permanently will ensure that this survey is not
        // shown again
        final survey = fetchedSurveys.first;
        expect(survey.buttonList.length, 2);
        analytics.surveyInteracted(
          survey: survey,
          surveyButton: survey.buttonList.first,
        );
      });

      // Moving out a week
      await withClock(Clock.fixed(DateTime(2023, 3, 10, 12, 0)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[surveyToLoad],
          ),
        );

        // Purposefully delete the file
        dismissedSurveyFile.deleteSync();

        final fetchedSurveys = await analytics.fetchAvailableSurveys();
        expect(fetchedSurveys.length, 1);
      });
    });

    test('Filtering out with excludeDashTool array', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[
              Survey(
                uniqueId: 'uniqueId',
                startDate: DateTime(2023, 1, 1),
                endDate: DateTime(2023, 12, 31),
                description: 'description',
                snoozeForMinutes: 10,
                samplingRate: 1.0,
                // This should be the same as the tool in the
                // Analytics constructor above
                excludeDashToolList: [
                  DashTool.flutterTool,
                ],
                conditionList: [],
                buttonList: [
                  SurveyButton(
                    buttonText: 'buttonText',
                    action: 'accept',
                    url: 'http://example.com',
                    promptRemainsVisible: false,
                  ),
                ],
              ),
            ],
          ),
        );

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 0);
      });
    });

    test(
        'Filter from excludeDashTool array does not '
        'apply for different tool', () async {
      await withClock(Clock.fixed(DateTime(2023, 3, 3)), () async {
        analytics = Analytics.fake(
          tool: DashTool.flutterTool,
          homeDirectory: homeDirectory,
          dartVersion: 'dartVersion',
          fs: fs,
          platform: DevicePlatform.macos,
          surveyHandler: FakeSurveyHandler.fromList(
            dismissedSurveyFile: dismissedSurveyFile,
            initializedSurveys: <Survey>[
              Survey(
                uniqueId: 'uniqueId',
                startDate: DateTime(2023, 1, 1),
                endDate: DateTime(2023, 12, 31),
                description: 'description',
                snoozeForMinutes: 10,
                samplingRate: 1.0,
                // This should be different from the tool in the
                // Analytics constructor above
                excludeDashToolList: [
                  DashTool.devtools,
                ],
                conditionList: [],
                buttonList: [
                  SurveyButton(
                    buttonText: 'buttonText',
                    action: 'accept',
                    url: 'http://example.com',
                    promptRemainsVisible: false,
                  ),
                ],
              ),
            ],
          ),
        );

        final fetchedSurveys = await analytics.fetchAvailableSurveys();

        expect(fetchedSurveys.length, 1);

        final survey = fetchedSurveys.first;
        expect(survey.excludeDashToolList.length, 1);
        expect(survey.excludeDashToolList.contains(DashTool.devtools), true);
      });
    });
  });
}
