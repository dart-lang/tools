// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'constants.dart';
import 'initializer.dart';
import 'utils.dart';

/// The regex pattern used to parse the disable analytics line.
const String telemetryFlagPattern = r'^reporting=([0|1]) *$';

/// The regex pattern used to parse the tools info
/// from the configuration file.
///
/// Example:
/// ```text
/// flutter-tool=2022-10-26,1
/// devtools=2022-11-26,1
/// ```
const String toolPattern =
    r'^([A-Za-z0-9]+[A-Za-z0-9_-]*)=([0-9]{4}-[0-9]{2}-[0-9]{2}),([0-9]+)$';

class ConfigHandler {
  /// Regex pattern implementation for matching a line in the config file.
  static RegExp telemetryFlagRegex =
      RegExp(telemetryFlagPattern, multiLine: true);
  static RegExp toolRegex = RegExp(toolPattern, multiLine: true);

  final FileSystem fs;
  final Directory homeDirectory;
  final File configFile;

  final Map<String, ToolInfo> parsedTools = <String, ToolInfo>{};

  DateTime configFileLastModified;

  /// Reporting enabled unless specified by user
  bool _telemetryEnabled = true;

  ConfigHandler({
    required this.fs,
    required this.homeDirectory,
    required this.configFile,
  }) : configFileLastModified = configFile.lastModifiedSync() {
    // Call the method to parse the contents of the config file when
    // this class is initialized
    parseConfig();
  }

  /// Returns the telemetry state from the config file.
  ///
  /// Method will reparse the config file if it detects that the
  /// last modified datetime is different from what was parsed when
  /// the class was initialized.
  bool get telemetryEnabled {
    if (configFileLastModified.isBefore(configFile.lastModifiedSync())) {
      parseConfig();
      configFileLastModified = configFile.lastModifiedSync();
    }

    return _telemetryEnabled;
  }

  /// Responsibe for the creation of the configuration line
  /// for the tool being passed in by the user and adding a
  /// [ToolInfo] object.
  void addTool({
    required String tool,
    required int versionNumber,
  }) {
    // Create the new instance of [ToolInfo] to be added
    // to the [parsedTools] map
    parsedTools[tool] = ToolInfo(
      lastRun: clock.now(),
      versionNumber: versionNumber,
    );

    // New string to be appended to the bottom of the configuration file
    // with a newline character for new tools to be added
    var newTool = '$tool=$dateStamp,$versionNumber\n';
    if (!configFile.readAsStringSync().endsWith('\n')) {
      newTool = '\n$newTool';
    }
    configFile.writeAsStringSync(newTool, mode: FileMode.append);
    configFileLastModified = configFile.lastModifiedSync();
  }

  /// Will increment the version number and update the date
  /// in the config file for the provided tool name while
  /// also incrementing the version number in [ToolInfo].
  void incrementToolVersion({
    required String tool,
    required int newVersionNumber,
  }) {
    if (!parsedTools.containsKey(tool)) {
      return;
    }

    // Read in the config file contents and use a regex pattern to
    // match the line for the current tool (ie. flutter-tools=2023-01-05,1)
    final configString = configFile.readAsStringSync();
    final pattern = '^($tool)=([0-9]{4}-[0-9]{2}-[0-9]{2}),([0-9]+)\$';

    final regex = RegExp(pattern, multiLine: true);
    final matches = regex.allMatches(configString);

    // If there isn't exactly one match for the given tool, that suggests the
    // file has been altered and needs to be reset
    if (matches.length != 1) {
      resetConfig();
      return;
    }

    // Construct the new tool line for the config line and replace it
    // in the original config string to prep for writing back out
    final newToolString = '$tool=$dateStamp,$newVersionNumber';
    final newConfigString = configString.replaceAll(regex, newToolString);
    configFile.writeAsStringSync(newConfigString);

    final toolInfo = parsedTools[tool];
    if (toolInfo == null) {
      return;
    }

    // Update the [ToolInfo] object for the current tool
    toolInfo.lastRun = clock.now();
    toolInfo.versionNumber = newVersionNumber;
  }

  /// Method responsible for reading in the config file stored on
  /// user's machine and parsing out the following: all the tools that
  /// have been logged in the file, the dates they were last run, and
  /// determining if telemetry is enabled by parsing the file.
  void parseConfig() {
    // Begin with the assumption that telemetry is always enabled
    _telemetryEnabled = true;

    // Read the configuration file as a string and run the two regex patterns
    // on it to get information around which tools have been parsed and whether
    // or not telemetry has been disabled by the user
    final configString = configFile.readAsStringSync();

    // Collect the tools logged in the configuration file
    toolRegex.allMatches(configString).forEach((RegExpMatch element) {
      // Extract the information relevant for the [ToolInfo] class
      final tool = element.group(1) as String;
      final lastRun = DateTime.parse(element.group(2) as String);
      final versionNumber = int.parse(element.group(3) as String);

      // Initialize an instance of the [ToolInfo] class to store
      // in the [parsedTools] map object
      parsedTools[tool] = ToolInfo(
        lastRun: lastRun,
        versionNumber: versionNumber,
      );
    });

    // Check for lines signaling that the user has disabled analytics,
    // if multiple lines are found, the more conservative value will be used
    telemetryFlagRegex.allMatches(configString).forEach((RegExpMatch element) {
      // Conditional for recording telemetry as being disabled
      if (element.group(1) == '0') {
        _telemetryEnabled = false;
      }
    });
  }

  /// This will reset the configuration file and clear the
  /// [parsedTools] map and trigger parsing the config again.
  void resetConfig() {
    createConfigFile(
      configFile: fs.file(p.join(
        homeDirectory.path,
        kDartToolDirectoryName,
        kConfigFileName,
      )),
      fs: fs,
      homeDirectory: homeDirectory,
    );
    parsedTools.clear();
    parseConfig();
  }

  /// Disables the reporting capabilities if [reportingBool] is set to `false`.
  Future<void> setTelemetry(bool reportingBool) async {
    final flag = reportingBool ? '1' : '0';
    final configString = await configFile.readAsString();

    final matches = telemetryFlagRegex.allMatches(configString);

    // If there isn't exactly one match for the reporting flag, that suggests
    // the file has been altered and needs to be reset
    if (matches.length != 1) {
      resetConfig();
      return;
    }

    final newTelemetryString = 'reporting=$flag';

    final newConfigString =
        configString.replaceAll(telemetryFlagRegex, newTelemetryString);

    await configFile.writeAsString(newConfigString);
    configFileLastModified = configFile.lastModifiedSync();

    _telemetryEnabled = reportingBool;
  }
}

class ToolInfo {
  DateTime lastRun;
  int versionNumber;

  ToolInfo({
    required this.lastRun,
    required this.versionNumber,
  });

  @override
  String toString() {
    return json.encode(<String, Object?>{
      'lastRun': DateFormat('yyyy-MM-dd').format(lastRun),
      'versionNumber': versionNumber,
    });
  }
}
