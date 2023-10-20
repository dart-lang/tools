// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unified_analytics/src/utils.dart';

/// The purpose of this example file is to demonstrate the sampling
/// rate functionality from the survey handler.
///
/// It defines a `remoteUniqueId` that subs in for a real survey's unique
/// ID that is hosted in the remote json file.
///
/// Begin the simulation by setting the `testSampleRate` and `iterations`
/// variables, where `iterations` simulates real users and `testSampleRate`
/// represents a fraction of how many people should be sampled.
///
/// In this example, we have set the `testSampleRate` to `0.3`, meaning we want
/// sample 30% of users, and `iterations` to `10,000`, which simulates `10,000`
/// users.
///
/// Running the script with predefined seed of `123` will
/// generate the below `stdout`
/// ```
/// Test sample rate = 0.3
/// Number of iterations = 10000
/// ---
///
/// Count of iterations sampled (successes) = 3046
/// Actual sample rate = 0.3046
/// ---
///
/// Runtime = 8ms
/// ```
///
/// The actual results yielded 3,046 people selected for a rate
/// of `30.46%` which is about the `30%` defined in `testSampleRate`.
void main() {
  // Seed has been set to replicate results
  //
  // Test with your own seed and alter other parameters
  // as needed
  final uuidGenerator = Uuid(123);

  // Randomly generate an ID that will simulate being used for
  // a given survey
  final remoteUniqueId = uuidGenerator.generateV4();

  // Define a sampling rate that we would like to test
  //
  // Setting 0.3 means any generated doubles less than or
  // equal to 0.3 results in a survey getting delievered
  const testSampleRate = 0.3;

  // Define how many iterations to run, each iteration can
  // be thought of as a developer using a dash tool
  const iterations = 10000;

  // Initializing a counter that will count the number of
  // iterations that were below the sampling rate
  var count = 0;

  final start = DateTime.now();
  for (var i = 0; i < iterations; i++) {
    // Each newly generated ID is simulating a unique
    // developer's CLIENT ID that is persisted on their disk
    final clientId = uuidGenerator.generateV4();

    // Generate a double that will be compared against the sampleRate
    final generatedDouble = sampleRate(remoteUniqueId, clientId);

    // Count successes if the generated double is less than our
    // testing sample rate
    if (generatedDouble <= testSampleRate) {
      count++;
    }
  }
  final end = DateTime.now();

  print('''
Test sample rate = $testSampleRate
Number of iterations = $iterations
---

Count of iterations sampled (successes) = $count
Actual sample rate = ${(count / iterations).toStringAsFixed(4)}
---

Runtime = ${end.difference(start).inMilliseconds}ms
''');
}
