import 'package:test/test.dart';

import 'collect_coverage_api_test.dart' as collect_coverage_api;
import 'collect_coverage_test.dart' as collect_coverage;
import 'lcov_test.dart' as lcov;
import 'resolver_test.dart' as resolver;
import 'run_and_collect_test.dart' as run_and_collect;
import 'util_test.dart' as util;

void main() {
  group('collect_coverage_api', collect_coverage_api.main);
  group('collect_coverage', collect_coverage.main);
  group('lcov', lcov.main);
  group('resolver', resolver.main);
  group('run_and_collect', run_and_collect.main);
  group('util', util.main);
}
