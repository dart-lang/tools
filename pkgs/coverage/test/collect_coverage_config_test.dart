import 'package:coverage/src/coverage_options.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  group('defaults when no yaml or command-line args provided', () {
    // Setup
    final defaults = CoverageOptionsProvider.defaultOptions;

    test('collect coverage', () {
      final collectedCoverage = parseArgsCollectCoverage([], defaults);

      expect(collectedCoverage.scopeOutput, defaults.scopeOutput);
      expect(collectedCoverage.functionCoverage, defaults.functionCoverage);
      expect(collectedCoverage.branchCoverage, defaults.branchCoverage);
      expect(collectedCoverage.output, 'stdout');
    });

    test('format coverage', () {
      final formattedCoverage =
          parseArgsFormatCoverage([], defaults);

      expect(formattedCoverage.output, 'stdout');
      expect(formattedCoverage.packagePath, defaults.packagePath);
    });

    test('test with coverage', () async {
      final testCoverage = await parseArgsTestWithCoverage([], defaults);

      expect(testCoverage.packagePath, getPackageDir(defaults.packagePath));
      expect(testCoverage.packageName, 'coverage');
      expect(testCoverage.output, 'coverage');
      expect(testCoverage.testScript, defaults.testScript);
      expect(testCoverage.functionCoverage, defaults.functionCoverage);
      expect(testCoverage.branchCoverage, defaults.branchCoverage);
      expect(testCoverage.scopeOutput, defaults.scopeOutput);
    });
  });

  test('uses yaml values when all values are provided in yaml file', () async {
    final configuredOptions = CoverageOptionsProvider(
      filePath: 'test/test_coverage_options/all_field.yaml',
    ).coverageOptions;

    // Parse arguments with empty command line args
    final collectedCoverage = parseArgsCollectCoverage([], configuredOptions);
    final formattedCoverage =
        parseArgsFormatCoverage([], configuredOptions);
    final testCoverage = await parseArgsTestWithCoverage([], configuredOptions);

    // Verify collect coverage yaml values
    expect(collectedCoverage.scopeOutput, ['lib', 'src']);
    expect(collectedCoverage.functionCoverage, isTrue);
    expect(collectedCoverage.branchCoverage, isFalse);
    expect(collectedCoverage.output, 'coverage/coverage.json');

    // Verify format coverage yaml values
    expect(formattedCoverage.output, 'coverage/lcov.info');
    expect(formattedCoverage.packagePath, '.');

    // Verify test with coverage yaml values
    expect(testCoverage.packagePath, getPackageDir('.'));
    expect(testCoverage.packageName, 'My Dart Package');
    expect(testCoverage.output, 'coverage');
    expect(testCoverage.testScript, 'test');
    expect(testCoverage.functionCoverage, isTrue);
    expect(testCoverage.branchCoverage, isFalse);
    expect(testCoverage.scopeOutput, ['lib', 'src']);
  });

  group('partial yaml configuration', () {
    test('override default values with partial yaml values 1', () async {
      final configuredOptions = CoverageOptionsProvider(
        filePath: 'test/test_coverage_options/partial_fields1.yaml',
      ).coverageOptions;

      // Parse arguments with empty command line args
      final collectedCoverage = parseArgsCollectCoverage([], configuredOptions);
      final testCoverage =
          await parseArgsTestWithCoverage([], configuredOptions);
      final formattedCoverage = parseArgsFormatCoverage([], configuredOptions);

      expect(collectedCoverage.output, 'custom_coverage/coverage.json');
      expect(collectedCoverage.scopeOutput, ['lib', 'test']);
      expect(collectedCoverage.functionCoverage, isFalse);
      expect(formattedCoverage.output, 'custom_coverage/lcov.info');
      expect(testCoverage.packageName, 'Custom Dart Package');
      expect(testCoverage.scopeOutput, ['lib', 'test']);
    });

    test('override default values with partial yaml values 2', () async {
      final configuredOptions = CoverageOptionsProvider(
        filePath: 'test/test_coverage_options/partial_fields2.yaml',
      ).coverageOptions;

      // Parse arguments with empty command line args
      final collectedCoverage = parseArgsCollectCoverage([], configuredOptions);
      final formattedCoverage = parseArgsFormatCoverage([], configuredOptions);
      final testCoverage =
          await parseArgsTestWithCoverage([], configuredOptions);

      // Verify collect coverage yaml values
      expect(collectedCoverage.scopeOutput, ['lib', 'tools']);
      expect(collectedCoverage.branchCoverage, isFalse);
      expect(collectedCoverage.functionCoverage, isTrue);
      expect(collectedCoverage.output, 'custom_lcov/coverage.json');

      // Verify format coverage yaml values
      expect(formattedCoverage.output, 'custom_lcov/lcov.info');
      expect(formattedCoverage.packagePath, '.');

      // Verify test with coverage yaml values
      expect(testCoverage.packageName, 'coverage');
      expect(testCoverage.output, 'custom_lcov');
      expect(testCoverage.testScript, 'custom_test');
      expect(testCoverage.functionCoverage, isTrue);
    });
  });

  test('override yaml values with command line args', () async {
    final configuredOptions = CoverageOptionsProvider(
      filePath: 'test/test_coverage_options/all_field.yaml',
    ).coverageOptions;

    // Parse arguments with command line args
    final collectedCoverage = parseArgsCollectCoverage([
      '--out=coverage.json',
      '--scope-output=lib',
      '--no-function-coverage',
      '--branch-coverage',
    ], configuredOptions);
    final formattedCoverage = parseArgsFormatCoverage([
      '--out=out_test.info',
      '--package=code_builder',
    ], configuredOptions);
    final testCoverage = await parseArgsTestWithCoverage([
      '--package-name=test',
      '--out=test_coverage.json',
      '--test=test_test.dart',
      '--function-coverage',
    ], configuredOptions);

    // Verify collect coverage command line args
    expect(collectedCoverage.output, 'coverage.json');
    expect(collectedCoverage.scopeOutput, ['lib']);
    expect(collectedCoverage.functionCoverage, isFalse);
    expect(collectedCoverage.branchCoverage, isTrue);

    // Verify format coverage command line args
    expect(formattedCoverage.output, 'out_test.info');
    expect(formattedCoverage.packagePath, 'code_builder');

    // Verify test with coverage command line args
    expect(testCoverage.packageName, 'test');
    expect(testCoverage.output, 'test_coverage.json');
    expect(testCoverage.testScript, 'test_test.dart');
    expect(testCoverage.functionCoverage, isTrue);
  });

  test('verify default values with empty yaml file', () async {
    final configuredOptions = CoverageOptionsProvider(
      filePath: 'test/test_coverage_options/empty.yaml',
    ).coverageOptions;

    // Parse arguments with empty command line args
    final collectedCoverage = parseArgsCollectCoverage([], configuredOptions);
    final formattedCoverage =
        parseArgsFormatCoverage([], configuredOptions);
    final testCoverage = await parseArgsTestWithCoverage([], configuredOptions);

    // Verify collect coverage defaults
    expect(collectedCoverage.scopeOutput, isEmpty);
    expect(collectedCoverage.functionCoverage, isFalse);
    expect(collectedCoverage.branchCoverage, isFalse);
    expect(collectedCoverage.output, 'stdout');

    // Verify format coverage defaults
    expect(formattedCoverage.output, 'stdout');
    expect(formattedCoverage.packagePath, '.');

    // Verify test with coverage defaults
    expect(testCoverage.packagePath, getPackageDir('.'));
    expect(testCoverage.packageName, 'coverage');
    expect(testCoverage.output, 'coverage');
    expect(testCoverage.testScript, 'test');
    expect(testCoverage.functionCoverage, isFalse);
    expect(testCoverage.branchCoverage, isFalse);
    expect(testCoverage.scopeOutput, isEmpty);
  });
}
