import 'package:test/test.dart';

import 'collect_coverage_test.dart' as collect_coverage;
import 'lcov_test.dart' as lcov;
import 'util_test.dart' as util;

void main() {
  group('collect_coverage', collect_coverage.main);
  group('lcov', lcov.main);
  group('util', util.main);
}
