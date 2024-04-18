// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as p;

import 'package:unified_analytics/src/constants.dart';
import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/src/survey_handler.dart';
import 'package:unified_analytics/unified_analytics.dart';

/// This example code is intended to only be used as guidance for
/// clients using this package. Clients using this package should avoid
/// the use of the [Analytics.fake] static method.
///
/// It was used in this example file so that the real [FileSystem] was swapped
/// out for a [MemoryFileSystem] so that repeated runs of this script yield
/// the same results.
void main() async {
  late final MemoryFileSystem fs;
  late final Analytics analytics;
  late final Directory home;
  // We need to initialize with a fake clock since the surveys have
  // a period of time they are valid for
  await withClock(Clock.fixed(DateTime(2023, 3, 3, 12, 0)), () async {
    // Use a memory file system to repeatedly run this example
    // file with the test instance
    fs = MemoryFileSystem(style: FileSystemStyle.posix);
    home = fs.directory('home');
    home.createSync();

    // The purpose of `initialAnalytics` is so that the tool is able to
    // send events after its first run; this instance won't be used below
    //
    // ignore: invalid_use_of_visible_for_testing_member
    final initialAnalytics = Analytics.fake(
      tool: DashTool.flutterTool,
      homeDirectory: home,
      dartVersion: 'dartVersion',
      fs: fs,
      platform: DevicePlatform.macos,
    );
    // The below command allows `DashTool.flutterTool` to send telemetry
    initialAnalytics.clientShowedMessage();

    // ignore: invalid_use_of_visible_for_testing_member
    analytics = Analytics.fake(
        tool: DashTool.flutterTool,
        homeDirectory: home,
        dartVersion: 'dartVersion',
        fs: fs,
        platform: DevicePlatform.macos,
        surveyHandler: FakeSurveyHandler.fromList(
          dismissedSurveyFile: fs.file(p.join(
            home.path,
            kDartToolDirectoryName,
            kDismissedSurveyFileName,
          )),
          initializedSurveys: [
            Survey(
              uniqueId: 'uniqueId',
              startDate: DateTime(2023, 1, 1),
              endDate: DateTime(2023, 5, 31),
              description: 'description',
              snoozeForMinutes: 10,
              samplingRate: 1.0,
              excludeDashToolList: [],
              conditionList: [],
              buttonList: [
                SurveyButton(
                  buttonText: 'View Survey',
                  action: 'accept',
                  promptRemainsVisible: false,
                  url: 'http://example.com',
                ),
                SurveyButton(
                  buttonText: 'More Info',
                  action: 'snooze',
                  promptRemainsVisible: true,
                  url: 'http://example2.com',
                ),
                SurveyButton(
                  buttonText: 'Dismiss Survey',
                  action: 'dismiss',
                  promptRemainsVisible: false,
                )
              ],
            ),
          ],
        ));
  });

  // Each client of this package will be able to fetch all of
  // the available surveys with the below method
  //
  // Sample rate will be applied automatically; it also won't
  // fetch any surveys in the snooze period or if they have
  // been dismissed
  final surveyList = await analytics.fetchAvailableSurveys();
  assert(surveyList.length == 1);

  // Grab the first and only survey to simulate displaying it to a user
  final survey = surveyList.first;
  print('Simulating displaying the survey with a print below:');
  print('Survey id: ${survey.uniqueId}\n');

  // Immediately after displaying the survey, the method below
  // should be run so that no other clients using this tool will show
  // it at the same time
  //
  // It will "snoozed" when the below is run as well as reported to
  // Google Analytics 4 that this survey was shown
  analytics.surveyShown(survey);

  // Get the file where this is persisted to show it getting updated
  final persistedSurveyFile = home
      .childDirectory(kDartToolDirectoryName)
      .childFile(kDismissedSurveyFileName);
  print('The contents of the json file '
      'after invoking `analytics.surveyShown(survey);`');
  print('${persistedSurveyFile.readAsStringSync()}\n');

  // Change the index below to decide which button to simulate pressing
  //
  // 0 - accept
  // 1 - snooze
  // 2 - dismiss
  final selectedButtonIndex = 1;
  assert([0, 1, 2].contains(selectedButtonIndex));

  // Get the survey button by index that will need to be passed along with
  // the survey to simulate an interaction with the survey
  final selectedSurveyButton = survey.buttonList[selectedButtonIndex];
  print('The simulated button pressed was: '
      '"${selectedSurveyButton.buttonText}" '
      '(action = ${selectedSurveyButton.action})\n');

  // The below method will handle whatever action the button
  analytics.surveyInteracted(
    survey: survey,
    surveyButton: selectedSurveyButton,
  );

  // Conditional to check if there is a URl to route to
  if (selectedSurveyButton.url != null) {
    print('***This button also has a survey URL link '
        'to route to at "${selectedSurveyButton.url}"***\n');
  }

  // Conditional to check what simulating a popup to stay up
  if (selectedSurveyButton.promptRemainsVisible) {
    print('***This button has its promptRemainsVisible field set to `true` '
        'so this simulates what seeing a pop up again would look like***\n');
  }

  print('The contents of the json file '
      'after invoking '
      '`analytics.surveyInteracted(survey: survey, '
      'surveyButton: selectedSurveyButton);`');
  print('${persistedSurveyFile.readAsStringSync()}\n');

  // Demonstrating that the survey doesn't get returned again
  print('Attempting to fetch surveys again will result in an empty list');
  print(await analytics.fetchAvailableSurveys());
}
