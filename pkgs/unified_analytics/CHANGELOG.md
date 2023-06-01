## 2.0.1-wip

- Allow latest package versions for `file` and `http`.

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

- Initial version.
