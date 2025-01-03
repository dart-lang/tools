import 'dart:io';

import 'package:yaml/yaml.dart';

import 'util.dart';
import 'yaml_merger.dart';

class CollectCoverageOptions {
  const CollectCoverageOptions({
    required this.uri,
    required this.out,
    required this.connectTimeout,
    required this.scopeOutput,
    required this.waitPaused,
    required this.resumeIsolates,
    required this.includeDart,
    required this.functionCoverage,
    required this.branchCoverage,
  });

  /// Creates a [CollectCoverageOptions] instance from YAML configuration.
  factory CollectCoverageOptions.fromYaml(YamlMap yaml) =>
      CollectCoverageOptions(
        uri: YamlUtils.getString(yaml, 'uri') as String,
        out: YamlUtils.getString(yaml, 'out') as String,
        connectTimeout: YamlUtils.getInt(yaml, 'connect-timeout'),
        scopeOutput: YamlUtils.getStringList(yaml, 'scope-output'),
        waitPaused: YamlUtils.getBool(yaml, 'wait-paused') ?? false,
        resumeIsolates: YamlUtils.getBool(yaml, 'resume-isolates') ?? false,
        includeDart: YamlUtils.getBool(yaml, 'include-dart') ?? false,
        functionCoverage: YamlUtils.getBool(yaml, 'function-coverage') ?? false,
        branchCoverage: YamlUtils.getBool(yaml, 'branch-coverage') ?? false,
      );

  final String host = '127.0.0.1';
  final String port = '8181';
  final String uri;
  final String out;
  final int? connectTimeout;
  final List<String> scopeOutput;
  final bool waitPaused;
  final bool resumeIsolates;
  final bool includeDart;
  final bool functionCoverage;
  final bool branchCoverage;
}

class FormatCoverageOptions {
  const FormatCoverageOptions({
    required this.baseDirectory,
    required this.bazel,
    required this.bazelWorkspace,
    required this.checkIgnore,
    required this.input,
    required this.lcov,
    required this.output,
    required this.packagePath,
    required this.prettyPrint,
    required this.prettyPrintFunc,
    required this.prettyPrintBranch,
    required this.reportOn,
    required this.ignoreFiles,
    required this.sdkRoot,
    required this.verbose,
    required this.workers,
  });

  /// Creates a [FormatCoverageOptions] instance from YAML configuration.
  factory FormatCoverageOptions.fromYaml(YamlMap yaml) => FormatCoverageOptions(
        baseDirectory: YamlUtils.getString(yaml, 'base-directory'),
        bazel: YamlUtils.getBool(yaml, 'bazel') ?? false,
        bazelWorkspace: YamlUtils.getString(yaml, 'bazel-workspace') as String,
        checkIgnore: YamlUtils.getBool(yaml, 'check-ignore') ?? false,
        input: YamlUtils.getString(yaml, 'in'),
        lcov: YamlUtils.getBool(yaml, 'lcov') ?? false,
        output: YamlUtils.getString(yaml, 'out') as String,
        packagePath: YamlUtils.getString(yaml, 'package') as String,
        prettyPrint: YamlUtils.getBool(yaml, 'pretty-print') ?? false,
        prettyPrintFunc: YamlUtils.getBool(yaml, 'pretty-print-func') ?? false,
        prettyPrintBranch:
            YamlUtils.getBool(yaml, 'pretty-print-branch') ?? false,
        reportOn: YamlUtils.getStringList(yaml, 'report-on'),
        ignoreFiles: YamlUtils.getStringList(yaml, 'ignore-files'),
        sdkRoot: YamlUtils.getString(yaml, 'sdk-root'),
        verbose: YamlUtils.getBool(yaml, 'verbose') ?? false,
        workers: YamlUtils.getInt(yaml, 'workers') as int,
      );

  final String? baseDirectory;
  final bool bazel;
  final String bazelWorkspace;
  final bool checkIgnore;
  final String? input;
  final bool lcov;
  final String output;
  final String packagePath;
  final bool prettyPrint;
  final bool prettyPrintFunc;
  final bool prettyPrintBranch;
  final List<String>? reportOn;
  final List<String>? ignoreFiles;
  final String? sdkRoot;
  final bool verbose;
  final int workers;
}

class TestWithCoverageOptions {
  const TestWithCoverageOptions({
    required this.packageDir,
    required this.packageName,
    required this.outDir,
    required this.port,
    required this.testScript,
    required this.functionCoverage,
    required this.branchCoverage,
    required this.scopeOutput,
  });

  /// Creates a [TestWithCoverageOptions] instance from YAML configuration.
  factory TestWithCoverageOptions.fromYaml(YamlMap yaml) =>
      TestWithCoverageOptions(
        packageDir: YamlUtils.getString(yaml, 'package') as String,
        packageName: YamlUtils.getString(yaml, 'package-name'),
        outDir: YamlUtils.getString(yaml, 'out'),
        port: YamlUtils.getString(yaml, 'port') as String,
        testScript: YamlUtils.getString(yaml, 'test') as String,
        functionCoverage: YamlUtils.getBool(yaml, 'function-coverage') ?? false,
        branchCoverage: YamlUtils.getBool(yaml, 'branch-coverage') ?? false,
        scopeOutput: YamlUtils.getStringList(yaml, 'scope-output'),
      );

  final String packageDir;
  final String? packageName;
  final String? outDir;
  final String port;
  final String testScript;
  final bool functionCoverage;
  final bool branchCoverage;
  final List<String> scopeOutput;
}

class CoverageOptions {
  const CoverageOptions({
    required this.collectCoverage,
    required this.formatCoverage,
    required this.testWithCoverage,
  });

  final CollectCoverageOptions collectCoverage;
  final FormatCoverageOptions formatCoverage;
  final TestWithCoverageOptions testWithCoverage;
}

abstract class CoverageOptionsProvider {
  factory CoverageOptionsProvider(
      {final String? optionsFilePath, final Map<String, dynamic>? options}) {
    YamlMap coverageOptions;

    final defaultOptionsProvider = DefaultCoverageOptionsProvider();

    if (options != null) {
      coverageOptions = YamlMap.wrap(options);
    } else {
      final optionsFile =
          _getOptionsFile(optionsFilePath ?? CoverageOptionsProvider.filePath);

      if (optionsFile == null) {
        return defaultOptionsProvider;
      }
      coverageOptions = _getOptionsFromFile(optionsFile);
    }

    final mergedOptions = defaultOptionsProvider.merge(
      defaultOptionsProvider.options,
      coverageOptions,
    );

    return CustomCoverageOptionsProvider(mergedOptions);
  }

  CoverageOptionsProvider._();

  static const filePath = 'coverage_options.yaml';

  static File? _getOptionsFile(String filePath) {
    final file = File(filePath);
    return file.existsSync() ? file : null;
  }

  static YamlMap _getOptionsFromFile(File file) {
    final yamlString = file.readAsStringSync();
    final content = loadYaml(yamlString);

    final options = content is YamlMap ? content['defaults'] : YamlMap.wrap({});

    return options is YamlMap ? options : YamlMap.wrap({});
  }

  YamlMap merge(YamlMap defaults, YamlMap overrides) =>
      Merger().mergeMap(defaults, overrides);

  YamlMap get options;
  CoverageOptions get coverageOptions => CoverageOptions(
        collectCoverage: CollectCoverageOptions.fromYaml(
            options['collect_coverage'] as YamlMap),
        formatCoverage: FormatCoverageOptions.fromYaml(
            options['format_coverage'] as YamlMap),
        testWithCoverage: TestWithCoverageOptions.fromYaml(
            options['test_with_coverage'] as YamlMap),
      );
}

class DefaultCoverageOptionsProvider extends CoverageOptionsProvider {
  DefaultCoverageOptionsProvider() : super._();

  @override
  YamlMap get options => defaultOptions;

  static final defaultOptions = YamlMap.wrap({
    'collect_coverage': {
      'uri': 'http://127.0.0.1:8181/',
      'out': 'stdout',
      'connect-timeout': null,
      'scope-output': List<String>.empty(),
      'wait-paused': false,
      'resume-isolates': false,
      'include-dart': false,
      'function-coverage': false,
      'branch-coverage': false,
    },
    'format_coverage': {
      'base-directory': '.',
      'bazel': false,
      'bazel-workspace': '',
      'check-ignore': false,
      'in': null,
      'lcov': false,
      'out': 'stdout',
      'package': '.',
      'pretty-print': false,
      'pretty-print-func': false,
      'pretty-print-branch': false,
      'report-on': null,
      'ignore-files': List<String>.empty(),
      'sdk-root': null,
      'verbose': false,
      'workers': 1,
    },
    'test_with_coverage': {
      'package': '.',
      'package-name': null,
      'port': '8181',
      'out': null,
      'test': 'test',
      'function-coverage': false,
      'branch-coverage': false,
      'scope-output': List<String>.empty(),
    }
  });
}

class CustomCoverageOptionsProvider extends CoverageOptionsProvider {
  CustomCoverageOptionsProvider(this.options) : super._();

  @override
  final YamlMap options;
}
