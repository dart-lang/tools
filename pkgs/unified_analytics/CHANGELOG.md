## 0.1.3-dev

- Error handling functionality added to prevent malformed session json data from causing a crash
- Creating a new analytics constructor to point to a test instance of Google Analytics for developers
- Exposing a new instance method that will need to be invoked when a client has successfully shown the consent message to the user `clientShowedMessage()`
- Adding and incrementing a tool's version will automatically use the current consent message version instead of incrementing by 1

## 0.1.2

- Implemented fake Google Analytics Client for `Analytics.test(...)` constructor; marked with visible for testing annotation

## 0.1.1

- Bumping intl package to 0.18.0 to fix version solving issue with flutter_tools
- LogFileStats includes more information about how many events are persisted and total count of how many times each event was sent

## 0.1.0

- Initial version.
