import 'dart:io';
import 'package:cli_config/cli_config.dart';

class CoverageOptions {
  const CoverageOptions({
    required this.output,
    this.connectTimeout,
    required this.scopeOutput,
    required this.resumeIsolates,
    required this.functionCoverage,
    required this.branchCoverage,
    required this.packagePath,
    this.input,
    this.reportOn,
    required this.workers,
    this.baseDirectory,
    required this.prettyPrint,
    required this.lcov,
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
      resumeIsolates: options.optionalBool('resume_isolates') ??
          defaultOptions.resumeIsolates,
      functionCoverage: options.optionalBool('function_coverage') ??
          defaultOptions.functionCoverage,
      branchCoverage: options.optionalBool('branch_coverage') ??
          defaultOptions.branchCoverage,
      packagePath:
          options.optionalString('package') ?? defaultOptions.packagePath,
      input: options.optionalString('in') ?? defaultOptions.input,
      reportOn:
          options.optionalStringList('report_on') ?? defaultOptions.reportOn,
      workers: options.optionalInt('workers') ?? defaultOptions.workers,
      baseDirectory: options.optionalString('base_directory') ??
          defaultOptions.baseDirectory,
      prettyPrint:
          options.optionalBool('pretty_print') ?? defaultOptions.prettyPrint,
      lcov: options.optionalBool('lcov') ?? defaultOptions.lcov,
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
  final bool resumeIsolates;
  final bool functionCoverage;
  final bool branchCoverage;
  final String packagePath;
  final String? input;
  final List<String>? reportOn;
  final int workers;
  final String? baseDirectory;
  final bool prettyPrint;
  final bool lcov;
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
    resumeIsolates: false,
    functionCoverage: false,
    branchCoverage: false,
    packagePath: '.',
    input: null,
    reportOn: null,
    workers: 1,
    baseDirectory: '.',
    prettyPrint: false,
    lcov: false,
    ignoreFiles: [],
    packageName: null,
    testScript: 'test',
    verbose: false,
  );
}
