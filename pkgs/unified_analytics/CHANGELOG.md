## 5.8.8+1

- Edit to error handler to not use default `Analytic.send` method and use new `Analytics._sendError` method that doesn't create a session id

## 5.8.8

- [Bug fix](https://github.com/dart-lang/tools/issues/252) rewrite the other call site for the session file

## 5.8.7

- [Bug fix](https://github.com/dart-lang/tools/issues/252) to rewrite the `last_ping` key into the session json file

## 5.8.6

- Refactored session handler class to use the last modified timestamp as the last ping value
- Bumping intl package to 0.19.0 to fix version solving issue with flutter_tools

## 5.8.5

- Fix late initialization error for `Analytics.userProperty` [bug](https://github.com/dart-lang/tools/issues/238)

## 5.8.4

- Exporting all enums from [`enums.dart`](https://github.com/dart-lang/tools/blob/main/pkgs/unified_analytics/lib/src/enums.dart) through `lib/testing.dart`

## 5.8.3

- [Fix bug](https://github.com/flutter/flutter/issues/143792) when parsing session json file

## 5.8.2

- Added new event `Event.analyticsException` to track internal errors for this package
- Redirecting the `Analytics.test` factory to return an instance of `FakeAnalytics`
- Exposing new helper function that can be used to parse the Dart SDK version

## 5.8.1

- Refactor logic for `okToSend` and `shouldShowMessage`
- Check devtools config file for legacy opt out status

## 5.8.0

- Fix template string for consent message
- Add `enabledFeatures` to constructor to collect features enabled for each dash tool

## 5.7.0

- Added the `Event.commandUsageValues` constructor

## 5.6.0

- Added the `Event.timing` constructor

## 5.5.0

- Edit to the `Event.flutterCommandResult` constructor to add `commandHasTerminal`
- Added timeout for `Analytics.setTelemetry` to prevent the clients from hanging
- Added the `Event.appleUsageEvent` constructor
- Added the `Event.exception` constructor

## 5.4.0

- Added the `Event.codeSizeAnalysis` constructor

## 5.3.0

- User property "host_os_version" added to provide detail version information about the host
- User property "locale" added to provide language related information
- User property "client_ide" (optional) added to provide the IDE used by the Dash tool using this package, if applicable
- Added the `Event.flutterCommandResult` constructor

## 5.2.0

- Added the `Event.hotRunnerInfo` constructor

## 5.1.0

- Added the `Event.flutterBuildInfo` constructor

## 5.0.0

- Update to the latest version of `package:dart_flutter_team_lints`
- Using internal futures list to store send events
- Added the `Event.doctorValidatorResult` constructor

## 4.0.1

- Adding constant for the NoOpAnalytics instance client ID to enable clients to reference it in tests

## 4.0.0

- Enhanced `LogFileStats` data to include information about flutter channel counts and tool counts
- Added new method to suppress telemetry collection temporarily for current invocation via `analytics.suppressTelemetry()`
- Added `SurveyHandler` feature to `Analytics` instance to fetch available surveys from remote endpoint to display to users along with functionality to dismiss them
- Surveys will be disabled for any users that have been opted out
- Shipping `FakeAnalytics` for clients of this tool that need to ensure workflows are sending events in tests
- Adding getter to `Analytics` instance to fetch the client ID being sent to GA4

## 3.0.0

- Allow latest package versions for `file` and `http`
- Introducing new `Event` class that will standardize what event data can be sent with each event
- Deprecating the `sendEvent` method in favor of the `send` method

## 2.0.0

- Refactoring `dateStamp` utility function to be defined in `utils.dart` instead of having static methods in `Initializer` and `ConfigHandler`
- Remove the `pddFlag` now that the revisions to the PDD have been finalized to persist data in the log file and session json file
- Opting out will now delete the contents of the CLIENT ID, session json, and log files; opting back in will regenerate them as events send
- `enableAsserts` parameter added to constructors for `Analytics` to check body of POST request for Google Analytics 4 limitations
- Now checking if write permissions are enabled for user's home directory, if not allowed, `NoOpAnalytics` returned by `Analytics` factory constructor

## 1.1.0

- Added a `okToSend` getter so that clients can easily and accurately check the state of the consent mechanism.
- Initialize the config file with user opted out if user was opted out in legacy Flutter and Dart analytics

## 1.0.1

- Error handling on the `analytics.sendEvent(...)` method to silently error out and return a `500` http status code to let tools using this package know Google Analytics did not receive the event (all successful requests will have a status code of `2xx` provided by Google Analytics)

## 1.0.0

- Error handling functionality added to prevent malformed session json data from causing a crash
- Creating a new analytics constructor to point to a test instance of Google Analytics for developers
- Align supported tool list with PDD
- Exposing a new instance method that will need to be invoked when a client has successfully shown the consent message to the user `clientShowedMessage()`
- Adding and incrementing a tool's version will automatically use the current consent message version instead of incrementing by 1
- Default constructor has disabled the usage of local log file and session json file until revisions have landed to the privacy document

## 0.1.2

- Implemented fake Google Analytics Client for `Analytics.test(...)` constructor; marked with visible for testing annotation

## 0.1.1

- Bumping intl package to 0.18.0 to fix version solving issue with flutter_tools
- LogFileStats includes more information about how many events are persisted and total count of how many times each event was sent

## 0.1.0

- Initial version
