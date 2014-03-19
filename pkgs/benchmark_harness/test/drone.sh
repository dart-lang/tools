# get the packages
pub install

# analyze the code
dart tool/hop_runner.dart analyze_all

# run the tests
dart tool/hop_runner.dart test
