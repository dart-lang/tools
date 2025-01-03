import 'package:coverage/src/coverage_options.dart';
import 'package:test/test.dart';

import 'test_coverage_options/partial_fields.dart';
import 'test_util.dart';

void main() {
  final defaultInputArgs = <String>['--in=coverage.json'];

  test('defaults when no yaml or command-line args provided', () async {
    // Setup
    final defaults = DefaultCoverageOptionsProvider().coverageOptions;
    final configuredOptions = CoverageOptionsProvider().coverageOptions;

    // Parse arguments with empty command line args
    final collectedCoverage =
        parseArgsCollectCoverage([], configuredOptions.collectCoverage);
    final formattedCoverage = parseArgsFormatCoverage(
        defaultInputArgs, configuredOptions.formatCoverage);
    final testCoverage =
        await parseArgsTestWithCoverage([], configuredOptions.testWithCoverage);

    // Verify collect coverage defaults
    expect(collectedCoverage.uri, defaults.collectCoverage.uri,
        reason: 'URI should match default');
    expect(collectedCoverage.scopeOutput, defaults.collectCoverage.scopeOutput,
        reason: 'scope output should match default');
    expect(collectedCoverage.resumeIsolates,
        defaults.collectCoverage.resumeIsolates,
        reason: 'resume isolates should match default');
    expect(collectedCoverage.waitPaused, defaults.collectCoverage.waitPaused,
        reason: 'wait paused should match default');
    expect(collectedCoverage.functionCoverage,
        defaults.collectCoverage.functionCoverage,
        reason: 'function coverage should match default');
    expect(collectedCoverage.branchCoverage,
        defaults.collectCoverage.branchCoverage,
        reason: 'branch coverage should match default');
    expect(collectedCoverage.connectTimeout,
        defaults.collectCoverage.connectTimeout,
        reason: 'connect timeout should match default');
    expect(collectedCoverage.includeDart, defaults.collectCoverage.includeDart,
        reason: 'include dart should match default');
    expect(collectedCoverage.out, defaults.collectCoverage.out,
        reason: 'output path should match default');

    // Verify format coverage defaults
    expect(
        formattedCoverage.baseDirectory, defaults.formatCoverage.baseDirectory,
        reason: 'base directory should match default');
    expect(formattedCoverage.bazel, defaults.formatCoverage.bazel,
        reason: 'bazel flag should match default');
    expect(formattedCoverage.bazelWorkspace,
        defaults.formatCoverage.bazelWorkspace,
        reason: 'bazel workspace should match default');
    expect(formattedCoverage.checkIgnore, defaults.formatCoverage.checkIgnore,
        reason: 'check ignore should match default');
    expect(formattedCoverage.input, 'coverage.json',
        reason: 'input should be coverage.json');
    expect(formattedCoverage.lcov, defaults.formatCoverage.lcov,
        reason: 'lcov flag should match default');
    expect(formattedCoverage.output, defaults.formatCoverage.output,
        reason: 'output path should match default');
    expect(formattedCoverage.packagePath, defaults.formatCoverage.packagePath,
        reason: 'package path should match default');
    expect(formattedCoverage.prettyPrint, defaults.formatCoverage.prettyPrint,
        reason: 'pretty print should match default');
    expect(formattedCoverage.prettyPrintFunc,
        defaults.formatCoverage.prettyPrintFunc,
        reason: 'pretty print func should match default');
    expect(formattedCoverage.prettyPrintBranch,
        defaults.formatCoverage.prettyPrintBranch,
        reason: 'pretty print branch should match default');
    expect(formattedCoverage.reportOn, isNull,
        reason: 'report on should be null');
    expect(formattedCoverage.ignoreFiles, defaults.formatCoverage.ignoreFiles,
        reason: 'ignore files should match default');
    expect(formattedCoverage.sdkRoot, defaults.formatCoverage.sdkRoot,
        reason: 'sdk root should match default');
    expect(formattedCoverage.verbose, defaults.formatCoverage.verbose,
        reason: 'verbose flag should match default');
    expect(formattedCoverage.workers, defaults.formatCoverage.workers,
        reason: 'workers count should match default');

    // Verify test with coverage defaults
    expect(testCoverage.packageDir,
        getPackageDir(defaults.testWithCoverage.packageDir),
        reason: 'package directory should match current directory');
    expect(testCoverage.packageName, 'coverage',
        reason: 'package name should be coverage');
    expect(testCoverage.outDir, 'coverage',
        reason: 'output directory should be coverage');
    expect(testCoverage.port, defaults.testWithCoverage.port,
        reason: 'port should match default');
    expect(testCoverage.testScript, defaults.testWithCoverage.testScript,
        reason: 'test script should match default');
    expect(testCoverage.functionCoverage,
        defaults.testWithCoverage.functionCoverage,
        reason: 'function coverage should match default');
    expect(
        testCoverage.branchCoverage, defaults.testWithCoverage.branchCoverage,
        reason: 'branch coverage should match default');
    expect(testCoverage.scopeOutput, defaults.testWithCoverage.scopeOutput,
        reason: 'scope output should match default');
  });

  test('uses yaml values when all values are provided in yaml file', () async {
    final configuredOptions = CoverageOptionsProvider(
      optionsFilePath: 'test/test_coverage_options/all_field.yaml',
    ).coverageOptions;

    // Parse arguments with empty command line args
    final collectedCoverage =
        parseArgsCollectCoverage([], configuredOptions.collectCoverage);
    final formattedCoverage = parseArgsFormatCoverage(
        defaultInputArgs, configuredOptions.formatCoverage);
    final testCoverage =
        await parseArgsTestWithCoverage([], configuredOptions.testWithCoverage);

    // Verify collect coverage yaml values
    expect(collectedCoverage.uri, 'http://127.0.0.1:8181/');
    expect(collectedCoverage.scopeOutput, ['lib/']);
    expect(collectedCoverage.resumeIsolates, isFalse);
    expect(collectedCoverage.waitPaused, isTrue);
    expect(collectedCoverage.functionCoverage, isTrue);
    expect(collectedCoverage.branchCoverage, isFalse);
    expect(collectedCoverage.connectTimeout, 30);
    expect(collectedCoverage.includeDart, isFalse);
    expect(collectedCoverage.out, 'coverage.json');

    // Verify format coverage yaml values
    expect(formattedCoverage.baseDirectory, '.');
    expect(formattedCoverage.bazel, isFalse);
    expect(formattedCoverage.bazelWorkspace, '');
    expect(formattedCoverage.checkIgnore, isFalse);
    expect(formattedCoverage.input, 'coverage.json');
    expect(formattedCoverage.lcov, isTrue);
    expect(formattedCoverage.output, 'lcov.info');
    expect(formattedCoverage.packagePath, '.');
    expect(formattedCoverage.prettyPrint, isFalse);
    expect(formattedCoverage.prettyPrintFunc, isFalse);
    expect(formattedCoverage.prettyPrintBranch, isFalse);
    expect(formattedCoverage.reportOn, ['lib/', 'bin/']);
    expect(formattedCoverage.ignoreFiles, ['test/']);
    expect(formattedCoverage.sdkRoot, '.');
    expect(formattedCoverage.verbose, isTrue);
    expect(formattedCoverage.workers, 2);

    // Verify test with coverage yaml values
    expect(testCoverage.packageDir, getPackageDir('.'));
    expect(testCoverage.packageName, 'My Dart Package');
    expect(testCoverage.outDir, 'test_coverage.json');
    expect(testCoverage.port, '8181');
    expect(testCoverage.testScript, 'test');
    expect(testCoverage.functionCoverage, isTrue);
    expect(testCoverage.branchCoverage, isFalse);
    expect(testCoverage.scopeOutput, ['lib/src/']);
  });

  group('partial yaml configuration', () {
    final partial1 = partialFieldOptions[0];
    final partial2 = partialFieldOptions[1];

    test('override default values with partial yaml values 1', () async {
      final configuredOptions = CoverageOptionsProvider(
        options: partial1,
      ).coverageOptions;

      // Parse arguments with empty command line args
      final collectedCoverage =
          parseArgsCollectCoverage([], configuredOptions.collectCoverage);
      final formattedCoverage = parseArgsFormatCoverage(
          defaultInputArgs, configuredOptions.formatCoverage);
      final testCoverage = await parseArgsTestWithCoverage(
          [], configuredOptions.testWithCoverage);

      // Verify collect coverage yaml values
      expect(collectedCoverage.uri, partial1['collect_coverage']!['uri']);
      expect(collectedCoverage.out, partial1['collect_coverage']!['out']);
      expect(collectedCoverage.scopeOutput,
          partial1['collect_coverage']!['scope-output']);
      expect(collectedCoverage.resumeIsolates,
          partial1['collect_coverage']!['resume-isolates']);
      expect(collectedCoverage.functionCoverage,
          partial1['collect_coverage']!['function-coverage']);
      expect(collectedCoverage.includeDart,
          partial1['collect_coverage']!['include-dart']);
      expect(collectedCoverage.connectTimeout,
          partial1['collect_coverage']!['connect-timeout']);

      // Verify format coverage yaml values
      expect(formattedCoverage.lcov, partial1['format_coverage']!['lcov']);
      expect(
          formattedCoverage.verbose, partial1['format_coverage']!['verbose']);
      expect(formattedCoverage.baseDirectory,
          partial1['format_coverage']!['base-directory']);
      expect(formattedCoverage.ignoreFiles,
          partial1['format_coverage']!['ignore-files']);
      expect(formattedCoverage.reportOn,
          partial1['format_coverage']!['report-on']);
      expect(formattedCoverage.prettyPrint,
          partial1['format_coverage']!['pretty-print']);
      expect(formattedCoverage.prettyPrintFunc,
          partial1['format_coverage']!['pretty-print-func']);

      // Verify test with coverage yaml values
      expect(testCoverage.packageName,
          partial1['test_with_coverage']!['package-name']);
      expect(testCoverage.port,
          partial1['test_with_coverage']!['port'].toString());
      expect(testCoverage.scopeOutput,
          partial1['test_with_coverage']!['scope-output']);
    });

    test('override default values with partial yaml values 2', () async {
      final configuredOptions = CoverageOptionsProvider(
        options: partial2,
      ).coverageOptions;

      // Parse arguments with empty command line args
      final collectedCoverage =
          parseArgsCollectCoverage([], configuredOptions.collectCoverage);
      final formattedCoverage = parseArgsFormatCoverage(
          defaultInputArgs, configuredOptions.formatCoverage);
      final testCoverage = await parseArgsTestWithCoverage(
          [], configuredOptions.testWithCoverage);

      // Verify collect coverage yaml values
      expect(collectedCoverage.uri, partial2['collect_coverage']!['uri']);
      expect(collectedCoverage.scopeOutput,
          partial2['collect_coverage']!['scope-output']);
      expect(collectedCoverage.includeDart,
          partial2['collect_coverage']!['include-dart']);
      expect(collectedCoverage.branchCoverage,
          partial2['collect_coverage']!['branch-coverage']);
      expect(collectedCoverage.waitPaused,
          partial2['collect_coverage']!['wait-paused']);
      expect(collectedCoverage.connectTimeout,
          partial2['collect_coverage']!['connect-timeout']);

      // Verify format coverage yaml values
      expect(formattedCoverage.bazel, partial2['format_coverage']!['bazel']);
      expect(formattedCoverage.checkIgnore,
          partial2['format_coverage']!['check-ignore']);
      expect(formattedCoverage.input, 'coverage.json');
      expect(formattedCoverage.output, partial2['format_coverage']!['out']);
      expect(formattedCoverage.packagePath,
          partial2['format_coverage']!['package']);
      expect(formattedCoverage.reportOn,
          partial2['format_coverage']!['report-on']);
      expect(
          formattedCoverage.sdkRoot, partial2['format_coverage']!['sdk-root']);

      // Verify test with coverage yaml values
      expect(testCoverage.packageDir,
          getPackageDir(partial2['test_with_coverage']!['package'] as String));
      expect(testCoverage.outDir, partial2['test_with_coverage']!['out']);
      expect(testCoverage.port,
          partial2['test_with_coverage']!['port'].toString());
      expect(testCoverage.testScript, partial2['test_with_coverage']!['test']);
      expect(testCoverage.functionCoverage,
          partial2['test_with_coverage']!['function-coverage']);
    });
  });

  test('override yaml values with command line args', () async {
    final configuredOptions = CoverageOptionsProvider(
      optionsFilePath: 'test/test_coverage_options/all_field.yaml',
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
    ], configuredOptions.collectCoverage);
    final formattedCoverage = parseArgsFormatCoverage([
      '--in=data.json',
      '--out=out_test.info',
      '--report-on=src/',
      '--report-on=src2/',
      '--ignore-files=bin/',
      '--workers=4',
    ], configuredOptions.formatCoverage);
    final testCoverage = await parseArgsTestWithCoverage([
      '--package-name=test',
      '--out=test_coverage.json',
      '--port=2589',
      '--test=test_test.dart',
      '--function-coverage',
    ], configuredOptions.testWithCoverage);

    // Verify collect coverage command line args
    expect(collectedCoverage.uri, 'http://localhost:8181/');
    expect(collectedCoverage.out, 'coverage.json');
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
    expect(testCoverage.outDir, 'test_coverage.json');
    expect(testCoverage.port, '2589');
    expect(testCoverage.testScript, 'test_test.dart');
    expect(testCoverage.functionCoverage, isTrue);
  });

  test('verify default values with empty yaml file', () async {
    final configuredOptions = CoverageOptionsProvider(
      optionsFilePath: 'test/test_coverage_options/empty.yaml',
    ).coverageOptions;

    // Parse arguments with empty command line args
    final collectedCoverage =
        parseArgsCollectCoverage([], configuredOptions.collectCoverage);
    final formattedCoverage = parseArgsFormatCoverage(
        defaultInputArgs, configuredOptions.formatCoverage);
    final testCoverage =
        await parseArgsTestWithCoverage([], configuredOptions.testWithCoverage);

    // Verify collect coverage defaults
    expect(collectedCoverage.uri, 'http://127.0.0.1:8181/');
    expect(collectedCoverage.scopeOutput, isEmpty);
    expect(collectedCoverage.resumeIsolates, isFalse);
    expect(collectedCoverage.waitPaused, isFalse);
    expect(collectedCoverage.functionCoverage, isFalse);
    expect(collectedCoverage.branchCoverage, isFalse);
    expect(collectedCoverage.connectTimeout, isNull);
    expect(collectedCoverage.includeDart, isFalse);
    expect(collectedCoverage.out, 'stdout');

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
    expect(testCoverage.packageDir, getPackageDir('.'));
    expect(testCoverage.packageName, 'coverage');
    expect(testCoverage.outDir, 'coverage');
    expect(testCoverage.port, '8181');
    expect(testCoverage.testScript, 'test');
    expect(testCoverage.functionCoverage, isFalse);
    expect(testCoverage.branchCoverage, isFalse);
    expect(testCoverage.scopeOutput, isEmpty);
  });

  test('verify invalid yaml file', () async {
    expect(
      () => CoverageOptionsProvider(
        optionsFilePath: 'test/test_coverage_options/partial_fields.dart',
      ).coverageOptions,
      throwsA(isA<FormatException>()),
    );
  });

  test('host, port, and uri for collect coverage', () {
    var configuredOptions = CoverageOptionsProvider(options: {
      'collect_coverage': {
        'uri': 'http://127.0.0.1:8181/',
      },
    }).coverageOptions;

    var collectedCoverage = parseArgsCollectCoverage([
      '--host=localhost',
      '--port=8181',
    ], configuredOptions.collectCoverage);

    expect(collectedCoverage.uri, 'http://localhost:8181/');

    collectedCoverage = parseArgsCollectCoverage([
      '--uri=http://localhost:8181/',
    ], configuredOptions.collectCoverage);

    expect(collectedCoverage.uri, 'http://localhost:8181/');

    configuredOptions = CoverageOptionsProvider(options: {
      'collect_coverage': {
        'uri': 'http://127.0.0.1:8181/',
      },
    }).coverageOptions;

    collectedCoverage = parseArgsCollectCoverage([
      '--uri=http://localhost:8181/',
    ], configuredOptions.collectCoverage);

    expect(collectedCoverage.uri, 'http://localhost:8181/');

    configuredOptions = CoverageOptionsProvider(options: {
      'collect_coverage': {
        'uri': 'http://test.com:8181/',
      },
    }).coverageOptions;

    collectedCoverage = parseArgsCollectCoverage([
      '--host=localhost',
      '--port=8181',
      '--uri=http://127.0.0.1:8181/',
    ], configuredOptions.collectCoverage);

    expect(collectedCoverage.uri, 'http://127.0.0.1:8181/');

    configuredOptions = CoverageOptionsProvider(options: {}).coverageOptions;

    collectedCoverage =
        parseArgsCollectCoverage([], configuredOptions.collectCoverage);

    expect(collectedCoverage.uri, 'http://127.0.0.1:8181/');
  });
}
