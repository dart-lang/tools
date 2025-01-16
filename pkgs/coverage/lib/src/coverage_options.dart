import 'dart:io';
import 'package:cli_config/cli_config.dart';

class CoverageOptions {
  const CoverageOptions({
    required this.output,
    required this.scopeOutput,
    required this.functionCoverage,
    required this.branchCoverage,
    required this.packagePath,
    this.packageName,
    required this.testScript,
  });

  factory CoverageOptions.fromConfig(
      Config options, CoverageOptions defaultOptions) {
    return CoverageOptions(
      output: options.optionalString('out') ?? defaultOptions.output,
      scopeOutput: options.optionalStringList('scope_output') ??
          defaultOptions.scopeOutput,
      functionCoverage: options.optionalBool('function_coverage') ??
          defaultOptions.functionCoverage,
      branchCoverage: options.optionalBool('branch_coverage') ??
          defaultOptions.branchCoverage,
      packagePath:
          options.optionalString('package') ?? defaultOptions.packagePath,
      packageName:
          options.optionalString('package_name') ?? defaultOptions.packageName,
      testScript: options.optionalString('test') ?? defaultOptions.testScript,
    );
  }

  final String? output;
  final List<String> scopeOutput;
  final bool functionCoverage;
  final bool branchCoverage;
  final String packagePath;
  final String? packageName;
  final String testScript;
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
    output: null,
    scopeOutput: [],
    functionCoverage: false,
    branchCoverage: false,
    packagePath: '.',
    packageName: null,
    testScript: 'test',
  );
}
