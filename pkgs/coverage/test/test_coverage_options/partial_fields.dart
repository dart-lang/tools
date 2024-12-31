const partialFieldOptions = [
  {
    'collect_coverage': {
      'uri': 'http://127.0.0.1:9000/',
      'out': 'custom_coverage.json',
      'scope-output': ['lib/', 'test/'],
      'resume-isolates': true,
      'function-coverage': false,
      'include-dart': true,
      'connect-timeout': 20
    },
    'format_coverage': {
      'lcov': false,
      'verbose': false,
      'base-directory': './src',
      'ignore-files': ['example/'],
      'report-on': ['lib/'],
      'pretty-print': true,
      'pretty-print-func': false
    },
    'test_with_coverage': {
      'package-name': 'Custom Dart Package',
      'port': 9000,
      'scope-output': ['lib/utils/']
    }
  },
  {
    'collect_coverage': {
      'uri': 'http://127.0.0.1:8500/',
      'scope-output': ['lib/', 'tools/'],
      'include-dart': false,
      'branch-coverage': false,
      'wait-paused': false,
      'connect-timeout': 15
    },
    'format_coverage': {
      'bazel': true,
      'check-ignore': true,
      'in': 'custom_coverage.json',
      'out': 'custom_lcov.info',
      'package': './packages',
      'report-on': ['src/', 'scripts/'],
      'sdk-root': './dart-sdk'
    },
    'test_with_coverage': {
      'package': './packages/custom_package',
      'out': 'custom_test_coverage.json',
      'port': 8500,
      'test': 'custom_test',
      'function-coverage': true
    }
  },
];
