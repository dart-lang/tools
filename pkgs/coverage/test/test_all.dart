import 'package:test/test.dart';

import 'collect_coverage_test.dart' as collect_coverage;
import 'collect_coverage_test.dart' as collect_coverage_api;
import 'lcov_test.dart' as lcov;
import 'util_test.dart' as util;

void main() {
  group('collect_coverage', collect_coverage.main);
  group('collect_coverage_api', collect_coverage_api.main);
  group('lcov', lcov.main);
  group('util', util.main);
}
