import 'dart:io';
import 'package:cli_config/cli_config.dart';
import 'package:path/path.dart' as path;

class CoverageOptions {
  const CoverageOptions({
    this.outputDirectory,
    required this.scopeOutput,
    required this.functionCoverage,
    required this.branchCoverage,
    required this.packageDirectory,
    this.packageName,
    required this.testScript,
  });

  factory CoverageOptions.fromConfig(
      Config options, CoverageOptions defaultOptions, String? optionsFilePath) {
    var outputDirectory = options.optionalString('output_directory') ??
        defaultOptions.outputDirectory;
    var packageDirectory = options.optionalString('package_directory') ??
        defaultOptions.packageDirectory;

    if (optionsFilePath != null) {
      if (outputDirectory != null && !path.isAbsolute(outputDirectory)) {
        outputDirectory = path.normalize(
            path.absolute(path.dirname(optionsFilePath), outputDirectory));
      }
      if (!path.isAbsolute(packageDirectory)) {
        packageDirectory = path.normalize(
            path.absolute(path.dirname(optionsFilePath), packageDirectory));
      }
    }

    return CoverageOptions(
      outputDirectory: outputDirectory,
      scopeOutput: options.optionalStringList('scope_output') ??
          defaultOptions.scopeOutput,
      functionCoverage: options.optionalBool('function_coverage') ??
          defaultOptions.functionCoverage,
      branchCoverage: options.optionalBool('branch_coverage') ??
          defaultOptions.branchCoverage,
      packageDirectory: packageDirectory,
      packageName:
          options.optionalString('package_name') ?? defaultOptions.packageName,
      testScript:
          options.optionalString('test_script') ?? defaultOptions.testScript,
    );
  }

  final String? outputDirectory;
  final List<String> scopeOutput;
  final bool functionCoverage;
  final bool branchCoverage;
  final String packageDirectory;
  final String? packageName;
  final String testScript;
}

class CoverageOptionsProvider {
  CoverageOptionsProvider({
    String? filePath,
  }) {
    final file = _getOptionsFile(filePath);
    final fileContents = file?.readAsStringSync();

    final isFileEmpty = fileContents?.isEmpty ?? false;

    // Pass null to fileContents if the file is empty
    final options = Config.fromConfigFileContents(
      fileContents: isFileEmpty ? null : fileContents,
      fileSourceUri: file?.uri,
    );

    coverageOptions =
        CoverageOptions.fromConfig(options, defaultOptions, optionsFilePath);
  }

  late final CoverageOptions coverageOptions;
  late final String? optionsFilePath;
  static const defaultFilePath = 'coverage_options.yaml';

  File? _getOptionsFile(String? filePath) {
    filePath ??= _findOptionsFilePath();

    optionsFilePath = filePath != null ? path.canonicalize(filePath) : null;

    if (optionsFilePath == null) {
      return null;
    }

    final file = File(optionsFilePath!);
    return file.existsSync() ? file : null;
  }

  String? _findOptionsFilePath() {
    var currentDir = Directory.current;

    while (true) {
      final pubSpecFilePath = path.join(currentDir.path, 'pubspec.yaml');
      if (File(pubSpecFilePath).existsSync()) {
        return path.join(currentDir.path, defaultFilePath);
      }
      final parentDir = currentDir.parent;
      if (parentDir.path == currentDir.path) {
        return null;
      }
      currentDir = parentDir;
    }
  }

  static const defaultOptions = CoverageOptions(
    outputDirectory: null,
    scopeOutput: [],
    functionCoverage: false,
    branchCoverage: false,
    packageDirectory: '.',
    packageName: null,
    testScript: 'test',
  );
}
