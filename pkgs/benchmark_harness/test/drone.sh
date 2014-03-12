# get the packages
pub install

# analyzer the code
dartanalyzer example/Template.dart
dartanalyzer lib/benchmark_harness.dart
dartanalyzer test/benchmark_harness_test.dart
dartanalyzer test/result_emitter_test.dart

# run the tests
dart test/benchmark_harness_test.dart
dart test/result_emitter_test.dart
