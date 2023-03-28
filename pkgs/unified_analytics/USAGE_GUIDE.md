This package is intended to be used on Dart and Flutter related tooling only.
It provides APIs to send events to Google Analytics using the Measurement Protocol.

## Usage

To get started using this package, import at the entrypoint dart file and
initialize with the required parameters

**IMPORTANT**: It is best practice to close the http client connection when finished
sending events, otherwise, you may notice that the dart process hangs on exit. The example below
shows how to handle closing the connection via `analytics.close()` method

[Link to documentation for http client's close method](https://pub.dev/documentation/http/latest/http/Client-class.html)

```dart
import 'unified_analytics/unified_analytics.dart';

// Constants that should be resolved by the client using package
final DashTool tool = DashTool.flutterTools; // Restricted to enum provided by package

// Values that need to be provided by the client that may
// need to be calculated
final String channel = ...;
final String flutterVersion = ...;
final String dartVersion = ...;

// Initialize the [Analytics] class with the required parameters;
// preferably outside of the [main] method
final Analytics analytics = Analytics(
  tool: tool,
  flutterChannel: channel,  // Optional; only if easy to determine
  flutterVersion: flutterVersion,  // Optional; only if easy to determine
  dartVersion: dartVersion,
);

// Timing a process and sending the event
void main() {
    DateTime start = DateTime.now();
    int count = 0;

    // Example of long running process
    for (int i = 0; i < 2000; i++) {
        count += i;
    }
    
    // Calculate the metric to send
    final int runTime = DateTime.now().difference(start).inMilliseconds;

    // Generate the body for the event data
    final Map<String, int> eventData = {
      'time_ns': runTime,
    };

    // Choose one of the enum values for [DashEvent] which should
    // have all possible events; if not there, open an issue for the
    // team to add
    final DashEvent eventName = ...; // Select appropriate DashEvent enum value

    // Make a call to the [Analytics] api to send the data
    analytics.sendEvent(
      eventName: eventName,
      eventData: eventData,
    );

    // Close the client connection on exit
    analytics.close();
}
```

## Opting In and Out of Analytics Collection

It will be important for each tool to expose a trivial method to
disabling or enabling analytics collection. Based on how the user interacts
with the tool, this can be done through the CLI, IDE, etc. The tool will
then pass a boolean to an API exposed by the package as shown below

```dart
// Begin by initializing the class
final Analytics analytics = Analytics(...);

// The boolean below simulates the user deciding to opt-out
// of Analytics collection
final bool status = false;

// Call the method to pass the boolean
analytics.setTelemetry(status);
```

## Informing Users About Analytics Opt-In Status

When a user first uses any tool with this package enabled, they
will be enrolled into Analytics collection. It will be the responsiblity
of the tool using this package to display the proper Analytics messaging
and inform them on how to Opt-Out of Analytics collection if they wish. The
package will expose APIs that will make it easy to configure Opt-In status.

```dart
// Begin by initializing the class
final Analytics analytics = Analytics(...);

// This should be performed every time the tool starts up
if (analytics.shouldShowMessage) {

  // How each tool displays the message will be unique,
  // print statement used for trivial usage example
  print(analytics.toolsMessage);
}
```

## Checking User Opt-In Status

Some tools may need to know if the user has opted in for Analytics
collection in order to enable additional functionality. The example below
shows how to check the status

```dart
// Begin by initializing the class
final Analytics analytics = Analytics(...);

// This getter will return a boolean showing the status;
// print statement used for trivial usage example
print('This user's status: ${analytics.telemetryEnabled}');  // true if opted-in
```

## Developing Within `package:unified_analytics`

When contributing to this package, if the developer needs to verify that
events have been sent, the developer should the use development constructor
so that the events being sent are not going into the production instance

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

The snippet below shows how to invoke the query and a sample response

```dart
// Begin by initializing the class
final Analytics analytics = Analytics(...);

// Printing the query results returns json formatted
// string to view; data can also be accessed through
// [LogFileStats] getters
print(analytics.logFileStats());

// Prints out the below
// {
//     "startDateTime": "2023-02-22 15:23:24.410921",
//     "minsFromStartDateTime": 20319,
//     "endDateTime": "2023-03-08 15:46:36.318211",
//     "minsFromEndDateTime": 136,
//     "sessionCount": 7,
//     "flutterChannelCount": 2,
//     "toolCount": 1,
//     "recordCount": 23,
//     "eventCount": {
//         "hot_reload_time": 16,
//         "analytics_collection_enabled": 7,
//         ... scales up with number of events
//     }
// }
```

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