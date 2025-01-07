import 'package:coverage/src/coverage_options.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  final defaultInputArgs = <String>['--in=coverage.json'];

  group('defaults when no yaml or command-line args provided', () {
    // Setup
    final defaults = CoverageOptionsProvider.defaultOptions;

    test('collect coverage', () {
      final collectedCoverage = parseArgsCollectCoverage([], defaults);

      expect(collectedCoverage.output, defaults.output);
      expect(collectedCoverage.scopeOutput, defaults.scopeOutput);
      expect(collectedCoverage.resumeIsolates, defaults.resumeIsolates);
      expect(collectedCoverage.waitPaused, defaults.waitPaused);
      expect(collectedCoverage.functionCoverage, defaults.functionCoverage);
      expect(collectedCoverage.branchCoverage, defaults.branchCoverage);
      expect(collectedCoverage.connectTimeout, defaults.connectTimeout);
      expect(collectedCoverage.includeDart, defaults.includeDart);
      expect(collectedCoverage.baseDirectory, defaults.baseDirectory);
      expect(collectedCoverage.bazel, defaults.bazel);
      expect(collectedCoverage.bazelWorkspace, defaults.bazelWorkspace);
      expect(collectedCoverage.checkIgnore, defaults.checkIgnore);
      expect(collectedCoverage.ignoreFiles, defaults.ignoreFiles);
      expect(collectedCoverage.input, defaults.input);
      expect(collectedCoverage.lcov, defaults.lcov);
      expect(collectedCoverage.packagePath, defaults.packagePath);
      expect(collectedCoverage.prettyPrint, defaults.prettyPrint);
      expect(collectedCoverage.prettyPrintFunc, defaults.prettyPrintFunc);
      expect(collectedCoverage.prettyPrintBranch, defaults.prettyPrintBranch);
      expect(collectedCoverage.reportOn, defaults.reportOn);
      expect(collectedCoverage.sdkRoot, defaults.sdkRoot);
      expect(collectedCoverage.verbose, defaults.verbose);
      expect(collectedCoverage.workers, defaults.workers);
    });

    test('format coverage', () {
      final formattedCoverage =
          parseArgsFormatCoverage(defaultInputArgs, defaults);

      expect(formattedCoverage.output, defaults.output);
      expect(formattedCoverage.scopeOutput, defaults.scopeOutput);
      expect(formattedCoverage.resumeIsolates, defaults.resumeIsolates);
      expect(formattedCoverage.waitPaused, defaults.waitPaused);
      expect(formattedCoverage.functionCoverage, defaults.functionCoverage);
      expect(formattedCoverage.branchCoverage, defaults.branchCoverage);
      expect(formattedCoverage.connectTimeout, defaults.connectTimeout);
      expect(formattedCoverage.includeDart, defaults.includeDart);
      expect(formattedCoverage.baseDirectory, defaults.baseDirectory);
      expect(formattedCoverage.bazel, defaults.bazel);
      expect(formattedCoverage.bazelWorkspace, defaults.bazelWorkspace);
      expect(formattedCoverage.checkIgnore, defaults.checkIgnore);
      expect(formattedCoverage.ignoreFiles, defaults.ignoreFiles);
      expect(formattedCoverage.input, 'coverage.json');
      expect(formattedCoverage.lcov, defaults.lcov);
      expect(formattedCoverage.packagePath, defaults.packagePath);
      expect(formattedCoverage.prettyPrint, defaults.prettyPrint);
      expect(formattedCoverage.prettyPrintFunc, defaults.prettyPrintFunc);
      expect(formattedCoverage.prettyPrintBranch, defaults.prettyPrintBranch);
      expect(formattedCoverage.reportOn, defaults.reportOn);
      expect(formattedCoverage.sdkRoot, defaults.sdkRoot);
      expect(formattedCoverage.verbose, defaults.verbose);
      expect(formattedCoverage.workers, defaults.workers);
    });

    test('test with coverage', () async {
      final testCoverage = await parseArgsTestWithCoverage([], defaults);

      expect(testCoverage.output, defaults.output);
      expect(testCoverage.scopeOutput, defaults.scopeOutput);
      expect(testCoverage.resumeIsolates, defaults.resumeIsolates);
      expect(testCoverage.waitPaused, defaults.waitPaused);
      expect(testCoverage.functionCoverage, defaults.functionCoverage);
      expect(testCoverage.branchCoverage, defaults.branchCoverage);
      expect(testCoverage.connectTimeout, defaults.connectTimeout);
      expect(testCoverage.includeDart, defaults.includeDart);
      expect(testCoverage.baseDirectory, defaults.baseDirectory);
      expect(testCoverage.bazel, defaults.bazel);
      expect(testCoverage.bazelWorkspace, defaults.bazelWorkspace);
      expect(testCoverage.checkIgnore, defaults.checkIgnore);
      expect(testCoverage.ignoreFiles, defaults.ignoreFiles);
      expect(testCoverage.input, defaults.input);
      expect(testCoverage.lcov, defaults.lcov);
      expect(testCoverage.packagePath, getPackageDir(defaults.packagePath));
      expect(testCoverage.prettyPrint, defaults.prettyPrint);
      expect(testCoverage.prettyPrintFunc, defaults.prettyPrintFunc);
      expect(testCoverage.prettyPrintBranch, defaults.prettyPrintBranch);
      expect(testCoverage.reportOn, defaults.reportOn);
      expect(testCoverage.sdkRoot, defaults.sdkRoot);
      expect(testCoverage.verbose, defaults.verbose);
      expect(testCoverage.workers, defaults.workers);
    });
  });

  test('uses yaml values when all values are provided in yaml file', () async {
    final configuredOptions = CoverageOptionsProvider(
      filePath: 'test/test_coverage_options/all_field.yaml',
    ).coverageOptions;

    // Parse arguments with empty command line args
    final collectedCoverage = parseArgsCollectCoverage([], configuredOptions);
    final formattedCoverage =
        parseArgsFormatCoverage(defaultInputArgs, configuredOptions);
    final testCoverage = await parseArgsTestWithCoverage([], configuredOptions);

    // Verify collect coverage yaml values
    expect(collectedCoverage.scopeOutput, ['lib', 'src']);
    expect(collectedCoverage.resumeIsolates, isFalse);
    expect(collectedCoverage.waitPaused, isTrue);
    expect(collectedCoverage.functionCoverage, isTrue);
    expect(collectedCoverage.branchCoverage, isFalse);
    expect(collectedCoverage.connectTimeout, 30);
    expect(collectedCoverage.includeDart, isFalse);
    expect(collectedCoverage.output, 'coverage');

    // Verify format coverage yaml values
    expect(formattedCoverage.baseDirectory, '.');
    expect(formattedCoverage.bazel, isFalse);
    expect(formattedCoverage.bazelWorkspace, '');
    expect(formattedCoverage.checkIgnore, isFalse);
    expect(formattedCoverage.input, 'coverage.json');
    expect(formattedCoverage.lcov, isTrue);
    expect(formattedCoverage.output, 'coverage');
    expect(formattedCoverage.packagePath, '.');
    expect(formattedCoverage.prettyPrint, isFalse);
    expect(formattedCoverage.prettyPrintFunc, isFalse);
    expect(formattedCoverage.prettyPrintBranch, isFalse);
    expect(formattedCoverage.reportOn, ['lib', 'bin']);
    expect(formattedCoverage.ignoreFiles, ['test']);
    expect(formattedCoverage.sdkRoot, '.');
    expect(formattedCoverage.verbose, isTrue);
    expect(formattedCoverage.workers, 2);

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
      final formattedCoverage =
          parseArgsFormatCoverage(defaultInputArgs, configuredOptions);
      final testCoverage =
          await parseArgsTestWithCoverage([], configuredOptions);

      // Verify collect coverage yaml values
      expect(collectedCoverage.output, 'custom_coverage.json');
      expect(collectedCoverage.scopeOutput, ['lib', 'test']);
      expect(collectedCoverage.resumeIsolates, isTrue);
      expect(collectedCoverage.functionCoverage, isFalse);
      expect(collectedCoverage.includeDart, isTrue);
      expect(collectedCoverage.connectTimeout, 20);

      // Verify format coverage yaml values
      expect(formattedCoverage.lcov, isFalse);
      expect(formattedCoverage.verbose, isFalse);
      expect(formattedCoverage.baseDirectory, 'src');
      expect(formattedCoverage.ignoreFiles, ['example']);
      expect(formattedCoverage.reportOn, ['lib']);
      expect(formattedCoverage.prettyPrint, isTrue);
      expect(formattedCoverage.prettyPrintFunc, isFalse);

      // Verify test with coverage yaml values
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
      expect(collectedCoverage.includeDart, isFalse);
      expect(collectedCoverage.branchCoverage, isFalse);
      expect(collectedCoverage.waitPaused, isFalse);
      expect(collectedCoverage.connectTimeout, 15);
      expect(collectedCoverage.functionCoverage, isTrue);

      // Verify format coverage yaml values
      expect(formattedCoverage.bazel, isTrue);
      expect(formattedCoverage.checkIgnore, isTrue);
      expect(formattedCoverage.input, 'custom_coverage.json');
      expect(formattedCoverage.output, 'custom_lcov.info');
      expect(formattedCoverage.packagePath, '.');
      expect(formattedCoverage.reportOn, ['src', 'scripts']);
      expect(formattedCoverage.sdkRoot, './dart-sdk');

      // Verify test with coverage yaml values
      expect(testCoverage.packageName, 'coverage');
      expect(testCoverage.output, 'custom_lcov.info');
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
      '--uri=http://localhost:8181/',
      '--out=coverage.json',
      '--scope-output=lib/',
      '--connect-timeout=10',
      '--resume-isolates',
      '--no-wait-paused',
      '--no-function-coverage',
      '--branch-coverage',
    ], configuredOptions);
    final formattedCoverage = parseArgsFormatCoverage([
      '--in=data.json',
      '--out=out_test.info',
      '--report-on=src/',
      '--report-on=src2/',
      '--ignore-files=bin/',
      '--workers=4',
    ], configuredOptions);
    final testCoverage = await parseArgsTestWithCoverage([
      '--package-name=test',
      '--out=test_coverage.json',
      '--port=2589',
      '--test=test_test.dart',
      '--function-coverage',
    ], configuredOptions);

    // Verify collect coverage command line args
    expect(collectedCoverage.output, 'coverage.json');
    expect(collectedCoverage.scopeOutput, ['lib/']);
    expect(collectedCoverage.resumeIsolates, isTrue);
    expect(collectedCoverage.waitPaused, isFalse);
    expect(collectedCoverage.functionCoverage, isFalse);
    expect(collectedCoverage.branchCoverage, isTrue);
    expect(collectedCoverage.connectTimeout, 10);

    // Verify format coverage command line args
    expect(formattedCoverage.input, 'data.json');
    expect(formattedCoverage.output, 'out_test.info');
    expect(formattedCoverage.reportOn, ['src/', 'src2/']);
    expect(formattedCoverage.ignoreFiles, ['bin/']);
    expect(formattedCoverage.workers, 4);

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
        parseArgsFormatCoverage(defaultInputArgs, configuredOptions);
    final testCoverage = await parseArgsTestWithCoverage([], configuredOptions);

    // Verify collect coverage defaults
    expect(collectedCoverage.scopeOutput, isEmpty);
    expect(collectedCoverage.resumeIsolates, isFalse);
    expect(collectedCoverage.waitPaused, isFalse);
    expect(collectedCoverage.functionCoverage, isFalse);
    expect(collectedCoverage.branchCoverage, isFalse);
    expect(collectedCoverage.connectTimeout, isNull);
    expect(collectedCoverage.includeDart, isFalse);
    expect(collectedCoverage.output, 'stdout');

    // Verify format coverage defaults
    expect(formattedCoverage.baseDirectory, '.');
    expect(formattedCoverage.bazel, isFalse);
    expect(formattedCoverage.bazelWorkspace, '');
    expect(formattedCoverage.checkIgnore, isFalse);
    expect(formattedCoverage.input, 'coverage.json');
    expect(formattedCoverage.lcov, isFalse);
    expect(formattedCoverage.output, 'stdout');
    expect(formattedCoverage.packagePath, '.');
    expect(formattedCoverage.prettyPrint, isFalse);
    expect(formattedCoverage.prettyPrintFunc, isFalse);
    expect(formattedCoverage.prettyPrintBranch, isFalse);
    expect(formattedCoverage.reportOn, isNull);
    expect(formattedCoverage.ignoreFiles, isEmpty);
    expect(formattedCoverage.sdkRoot, isNull);
    expect(formattedCoverage.verbose, isFalse);
    expect(formattedCoverage.workers, 1);

    // Verify test with coverage defaults
    expect(testCoverage.packagePath, getPackageDir('.'));
    expect(testCoverage.packageName, 'coverage');
    expect(testCoverage.output, 'stdout');
    expect(testCoverage.testScript, 'test');
    expect(testCoverage.functionCoverage, isFalse);
    expect(testCoverage.branchCoverage, isFalse);
    expect(testCoverage.scopeOutput, isEmpty);
  });
}
