import 'dart:io';
import 'package:cli_config/cli_config.dart';

class CoverageOptions {
  const CoverageOptions({
    required this.output,
    this.connectTimeout,
    required this.scopeOutput,
    required this.waitPaused,
    required this.resumeIsolates,
    required this.includeDart,
    required this.functionCoverage,
    required this.branchCoverage,
    this.sdkRoot,
    required this.packagePath,
    this.input,
    this.reportOn,
    required this.workers,
    required this.bazelWorkspace,
    this.baseDirectory,
    required this.bazel,
    required this.prettyPrint,
    required this.prettyPrintFunc,
    required this.prettyPrintBranch,
    required this.lcov,
    required this.checkIgnore,
    required this.ignoreFiles,
    this.packageName,
    required this.testScript,
    required this.verbose,
  });

  factory CoverageOptions.fromConfig(
      Config options, CoverageOptions defaultOptions) {
    return CoverageOptions(
      output: options.optionalString('out') ?? defaultOptions.output,
      connectTimeout: options.optionalInt('connect_timeout') ??
          defaultOptions.connectTimeout,
      scopeOutput: options.optionalStringList('scope_output') ??
          defaultOptions.scopeOutput,
      waitPaused:
          options.optionalBool('wait_paused') ?? defaultOptions.waitPaused,
      resumeIsolates: options.optionalBool('resume_isolates') ??
          defaultOptions.resumeIsolates,
      includeDart:
          options.optionalBool('include_dart') ?? defaultOptions.includeDart,
      functionCoverage: options.optionalBool('function_coverage') ??
          defaultOptions.functionCoverage,
      branchCoverage: options.optionalBool('branch_coverage') ??
          defaultOptions.branchCoverage,
      sdkRoot: options.optionalString('sdk_root') ?? defaultOptions.sdkRoot,
      packagePath:
          options.optionalString('package') ?? defaultOptions.packagePath,
      input: options.optionalString('in') ?? defaultOptions.input,
      reportOn:
          options.optionalStringList('report_on') ?? defaultOptions.reportOn,
      workers: options.optionalInt('workers') ?? defaultOptions.workers,
      bazelWorkspace: options.optionalString('bazel_workspace') ??
          defaultOptions.bazelWorkspace,
      baseDirectory: options.optionalString('base_directory') ??
          defaultOptions.baseDirectory,
      bazel: options.optionalBool('bazel') ?? defaultOptions.bazel,
      prettyPrint:
          options.optionalBool('pretty_print') ?? defaultOptions.prettyPrint,
      prettyPrintFunc: options.optionalBool('pretty_print_func') ??
          defaultOptions.prettyPrintFunc,
      prettyPrintBranch: options.optionalBool('pretty_print_branch') ??
          defaultOptions.prettyPrintBranch,
      lcov: options.optionalBool('lcov') ?? defaultOptions.lcov,
      checkIgnore:
          options.optionalBool('check_ignore') ?? defaultOptions.checkIgnore,
      ignoreFiles: options.optionalStringList('ignore_files') ??
          defaultOptions.ignoreFiles,
      packageName:
          options.optionalString('package_name') ?? defaultOptions.packageName,
      testScript: options.optionalString('test') ?? defaultOptions.testScript,
      verbose: options.optionalBool('verbose') ?? defaultOptions.verbose,
    );
  }

  final String output;
  final int? connectTimeout;
  final List<String> scopeOutput;
  final bool waitPaused;
  final bool resumeIsolates;
  final bool includeDart;
  final bool functionCoverage;
  final bool branchCoverage;
  final String? sdkRoot;
  final String packagePath;
  final String? input;
  final List<String>? reportOn;
  final int workers;
  final String bazelWorkspace;
  final String? baseDirectory;
  final bool bazel;
  final bool prettyPrint;
  final bool prettyPrintFunc;
  final bool prettyPrintBranch;
  final bool lcov;
  final bool checkIgnore;
  final List<String> ignoreFiles;
  final String? packageName;
  final String testScript;
  final bool verbose;
}

class CoverageOptionsProvider {
  CoverageOptionsProvider({
    String? filePath,
  }) {
    final file = _getOptionsFile(filePath ?? CoverageOptionsProvider.filePath);
    final fileContents = file?.readAsStringSync();

    final isFileEmpty = fileContents?.isEmpty ?? false;

    // Pass null to fileContents if the file is empty
    final options = Config.fromConfigFileContents(
      fileContents: isFileEmpty ? null : fileContents,
      fileSourceUri: file?.uri,
    );

    coverageOptions = CoverageOptions.fromConfig(options, defaultOptions);
  }

  late final CoverageOptions coverageOptions;

  static const filePath = 'coverage.yaml';

  static File? _getOptionsFile(String filePath) {
    final file = File(filePath);
    return file.existsSync() ? file : null;
  }

  static const defaultOptions = CoverageOptions(
    output: 'stdout',
    connectTimeout: null,
    scopeOutput: [],
    waitPaused: false,
    resumeIsolates: false,
    includeDart: false,
    functionCoverage: false,
    branchCoverage: false,
    sdkRoot: null,
    packagePath: '.',
    input: null,
    reportOn: null,
    workers: 1,
    bazelWorkspace: '',
    baseDirectory: '.',
    bazel: false,
    prettyPrint: false,
    prettyPrintFunc: false,
    prettyPrintBranch: false,
    lcov: false,
    checkIgnore: false,
    ignoreFiles: [],
    packageName: null,
    testScript: 'test',
    verbose: false,
  );
}
