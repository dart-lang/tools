# get the packages
pub install

# analyze the code
dartanalyzer example/Template.dart
dartanalyzer lib/benchmark_harness.dart
dartanalyzer test/all.dart
dartanalyzer test/benchmark_harness_test.dart

# run the tests
dart test/all.dart
