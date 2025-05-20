// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:coverage/src/coverage_options.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../bin/collect_coverage.dart' as collect_coverage;
import '../bin/format_coverage.dart' as format_coverage;
import '../bin/test_with_coverage.dart' as test_with_coverage;

void main() {
  final formatCoverageArgs = ['--in=./test/collect_coverage_config_test.dart'];

  group('defaults when no yaml or command-line args provided', () {
    // Setup
    final defaults = CoverageOptionsProvider().coverageOptions;

    test('collect coverage', () {
      final collectedCoverage = collect_coverage.parseArgs([], defaults);

      expect(collectedCoverage.scopedOutput, defaults.scopeOutput);
      expect(collectedCoverage.functionCoverage, defaults.functionCoverage);
      expect(collectedCoverage.branchCoverage, defaults.branchCoverage);
      expect(collectedCoverage.out, isNull);
    });

    test('format coverage', () {
      final formattedCoverage =
          format_coverage.parseArgs(formatCoverageArgs, defaults);

      expect(formattedCoverage.output, isNull);
      expect(formattedCoverage.packagePath, defaults.packageDirectory);
    });

    test('test with coverage', () async {
      final testCoverage = await test_with_coverage.parseArgs([], defaults);

      expect(path.canonicalize(testCoverage.packageDir),
          path.canonicalize(defaults.packageDirectory));
      expect(path.canonicalize(testCoverage.outDir),
          path.canonicalize('coverage'));
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
    final collectedCoverage = collect_coverage.parseArgs([], configuredOptions);
    final formattedCoverage =
        format_coverage.parseArgs(formatCoverageArgs, configuredOptions);
    final testCoverage =
        await test_with_coverage.parseArgs([], configuredOptions);

    // Verify collect coverage yaml values
    expect(collectedCoverage.scopedOutput, ['lib', 'src']);
    expect(collectedCoverage.functionCoverage, isTrue);
    expect(collectedCoverage.branchCoverage, isFalse);
    expect(path.canonicalize(collectedCoverage.out!),
        path.canonicalize('var/coverage_data/coverage.json'));

    // Verify format coverage yaml values
    expect(path.canonicalize(formattedCoverage.output!),
        path.canonicalize('var/coverage_data/lcov.info'));
    expect(path.canonicalize(formattedCoverage.packagePath),
        path.canonicalize('test/test_files'));

    // Verify test with coverage yaml values
    expect(path.canonicalize(testCoverage.packageDir),
        path.canonicalize('test/test_files'));
    expect(path.canonicalize(testCoverage.outDir),
        path.canonicalize('var/coverage_data'));
    expect(testCoverage.testScript, 'test1');
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
      final collectedCoverage =
          collect_coverage.parseArgs([], configuredOptions);
      final testCoverage =
          await test_with_coverage.parseArgs([], configuredOptions);
      final formattedCoverage =
          format_coverage.parseArgs([], configuredOptions);

      expect(path.canonicalize(collectedCoverage.out!),
          path.canonicalize('var/coverage_data/custom_coverage/coverage.json'));
      expect(collectedCoverage.scopedOutput, ['lib', 'test']);
      expect(collectedCoverage.functionCoverage, isFalse);
      expect(path.canonicalize(formattedCoverage.output!),
          path.canonicalize('var/coverage_data/custom_coverage/lcov.info'));
      expect(testCoverage.scopeOutput, ['lib', 'test']);
    });

    test('override default values with partial yaml values 2', () async {
      final configuredOptions = CoverageOptionsProvider(
        filePath: 'test/test_coverage_options/partial_fields2.yaml',
      ).coverageOptions;

      // Parse arguments with empty command line args
      final collectedCoverage =
          collect_coverage.parseArgs([], configuredOptions);
      final formattedCoverage =
          format_coverage.parseArgs([], configuredOptions);
      final testCoverage =
          await test_with_coverage.parseArgs([], configuredOptions);

      // Verify collect coverage yaml values
      expect(collectedCoverage.scopedOutput, ['lib', 'tools']);
      expect(collectedCoverage.branchCoverage, isFalse);
      expect(collectedCoverage.functionCoverage, isTrue);
      expect(path.canonicalize(collectedCoverage.out!),
          path.canonicalize('var/coverage_data/custom_lcov/coverage.json'));

      // Verify format coverage yaml values
      expect(path.canonicalize(formattedCoverage.output!),
          path.canonicalize('var/coverage_data/custom_lcov/lcov.info'));
      expect(path.canonicalize(formattedCoverage.packagePath),
          path.canonicalize('test/test_coverage_options'));

      // Verify test with coverage yaml values
      expect(path.canonicalize(testCoverage.outDir),
          path.canonicalize('var/coverage_data/custom_lcov'));
      expect(testCoverage.testScript, 'custom_test');
      expect(testCoverage.functionCoverage, isTrue);
    });
  });

  group('override yaml values with command line args', () {
    test('override 1', () async {
      final configuredOptions = CoverageOptionsProvider(
        filePath: 'test/test_coverage_options/all_field.yaml',
      ).coverageOptions;

      // Parse arguments with command line args
      final collectedCoverage = collect_coverage.parseArgs([
        '--out=var/coverage_data/coverage.json',
        '--scope-output=lib',
        '--no-function-coverage',
        '--branch-coverage',
      ], configuredOptions);
      final formattedCoverage = format_coverage.parseArgs([
        '--out=var/coverage_data/out_test.info',
        '--package=../code_builder',
      ], configuredOptions);
      final testCoverage = await test_with_coverage.parseArgs([
        '--package-name=test',
        '--out=test_coverage.json',
        '--test=test_test.dart',
        '--function-coverage',
      ], configuredOptions);

      // Verify collect coverage command line args
      expect(collectedCoverage.out,
          path.normalize('var/coverage_data/coverage.json'));
      expect(collectedCoverage.scopedOutput, ['lib']);
      expect(collectedCoverage.functionCoverage, isFalse);
      expect(collectedCoverage.branchCoverage, isTrue);

      // Verify format coverage command line args
      expect(formattedCoverage.output,
          path.normalize('var/coverage_data/out_test.info'));
      expect(formattedCoverage.packagePath, '../code_builder');

      // Verify test with coverage command line args
      expect(testCoverage.outDir, 'test_coverage.json');
      expect(testCoverage.testScript, 'test_test.dart');
      expect(testCoverage.functionCoverage, isTrue);
    });

    test('override 2', () async {
      final configuredOptions = CoverageOptionsProvider(
        filePath: 'test/test_coverage_options/all_field.yaml',
      ).coverageOptions;

      // Parse arguments with command line args
      final collectedCoverage = collect_coverage.parseArgs([
        '--out=stdout',
        '--scope-output=src',
        '--function-coverage',
        '--no-branch-coverage',
      ], configuredOptions);
      final formattedCoverage = format_coverage.parseArgs([
        '--out=stdout',
        '--package=../cli_config',
      ], configuredOptions);
      final testCoverage = await test_with_coverage.parseArgs([
        '--package-name=cli_config',
        '--out=cli_config_coverage.json',
        '--test=cli_config_test.dart',
        '--function-coverage',
      ], configuredOptions);

      // Verify collect coverage command line args
      expect(collectedCoverage.out, isNull);
      expect(collectedCoverage.scopedOutput, ['src']);
      expect(collectedCoverage.functionCoverage, isTrue);
      expect(collectedCoverage.branchCoverage, isFalse);

      // Verify format coverage command line args
      expect(formattedCoverage.output, isNull);
      expect(formattedCoverage.packagePath, '../cli_config');

      // Verify test with coverage command line args
      expect(testCoverage.outDir, 'cli_config_coverage.json');
      expect(testCoverage.testScript, 'cli_config_test.dart');
      expect(testCoverage.functionCoverage, isTrue);
    });
  });

  test('format exception when empty yaml file', () {
    expect(
        () => CoverageOptionsProvider(
              filePath: 'test/test_coverage_options/empty.yaml',
            ),
        throwsFormatException);
  });
}
