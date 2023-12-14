This package is intended to be used on Dart and Flutter related tooling only.
It provides APIs to send events to Google Analytics using the Measurement Protocol.

## Usage

To get started using this package, import at the entrypoint dart file and
initialize with the required parameters.

The example file shows an end-to-end usage guide for using this package and
can be referred to here [unified_analytics_example.dart](example/unified_analytics_example.dart).

**IMPORTANT**: It is best practice to close the http client connection when finished
sending events, otherwise, you may notice that the dart process hangs on exit. The example below
shows how to handle closing the connection via `analytics.close()` method.

[Link to documentation for http client's close method](https://pub.dev/documentation/http/latest/http/Client-class.html)


## Opting In and Out of Analytics Collection

It will be important for each tool to expose a trivial method to
disabling or enabling analytics collection. Based on how the user interacts
with the tool, this can be done through the CLI, IDE, etc. The tool will
then pass a boolean to an API exposed by the package as shown below.

```dart
// Begin by initializing the class
final Analytics analytics = Analytics(...);

// The boolean below simulates the user deciding to opt-out
// of Analytics collection
final bool status = false;

// Call the method to pass the boolean
analytics.setTelemetry(status);
```

## Displaying Consent Message to Users

When a user first uses any tool with this package enabled, the tool using
this package will need to ensure that the user has seen the consent message.
The tool using this package should check with the `Analytics` instance
by invoking the `shouldShowMessage` getter. When this getter returns
`true`, this means that the user has not been enrolled into analytics
collection yet. It is at this point that the tool using this package will
invoke the `getConsentMessage` getter to return a string to share with the
user (each tool will have their own method of displaying the message
through cli stdout, popup modal, etc.). Once the message has been shown,
the tool using this package will need to confirm to the `Analytics` instance
that it has shown the message; it is at this point that the user has
officially been onboarded to analytics collection.



```dart
// Begin by initializing the class near the entrypoint
final Analytics analytics = Analytics(...);

// This conditional should always run; the first time it is run, this
// will return true since the consent message has never been shown
if (analytics.shouldShowMessage) {
  
  // Simulates displaying the message, this will vary from
  // client to client; ie. stdout, popup in IDE, etc.
  print(analytics.getConsentMessage);

  // After receiving confirmation that the message has been
  // displayed, invoking the below method will successfully
  // onboard the tool into the config file and allow for
  // events to be sent on the next creation of the analytics
  // instance
  analytics.clientShowedMessage();
}
```

## Checking User Opt-In Status

Some tools may need to know if the user has opted in for Analytics
collection in order to enable additional functionality. The example below
shows how to check the status.

```dart
// Begin by initializing the class
final Analytics analytics = Analytics(...);

// This getter will return a boolean showing the status;
// print statement used for trivial usage example
print('This user's status: ${analytics.telemetryEnabled}');  // true if opted-in
```

## Checking for New Versions of Consent Message

In the event that the package consent messaging needs has been updated, an
API has been exposed on an instance of `Analytics` that will notify the tool
using this package whether to display the message again.

```dart
// Begin by initializing the class
//
// This is assuming that the tool has already been onboarded
// and that the user has already seen the previous version of
// the consent message
final Analytics analytics = Analytics(...);


// Much like the first example, if there is a new version of
// the tools message that needs to be shown, use the same work
// workflow
if (analytics.shouldShowMessage) {
  
  // Simulates displaying the message, this will vary from
  // client to client; ie. stdout, popup in IDE, etc.
  print(analytics.getConsentMessage);

  // After receiving confirmation that the message has been
  // displayed, invoking the below method will successfully
  // onboard the tool into the config file and allow for
  // events to be sent on the next creation of the analytics
  // instance
  analytics.clientShowedMessage();
}
```

It is important to note events will not be sent if there is a new version of
the consent message.

## Developing Within `package:unified_analytics`

### Adding new data classes

#### User properties
In Google Analytics, new data fields can be collected as user properties 
or events. 

User properties are key-value pairs that can be used to segment users. For example, 
the Flutter channel used. To request that a new user property 
be added, file an issue [using this template](https://github.com/dart-lang/tools/issues/new?template=unified_analytics_user_property.yml). 

To add a new user property, add a new property to the `UserProperty` class 
in the [`user_property.dart` file](./lib/src/user_property.dart). 

#### Events
Events are actions that the user, or tool, performs. In Google Analytics, 
events can have associated data. This event data is stored 
in key-value pairs. 

To request new events, or event data, file an issue 
[using this template](https://github.com/dart-lang/tools/issues/new?template=unified_analytics_event.yml).

To add a new event, create a new field in the `DashEvent` enum (if necessary) in
the [`enums.dart` file](./lib/src/enums.dart). 

Then, add event data, create a new constructor for the `Event` class 
in the [`event.dart` file](./lib/src/event.dart).


### Testing event collection

When contributing to this package, if the developer needs to verify that
events have been sent, the developer should the use development constructor
so that the events being sent are not going into the production instance.

```dart
final Analytics analytics = Analytics.development(...);
```

Reach out to maintainers to get access to the test Google Analytics endpoint.

## Advanced Usage: Querying Locally Persisted Logs

This package enables  tools to persist the events that have been sent
to Google Analytics for logging by default. This can be very helpful if
tools would like to understand the user's activity level across all
related tooling. For example, if querying the locally persisted logs
shows that the user has not been active for N number of days, a tool that
works within an IDE can prompt the user with a survey to understand why their
level of activity has dropped.

The snippet below shows how to invoke the query and a sample response.

```dart
// Begin by initializing the class
final Analytics analytics = Analytics(...);

// Printing the query results returns json formatted
// string to view; data can also be accessed through
// [LogFileStats] getters
print(analytics.logFileStats());
```
Refer to the `LogFileStats` instance [variables](lib/src/log_handler.dart) for details on the result.

Explanation of the each key above

- startDateTime: the earliest event that was sent
- minsFromStartDateTime: the number of minutes elapsed since the earliest message
- endDateTime: the latest, most recent event that was sent
- minsFromEndDateTime: the number of minutes elapsed since the latest message
- sessionCount: count of sessions; sessions have a minimum time of 30 minutes
- flutterChannelCount: count of flutter channels (can be 0 if developer is a Dart dev only)
- toolCount: count of the Dart and Flutter tools sending analytics
- recordCount: count of the total number of events in the log file
- eventCount: counts each unique event and how many times they occurred in the log file