// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// URL endpoint for sending Google Analytics Events.
const String kAnalyticsUrl = 'https://www.google-analytics.com/mp/collect';

/// Name for the text file that will contain the user's randomly generated
/// client id.
const String kClientIdFileName = 'CLIENT_ID';

/// Name for the file where telemetry status and tools data will be stored.
const String kConfigFileName = 'dart-flutter-telemetry.config';

/// The string that will provide the boilerplate for the configuration file
/// stored on the user's machine.
const String kConfigString = '''
# INTRODUCTION
#
# This is the Flutter and Dart telemetry reporting
# configuration file.
#
# Lines starting with a #" are documentation that
# the tools maintain automatically.
#
# All other lines are configuration lines. They have
# the form "name=value". If multiple lines contain
# the same configuration name with different values,
# the parser will default to a conservative value. 

# DISABLING TELEMETRY REPORTING
#
# To disable telemetry reporting, set "reporting" to
# the value "0" and to enable, set to "1":
reporting=1

# NOTIFICATIONS
#
# Each tool records when it last informed the user about
# analytics reporting and the privacy policy.
#
# The following tools have so far read this file:
#
#   dart-tools (Dart CLI developer tool)
#   devtools (DevTools debugging and performance tools)
#   flutter-tools (Flutter CLI developer tool)
#
# For each one, the file may contain a configuration line
# where the name is the code in the list above, e.g. "dart-tool",
# and the value is a date in the form YYYY-MM-DD, a comma, and
# a number representing the version of the message that was
# displayed.''';

/// Link to contextual survey metadata file.
const String kContextualSurveyUrl =
    'https://storage.googleapis.com/flutter-uxr/surveys/contextual-survey-metadata.json';

/// Name of the directory where all of the files necessary for this package
/// will be located.
const String kDartToolDirectoryName = '.dart-tool';

/// The default time to wait before closing the http connection to allow for
/// pending events to be sent.
const int kDelayDuration = 250;

/// Name of the file where we persist dismissed survey ids.
const String kDismissedSurveyFileName =
    'dart-flutter-telemetry-dismissed-surveys.json';

/// The API secret associated with the GA4 instance's Measurement Protocol.
const String kGoogleAnalyticsApiSecret = 'Ka1jc8tZSzWc_GXMWHfPHA';

/// The measurement ID related to the GA4 instance.
///
/// Serves as an identifier for a web data stream.
const String kGoogleAnalyticsMeasurementId = 'G-04BXPVBCWJ';

/// How many data records to store in the log file.
const int kLogFileLength = 2500;

/// The maximum allowed size of the telemetry log file.
///
/// 25 MiB.
const int kMaxLogFileSize = 25 * (1 << 20);

/// Filename for the log file to persist sent events on user's machine.
const String kLogFileName = 'dart-flutter-telemetry.log';

/// The current version of the package, should be in line with pubspec version.
const String kPackageVersion = '6.1.2';

/// The minimum length for a session.
const int kSessionDurationMinutes = 30;

/// Name for the json file where the session details will be stored.
const String kSessionFileName = 'dart-flutter-telemetry-session.json';

/// The message that should be shown to the user.
const String kToolsMessage = '''
The {{ toolDescription }} uses Google Analytics to report usage and diagnostic
data along with package dependencies, and crash reporting to send basic crash
reports. This data is used to help improve the Dart platform, Flutter framework,
and related tools.

Telemetry is not sent on the very first run. To disable reporting of telemetry,
run this terminal command:

    {{ toolName }} --disable-analytics

If you opt out of telemetry, an opt-out event will be sent, and then no further
information will be sent. This data is collected in accordance with the Google
Privacy Policy (https://policies.google.com/privacy).
''';

/// The version number for the message below.
///
/// If the message below is altered, the version should be incremented so that
/// users can be prompted with the updated messaging.
const int kToolsMessageVersion = 1;
