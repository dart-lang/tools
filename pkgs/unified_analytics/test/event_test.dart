// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/src/event.dart';

void main() {
  test('Event.analysisStatistics constructed', () {
    Event generateEvent() => Event.analysisStatistics(
      workingDuration: 'workingDuration',
      withFineDependencies: false,
      changedFileEventCount: 1,
      removedFileEventCount: 2,
      changedFileUniqueCount: 3,
      removedFileUniqueCount: 4,
      immediateFileCountPercentiles: 'immediateFileCountPercentiles',
      immediateFileLineCountPercentiles: 'immediateFileLineCountPercentiles',
      transitiveFileCountPercentiles: 'transitiveFileCountPercentiles',
      transitiveFileLineCountPercentiles: 'transitiveFileLineCountPercentiles',
      produceErrorsPotentialFileCount: 10,
      produceErrorsPotentialFileLineCount: 11,
      produceErrorsActualFileCount: 12,
      produceErrorsActualFileLineCount: 13,
      produceErrorsDurationMs: 14,
      produceErrorsElementsDurationMs: 15,
      libraryDiagnosticsBundleFailures: 'id1:1,id2:2',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.analysisStatistics);
    expect(constructedEvent.eventData['workingDuration'], 'workingDuration');
    expect(constructedEvent.eventData['withFineDependencies'], false);
    expect(constructedEvent.eventData['changedFileEventCount'], 1);
    expect(constructedEvent.eventData['removedFileEventCount'], 2);
    expect(constructedEvent.eventData['changedFileUniqueCount'], 3);
    expect(constructedEvent.eventData['removedFileUniqueCount'], 4);
    expect(
      constructedEvent.eventData['immediateFileCountPercentiles'],
      'immediateFileCountPercentiles',
    );
    expect(
      constructedEvent.eventData['immediateFileLineCountPercentiles'],
      'immediateFileLineCountPercentiles',
    );
    expect(
      constructedEvent.eventData['transitiveFileCountPercentiles'],
      'transitiveFileCountPercentiles',
    );
    expect(
      constructedEvent.eventData['transitiveFileLineCountPercentiles'],
      'transitiveFileLineCountPercentiles',
    );
    expect(constructedEvent.eventData['produceErrorsPotentialFileCount'], 10);
    expect(
      constructedEvent.eventData['produceErrorsPotentialFileLineCount'],
      11,
    );
    expect(constructedEvent.eventData['produceErrorsActualFileCount'], 12);
    expect(constructedEvent.eventData['produceErrorsActualFileLineCount'], 13);
    expect(constructedEvent.eventData['produceErrorsDurationMs'], 14);
    expect(constructedEvent.eventData['produceErrorsElementsDurationMs'], 15);
    expect(
      constructedEvent.eventData['libraryDiagnosticsBundleFailures'],
      'id1:1,id2:2',
    );
    expect(constructedEvent.eventData.length, 17);
  });

  test('Event.analyticsCollectionEnabled constructed', () {
    Event generateEvent() => Event.analyticsCollectionEnabled(status: false);

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.analyticsCollectionEnabled);
    expect(constructedEvent.eventData['status'], false);
    expect(constructedEvent.eventData.length, 1);
  });

  test('Event.clientNotification constructed', () {
    Event generateEvent() => Event.clientNotification(
      duration: 'duration',
      latency: 'latency',
      method: 'method',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.clientNotification);
    expect(constructedEvent.eventData['duration'], 'duration');
    expect(constructedEvent.eventData['latency'], 'latency');
    expect(constructedEvent.eventData['method'], 'method');
    expect(constructedEvent.eventData.length, 3);
  });

  test('Event.clientRequest constructed', () {
    Event generateEvent() => Event.clientRequest(
      duration: 'duration',
      latency: 'latency',
      method: 'method',
      added: 'added',
      excluded: 'excluded',
      files: 'files',
      included: 'included',
      openWorkspacePaths: 'openWorkspacePaths',
      removed: 'removed',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.clientRequest);
    expect(constructedEvent.eventData['duration'], 'duration');
    expect(constructedEvent.eventData['latency'], 'latency');
    expect(constructedEvent.eventData['method'], 'method');
    expect(constructedEvent.eventData['added'], 'added');
    expect(constructedEvent.eventData['excluded'], 'excluded');
    expect(constructedEvent.eventData['files'], 'files');
    expect(constructedEvent.eventData['included'], 'included');
    expect(
      constructedEvent.eventData['openWorkspacePaths'],
      'openWorkspacePaths',
    );
    expect(constructedEvent.eventData['removed'], 'removed');
    expect(constructedEvent.eventData.length, 9);
  });

  test('Event.commandExecuted constructed', () {
    Event generateEvent() => Event.commandExecuted(count: 5, name: 'name');

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.commandExecuted);
    expect(constructedEvent.eventData['count'], 5);
    expect(constructedEvent.eventData['name'], 'name');
    expect(constructedEvent.eventData.length, 2);
  });

  test('Event.contextStructure constructed', () {
    Event generateEvent() => Event.contextStructure(
      immediateFileCount: 1,
      immediateFileLineCount: 2,
      numberOfContexts: 3,
      transitiveFileCount: 4,
      transitiveFileLineCount: 5,
      transitiveFileUniqueCount: 6,
      transitiveFileUniqueLineCount: 7,
      libraryCycleLibraryCounts: 'a',
      libraryCycleLineCounts: 'b',
      contextWorkspaceType: '[0,1,2]',
      numberOfPackagesInWorkspace: '32',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.contextStructure);
    expect(constructedEvent.eventData['immediateFileCount'], 1);
    expect(constructedEvent.eventData['immediateFileLineCount'], 2);
    expect(constructedEvent.eventData['numberOfContexts'], 3);
    expect(constructedEvent.eventData['transitiveFileCount'], 4);
    expect(constructedEvent.eventData['transitiveFileLineCount'], 5);
    expect(constructedEvent.eventData['transitiveFileUniqueCount'], 6);
    expect(constructedEvent.eventData['transitiveFileUniqueLineCount'], 7);
    expect(constructedEvent.eventData['libraryCycleLibraryCounts'], 'a');
    expect(constructedEvent.eventData['libraryCycleLineCounts'], 'b');
    expect(constructedEvent.eventData['contextWorkspaceType'], '[0,1,2]');
    expect(constructedEvent.eventData['numberOfPackagesInWorkspace'], '32');
    expect(constructedEvent.eventData['minSdkConstraints'], '');
    expect(constructedEvent.eventData['languageVersionOverrides'], '');
    expect(constructedEvent.eventData.length, 13);
  });

  test('Event.contextStructure constructed with optional parameters', () {
    Event generateEvent() => Event.contextStructure(
      immediateFileCount: 1,
      immediateFileLineCount: 2,
      numberOfContexts: 3,
      transitiveFileCount: 4,
      transitiveFileLineCount: 5,
      transitiveFileUniqueCount: 6,
      transitiveFileUniqueLineCount: 7,
      libraryCycleLibraryCounts: 'a',
      libraryCycleLineCounts: 'b',
      contextWorkspaceType: '[0,1,2]',
      numberOfPackagesInWorkspace: '32',
      minSdkConstraints: '{"2.12.0":5,"3.0.0":2}',
      languageVersionOverrides: '{"2.12":5,"3.10":2}',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.contextStructure);
    expect(constructedEvent.eventData['immediateFileCount'], 1);
    expect(constructedEvent.eventData['immediateFileLineCount'], 2);
    expect(constructedEvent.eventData['numberOfContexts'], 3);
    expect(constructedEvent.eventData['transitiveFileCount'], 4);
    expect(constructedEvent.eventData['transitiveFileLineCount'], 5);
    expect(constructedEvent.eventData['transitiveFileUniqueCount'], 6);
    expect(constructedEvent.eventData['transitiveFileUniqueLineCount'], 7);
    expect(constructedEvent.eventData['libraryCycleLibraryCounts'], 'a');
    expect(constructedEvent.eventData['libraryCycleLineCounts'], 'b');
    expect(constructedEvent.eventData['contextWorkspaceType'], '[0,1,2]');
    expect(constructedEvent.eventData['numberOfPackagesInWorkspace'], '32');
    expect(
      constructedEvent.eventData['minSdkConstraints'],
      '{"2.12.0":5,"3.0.0":2}',
    );
    expect(
      constructedEvent.eventData['languageVersionOverrides'],
      '{"2.12":5,"3.10":2}',
    );
    expect(constructedEvent.eventData.length, 13);
  });

  test('Event.dartCliCommandExecuted constructed', () {
    Event generateEvent() => Event.dartCliCommandExecuted(
      name: 'name',
      enabledExperiments: 'enabledExperiments',
      exitCode: 0,
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.dartCliCommandExecuted);
    expect(constructedEvent.eventData['name'], 'name');
    expect(
      constructedEvent.eventData['enabledExperiments'],
      'enabledExperiments',
    );
    expect(constructedEvent.eventData['exitCode'], 0);
    expect(constructedEvent.eventData.length, 3);
  });

  test('Event.dartCliCommandExecuted constructed with Set of dependencies', () {
    final deps = {'path', 'meta', 'collection'};
    Event generateEvent() => Event.dartCliCommandExecuted(
      name: 'name',
      enabledExperiments: 'enabledExperiments',
      exitCode: 0,
      pubspecHasFlutterSdk: true,
      pubspecDependencies: deps,
      pubspecEnvironmentSdk: '^3.0.0',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.dartCliCommandExecuted);
    expect(constructedEvent.eventData['name'], 'name');
    expect(
      constructedEvent.eventData['enabledExperiments'],
      'enabledExperiments',
    );
    expect(constructedEvent.eventData['exitCode'], 0);
    expect(constructedEvent.eventData['pubspec_has_flutter_sdk'], true);
    expect(constructedEvent.eventData['pubspec_environment_sdk'], '^3.0.0');

    // Delegates chunking to chunkDependencies
    final expectedChunks = chunkDependencies(deps);
    expect(
      constructedEvent.eventData['pubspec_dep_0'],
      expectedChunks['pubspec_dep_0'],
    );
    expect(constructedEvent.eventData.length, 6);
  });

  test('Event.dartCliCommandExecuted delegates to chunkDependencies', () {
    final deps = <String>{};
    for (var i = 1; i <= 50; i++) {
      deps.add('dep_$i');
    }

    final event = Event.dartCliCommandExecuted(
      name: 'name',
      enabledExperiments: 'enabledExperiments',
      pubspecDependencies: deps,
    );

    final expected = chunkDependencies(deps);
    for (final entry in expected.entries) {
      expect(event.eventData[entry.key], entry.value);
    }
  });

  test('Event.dartCliCommandExecuted constructed with target package', () {
    Event generateEvent() => Event.dartCliCommandExecuted(
      name: 'install',
      enabledExperiments: 'enabledExperiments',
      exitCode: 0,
      targetPackage: 'dhttpd',
      targetPackageVersion: '4.1.0',
      targetPackageConstraint: '^4.0.0',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.dartCliCommandExecuted);
    expect(constructedEvent.eventData['name'], 'install');
    expect(constructedEvent.eventData['exitCode'], 0);
    expect(constructedEvent.eventData['target_package'], 'dhttpd');
    expect(constructedEvent.eventData['target_package_version'], '4.1.0');
    expect(constructedEvent.eventData['target_package_constraint'], '^4.0.0');
    expect(constructedEvent.eventData.length, 6);
  });

  test('Event.dartCliCommandExecuted omits null target package fields', () {
    final event = Event.dartCliCommandExecuted(
      name: 'run',
      enabledExperiments: 'enabledExperiments',
      targetPackage: 'dhttpd',
      targetPackageVersion: '4.1.0',
    );

    expect(event.eventData['target_package'], 'dhttpd');
    expect(event.eventData['target_package_version'], '4.1.0');
    expect(event.eventData.containsKey('target_package_constraint'), isFalse);
    expect(event.eventData.length, 4);
  });

  test('Event.dartCliCommandExecuted omits target package values over the '
      'GA4 length limit', () {
    final tooLong = 'a' * 101;
    final deps = {for (var i = 0; i < 500; i++) 'dependency_number_$i'};

    final event = Event.dartCliCommandExecuted(
      name: 'run',
      enabledExperiments: 'enabledExperiments',
      exitCode: 0,
      pubspecHasFlutterSdk: false,
      pubspecEnvironmentSdk: '^3.0.0',
      pubspecDependencies: deps,
      targetPackage: 'dhttpd',
      targetPackageVersion: 'a' * 100,
      targetPackageConstraint: tooLong,
    );

    expect(event.eventData['target_package'], 'dhttpd');
    expect(event.eventData['target_package_version'], 'a' * 100);
    expect(event.eventData.containsKey('target_package_constraint'), isFalse);
    // The omitted value does not take a slot from the dependency chunks.
    expect(
      event.eventData.keys.where((key) => key.startsWith('pubspec_dep_')),
      hasLength(18),
    );
    expect(event.eventData.length, 25);
  });

  test('Event.dartCliCommandExecuted omits target package version and '
      'constraint without a target package', () {
    final deps = {for (var i = 0; i < 500; i++) 'dependency_number_$i'};

    Event generateEvent({String? targetPackage}) =>
        Event.dartCliCommandExecuted(
          name: 'run',
          enabledExperiments: 'enabledExperiments',
          pubspecDependencies: deps,
          targetPackage: targetPackage,
          targetPackageVersion: '4.1.0',
          targetPackageConstraint: '^4.0.0',
        );

    // Both a missing name and one over the GA4 length limit drop all three.
    for (final event in [
      generateEvent(),
      generateEvent(targetPackage: 'a' * 101),
    ]) {
      expect(
        event.eventData.keys.where((key) => key.startsWith('target_package')),
        isEmpty,
      );
      // Nothing is taken from the dependency chunks.
      expect(
        event.eventData.keys.where((key) => key.startsWith('pubspec_dep_')),
        hasLength(20),
      );
    }
  });

  test('Event.dartCliCommandExecuted stays within the GA4 parameter limit '
      'with target package and dependencies', () {
    final deps = {for (var i = 0; i < 500; i++) 'dependency_number_$i'};

    Event generateEvent({
      String? targetPackage,
      String? targetPackageVersion,
      String? targetPackageConstraint,
    }) => Event.dartCliCommandExecuted(
      name: 'run',
      enabledExperiments: 'enabledExperiments',
      exitCode: 0,
      pubspecHasFlutterSdk: false,
      pubspecEnvironmentSdk: '^3.0.0',
      pubspecDependencies: deps,
      targetPackage: targetPackage,
      targetPackageVersion: targetPackageVersion,
      targetPackageConstraint: targetPackageConstraint,
    );

    int chunkCount(Event event) => event.eventData.keys
        .where((key) => key.startsWith('pubspec_dep_'))
        .length;

    final withoutTarget = generateEvent();
    expect(withoutTarget.eventData.length, 25);
    expect(chunkCount(withoutTarget), 20);

    // Unused standard parameters do not add dependency chunks beyond
    // `pubspec_dep_19`.
    final minimal = Event.dartCliCommandExecuted(
      name: 'run',
      enabledExperiments: 'enabledExperiments',
      pubspecDependencies: deps,
    );
    expect(minimal.eventData.length, 22);
    expect(chunkCount(minimal), 20);

    final withPartialTarget = generateEvent(
      targetPackage: 'dhttpd',
      targetPackageVersion: '4.1.0',
    );
    expect(withPartialTarget.eventData.length, 25);
    expect(chunkCount(withPartialTarget), 18);

    final withTarget = generateEvent(
      targetPackage: 'dhttpd',
      targetPackageVersion: '4.1.0',
      targetPackageConstraint: '^4.0.0',
    );
    expect(withTarget.eventData.length, 25);
    expect(chunkCount(withTarget), 17);
    expect(withTarget.eventData['target_package'], 'dhttpd');
    expect(withTarget.eventData['target_package_version'], '4.1.0');
    expect(withTarget.eventData['target_package_constraint'], '^4.0.0');
  });

  group('chunkDependencies', () {
    test('empty set returns empty map', () {
      expect(chunkDependencies({}), isEmpty);
    });

    test('respects maxChunks', () {
      final deps = {for (var i = 0; i < 500; i++) 'dependency_number_$i'};

      final full = chunkDependencies(deps);
      expect(full, hasLength(20));

      final limited = chunkDependencies(deps, maxChunks: 3);
      expect(limited.keys, ['pubspec_dep_0', 'pubspec_dep_1', 'pubspec_dep_2']);
      // Lowering the limit truncates; it does not reshuffle.
      for (final entry in limited.entries) {
        expect(full[entry.key], entry.value);
      }

      expect(chunkDependencies(deps, maxChunks: 0), isEmpty);
    });

    test('sorts deterministically using salted FNV-1a hash values', () {
      final deps = {'path', 'meta', 'collection', 'args', 'yaml', 'http'};

      // Verification of determinism across multiple calls
      final result1 = chunkDependencies(deps);
      final result2 = chunkDependencies(deps);
      expect(result1, result2);

      // Verify that it is NOT sorted alphabetically.
      // Alphabetical order would be: args, collection, http, meta, path, yaml
      final alphabeticalList = deps.toList()..sort();
      final reportedList = result1['pubspec_dep_0']!.split(',');
      expect(reportedList, isNot(alphabeticalList));
    });

    test(
      'salts ordering by dependency set to eliminate ecosystem-wide starvation',
      () {
        final depsA = {
          'path',
          'meta',
          'collection',
          'args',
          'yaml',
          'http',
          'shelf',
        };
        final depsB = {
          'path',
          'meta',
          'collection',
          'args',
          'yaml',
          'http',
          'async',
        };

        final resultA = chunkDependencies(depsA);
        final resultB = chunkDependencies(depsB);

        // Both results are deterministic across repeated runs
        expect(resultA, chunkDependencies(depsA));
        expect(resultB, chunkDependencies(depsB));

        // The common packages ('path', 'meta', 'collection', etc.) should have
        // different relative orderings between project A and project B because
        // each project computes a unique dependency-set salt.
        final commonInA = resultA['pubspec_dep_0']!
            .split(',')
            .where((p) => p != 'shelf')
            .toList();
        final commonInB = resultB['pubspec_dep_0']!
            .split(',')
            .where((p) => p != 'async')
            .toList();
        expect(commonInA, isNot(commonInB));
      },
    );

    test('chunks correctly based on 100-character limit', () {
      // 10 dependencies, each 16 characters.
      // Delimited by ',' means 17 characters per dep (except last).
      final deps = <String>{};
      for (var i = 1; i <= 10; i++) {
        deps.add('dep_${i.toString().padLeft(2, '0')}_123456789');
      }

      final result = chunkDependencies(deps);

      // Since each dep is 16 chars, 6 deps would be 6 * 16 + 5 = 101 chars,
      // which is > 100. So max 5 deps fit in a single chunk
      // (5 * 16 + 4 = 84 chars). Therefore, it must be split across
      // exactly 2 chunks.
      expect(result.containsKey('pubspec_dep_0'), isTrue);
      expect(result.containsKey('pubspec_dep_1'), isTrue);
      expect(result.containsKey('pubspec_dep_2'), isFalse);

      expect(result['pubspec_dep_0']!.length, lessThanOrEqualTo(100));
      expect(result['pubspec_dep_1']!.length, lessThanOrEqualTo(100));

      final allReported = <String>{
        ...result['pubspec_dep_0']!.split(','),
        ...result['pubspec_dep_1']!.split(','),
      };
      expect(allReported, deps);
    });

    test('caps at 20 chunks', () {
      // Generate 150 dependencies, each 15 characters.
      // This would require ~24 chunks, but must be capped at 20.
      final deps = <String>{};
      for (var i = 1; i <= 150; i++) {
        deps.add('dep_${i.toString().padLeft(3, '0')}_12345678');
      }

      final result = chunkDependencies(deps);

      expect(result.containsKey('pubspec_dep_0'), isTrue);
      expect(result.containsKey('pubspec_dep_19'), isTrue);
      expect(result.containsKey('pubspec_dep_20'), isFalse);
      expect(result.length, 20);
    });

    test('guards against and skips package names > 100 characters', () {
      final longName = 'a' * 101;
      final result = chunkDependencies({longName, 'path'});

      expect(result['pubspec_dep_0'], 'path');
      expect(result.length, 1);
    });
  });

  test('Event.diagnosticReportedCount constructed', () {
    final expectedCode = 'some_diagnostic_code';
    final expectedCount = 27;
    Event generateEvent() =>
        Event.diagnosticReportedCount(code: expectedCode, count: expectedCount);

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.diagnosticReportedCount);
    expect(constructedEvent.eventData['code'], expectedCode);
    expect(constructedEvent.eventData['count'], expectedCount);
  });

  test('Event.doctorValidatorResult constructed', () {
    Event generateEvent() => Event.doctorValidatorResult(
      validatorName: 'validatorName',
      result: 'success',
      partOfGroupedValidator: false,
      doctorInvocationId: 123,
      statusInfo: 'statusInfo',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.doctorValidatorResult);
    expect(constructedEvent.eventData['validatorName'], 'validatorName');
    expect(constructedEvent.eventData['result'], 'success');
    expect(constructedEvent.eventData['partOfGroupedValidator'], false);
    expect(constructedEvent.eventData['doctorInvocationId'], 123);
    expect(constructedEvent.eventData['statusInfo'], 'statusInfo');
    expect(constructedEvent.eventData.length, 5);
  });

  test('Event.hotReloadTime constructed', () {
    Event generateEvent() => Event.hotReloadTime(timeMs: 500);

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.hotReloadTime);
    expect(constructedEvent.eventData['timeMs'], 500);
    expect(constructedEvent.eventData.length, 1);
  });

  test('Event.lintUsageCount constructed', () {
    Event generateEvent() => Event.lintUsageCount(count: 5, name: 'name');

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.lintUsageCount);
    expect(constructedEvent.eventData['count'], 5);
    expect(constructedEvent.eventData['name'], 'name');
    expect(constructedEvent.eventData.length, 2);
  });

  test('Event.memoryInfo constructed', () {
    Event generateEvent() =>
        Event.memoryInfo(rss: 4, periodSec: 5, mbPerSec: 5.55);

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.memoryInfo);
    expect(constructedEvent.eventData['rss'], 4);
    expect(constructedEvent.eventData['periodSec'], 5);
    expect(constructedEvent.eventData['mbPerSec'], 5.55);
    expect(constructedEvent.eventData.length, 3);
  });

  test('Event.migrateRound constructed', () {
    Event generateEvent() => Event.migrateRound(
      fromSdkVersion: '3.12',
      packagesAtStart: 3,
      packagesAtEnd: 1,
      failures: '{"b2":1,"h1":1}',
      prepareDurationMs: 10,
      bumpDurationMs: 20,
      cleanupDurationMs: 30,
      totalDurationMs: 70,
      migrateSessionId: 1761501474000,
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.migrateRound);
    expect(
      constructedEvent.eventData,
      equals({
        'fromSdkVersion': '3.12',
        'packagesAtStart': 3,
        'packagesAtEnd': 1,
        'failures': '{"b2":1,"h1":1}',
        'prepareDurationMs': 10,
        'bumpDurationMs': 20,
        'cleanupDurationMs': 30,
        'totalDurationMs': 70,
        'migrateSessionId': 1761501474000,
      }),
    );
  });

  test('Event.migrateRound constructed without optional fields', () {
    final constructedEvent = Event.migrateRound(
      fromSdkVersion: '3.12',
      packagesAtStart: 1,
      packagesAtEnd: 1,
      totalDurationMs: 5,
      migrateSessionId: 1761501474000,
    );

    expect(
      constructedEvent.eventData,
      equals({
        'fromSdkVersion': '3.12',
        'packagesAtStart': 1,
        'packagesAtEnd': 1,
        'totalDurationMs': 5,
        'migrateSessionId': 1761501474000,
      }),
    );
  });

  test('Event.migrateRun constructed', () {
    Event generateEvent() => Event.migrateRun(
      fromSdkVersion: '3.11',
      toSdkVersion: '3.13',
      targetSdk: true,
      prepare: true,
      bump: true,
      cleanup: false,
      apply: false,
      durationMs: 5321,
      cleanupCheckDurationMs: 2100,
      migrateSessionId: 1761501474000,
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.migrateRun);
    expect(
      constructedEvent.eventData,
      equals({
        'fromSdkVersion': '3.11',
        'toSdkVersion': '3.13',
        'targetSdk': true,
        'prepare': true,
        'bump': true,
        'cleanup': false,
        'apply': false,
        'durationMs': 5321,
        'cleanupCheckDurationMs': 2100,
        'migrateSessionId': 1761501474000,
      }),
    );
  });

  test('Event.migrateRun constructed without optional fields', () {
    final constructedEvent = Event.migrateRun(
      targetSdk: false,
      prepare: true,
      bump: true,
      cleanup: false,
      apply: false,
      durationMs: 1,
      migrateSessionId: 1761501474000,
    );

    expect(
      constructedEvent.eventData,
      equals({
        'targetSdk': false,
        'prepare': true,
        'bump': true,
        'cleanup': false,
        'apply': false,
        'durationMs': 1,
        'migrateSessionId': 1761501474000,
      }),
    );
  });

  test('Event.pluginRequest constructed', () {
    Event generateEvent() => Event.pluginRequest(
      duration: 'duration',
      method: 'method',
      pluginId: 'pluginId',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.pluginRequest);
    expect(constructedEvent.eventData['duration'], 'duration');
    expect(constructedEvent.eventData['method'], 'method');
    expect(constructedEvent.eventData['pluginId'], 'pluginId');
    expect(constructedEvent.eventData.length, 3);
  });

  test('Event.plugins constructed', () {
    Event generateEvent() => Event.plugins(
      count: 5,
      lintRuleCounts: 'lintRuleCounts',
      warningRuleCounts: 'warningRuleCounts',
      fixCounts: 'fixCounts',
      assistCounts: 'assistCounts',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.plugins);
    expect(constructedEvent.eventData['count'], 5);
    expect(constructedEvent.eventData['lintRuleCounts'], 'lintRuleCounts');
    expect(
      constructedEvent.eventData['warningRuleCounts'],
      'warningRuleCounts',
    );
    expect(constructedEvent.eventData['fixCounts'], 'fixCounts');
    expect(constructedEvent.eventData['assistCounts'], 'assistCounts');
    expect(constructedEvent.eventData, hasLength(5));
  });

  test('Event.pluginUse constructed', () {
    Event generateEvent() =>
        Event.pluginUse(count: 5, enabled: 'enabled', pluginId: 'pluginId');

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.pluginUse);
    expect(constructedEvent.eventData['count'], 5);
    expect(constructedEvent.eventData['enabled'], 'enabled');
    expect(constructedEvent.eventData['pluginId'], 'pluginId');
    expect(constructedEvent.eventData.length, 3);
  });

  test('Event.pubGet constructed', () {
    Event generateEvent() => Event.pubGet(
      packageName: 'packageName',
      version: 'version',
      dependencyType: 'dependencyType',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.pubGet);
    expect(constructedEvent.eventData['packageName'], 'packageName');
    expect(constructedEvent.eventData['version'], 'version');
    expect(constructedEvent.eventData['dependencyType'], 'dependencyType');
    expect(constructedEvent.eventData.length, 3);
  });

  test('Event.serverSession constructed', () {
    Event generateEvent() => Event.serverSession(
      clientId: 'clientId',
      clientVersion: 'clientVersion',
      duration: 5,
      flags: 'flags',
      parameters: 'parameters',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.serverSession);
    expect(constructedEvent.eventData['clientId'], 'clientId');
    expect(constructedEvent.eventData['clientVersion'], 'clientVersion');
    expect(constructedEvent.eventData['duration'], 5);
    expect(constructedEvent.eventData['flags'], 'flags');
    expect(constructedEvent.eventData['parameters'], 'parameters');
    expect(constructedEvent.eventData['ideName'], '');
    expect(constructedEvent.eventData['ideVersion'], '');
    expect(constructedEvent.eventData['pluginName'], '');
    expect(constructedEvent.eventData['pluginVersion'], '');
    expect(constructedEvent.eventData.length, 9);
  });

  test('Event.serverSession constructed with optional parameters', () {
    Event generateEvent() => Event.serverSession(
      clientId: 'clientId',
      clientVersion: 'clientVersion',
      duration: 5,
      flags: 'flags',
      parameters: 'parameters',
      ideName: 'ideName',
      ideVersion: 'ideVersion',
      pluginName: 'pluginName',
      pluginVersion: 'pluginVersion',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.serverSession);
    expect(constructedEvent.eventData['clientId'], 'clientId');
    expect(constructedEvent.eventData['clientVersion'], 'clientVersion');
    expect(constructedEvent.eventData['duration'], 5);
    expect(constructedEvent.eventData['flags'], 'flags');
    expect(constructedEvent.eventData['parameters'], 'parameters');
    expect(constructedEvent.eventData['ideName'], 'ideName');
    expect(constructedEvent.eventData['ideVersion'], 'ideVersion');
    expect(constructedEvent.eventData['pluginName'], 'pluginName');
    expect(constructedEvent.eventData['pluginVersion'], 'pluginVersion');
    expect(constructedEvent.eventData.length, 9);
  });

  test('Event.severityAdjustment constructed', () {
    Event generateEvent() => Event.severityAdjustment(
      diagnostic: 'diagnostic',
      adjustments: 'adjustments',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.severityAdjustment);
    expect(constructedEvent.eventData['diagnostic'], 'diagnostic');
    expect(constructedEvent.eventData['adjustments'], 'adjustments');
    expect(constructedEvent.eventData.length, 2);
  });

  test('Event.surveyAction constructed', () {
    Event generateEvent() =>
        Event.surveyAction(surveyId: 'surveyId', status: 'status');

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.surveyAction);
    expect(constructedEvent.eventData['surveyId'], 'surveyId');
    expect(constructedEvent.eventData['status'], 'status');
    expect(constructedEvent.eventData.length, 2);
  });

  test('Event.surveyShown constructed', () {
    Event generateEvent() => Event.surveyShown(surveyId: 'surveyId');

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.surveyShown);
    expect(constructedEvent.eventData['surveyId'], 'surveyId');
    expect(constructedEvent.eventData.length, 1);
  });

  test('Event.flutterBuildInfo constructed', () {
    Event generateEvent() => Event.flutterBuildInfo(
      label: 'label',
      buildType: 'buildType',
      command: 'command',
      settings: 'settings',
      error: 'error',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.flutterBuildInfo);
    expect(constructedEvent.eventData['label'], 'label');
    expect(constructedEvent.eventData['buildType'], 'buildType');
    expect(constructedEvent.eventData['command'], 'command');
    expect(constructedEvent.eventData['settings'], 'settings');
    expect(constructedEvent.eventData['error'], 'error');
    expect(constructedEvent.eventData.length, 5);
  });

  test('Event.hotRunnerInfo constructed', () {
    Event generateEvent() => Event.hotRunnerInfo(
      label: 'label',
      targetPlatform: 'targetPlatform',
      sdkName: 'sdkName',
      emulator: false,
      fullRestart: true,
      reason: 'reason',
      finalLibraryCount: 5,
      syncedLibraryCount: 6,
      syncedClassesCount: 7,
      syncedProceduresCount: 8,
      syncedBytes: 9,
      invalidatedSourcesCount: 10,
      transferTimeInMs: 11,
      overallTimeInMs: 12,
      compileTimeInMs: 13,
      findInvalidatedTimeInMs: 14,
      scannedSourcesCount: 15,
      reassembleTimeInMs: 16,
      reloadVMTimeInMs: 17,
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.hotRunnerInfo);
    expect(constructedEvent.eventData['label'], 'label');
    expect(constructedEvent.eventData['targetPlatform'], 'targetPlatform');
    expect(constructedEvent.eventData['sdkName'], 'sdkName');
    expect(constructedEvent.eventData['emulator'], false);
    expect(constructedEvent.eventData['fullRestart'], true);
    expect(constructedEvent.eventData['reason'], 'reason');
    expect(constructedEvent.eventData['finalLibraryCount'], 5);
    expect(constructedEvent.eventData['syncedLibraryCount'], 6);
    expect(constructedEvent.eventData['syncedClassesCount'], 7);
    expect(constructedEvent.eventData['syncedProceduresCount'], 8);
    expect(constructedEvent.eventData['syncedBytes'], 9);
    expect(constructedEvent.eventData['invalidatedSourcesCount'], 10);
    expect(constructedEvent.eventData['transferTimeInMs'], 11);
    expect(constructedEvent.eventData['overallTimeInMs'], 12);
    expect(constructedEvent.eventData['compileTimeInMs'], 13);
    expect(constructedEvent.eventData['findInvalidatedTimeInMs'], 14);
    expect(constructedEvent.eventData['scannedSourcesCount'], 15);
    expect(constructedEvent.eventData['reassembleTimeInMs'], 16);
    expect(constructedEvent.eventData['reloadVMTimeInMs'], 17);
    expect(constructedEvent.eventData.length, 19);
  });

  test('Event.flutterCommandResult constructed', () {
    Event generateEvent() => Event.flutterCommandResult(
      commandPath: 'commandPath',
      result: 'result',
      commandHasTerminal: true,
      hostArch: 'arm64',
      maxRss: 123,
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.flutterCommandResult);
    expect(constructedEvent.eventData['commandPath'], 'commandPath');
    expect(constructedEvent.eventData['result'], 'result');
    expect(constructedEvent.eventData['commandHasTerminal'], true);
    expect(constructedEvent.eventData['hostArch'], 'arm64');
    expect(constructedEvent.eventData['maxRss'], 123);
    expect(constructedEvent.eventData.length, 5);
  });

  test(
    'Event.flutterCommandResult constructed with optional values omitted',
    () {
      Event generateEvent() => Event.flutterCommandResult(
        commandPath: 'commandPath',
        result: 'result',
        commandHasTerminal: true,
      );

      final constructedEvent = generateEvent();

      expect(generateEvent, returnsNormally);
      expect(constructedEvent.eventName, DashEvent.flutterCommandResult);
      expect(constructedEvent.eventData['commandPath'], 'commandPath');
      expect(constructedEvent.eventData['result'], 'result');
      expect(constructedEvent.eventData['commandHasTerminal'], true);
      expect(constructedEvent.eventData['hostArch'], isNull);
      expect(constructedEvent.eventData['maxRss'], isNull);
      expect(constructedEvent.eventData.length, 3);
    },
  );

  test('Event.flutterWasmDryRunPackage constructed', () {
    Event generateEvent() => Event.flutterWasmDryRunPackage(
      result: 'success',
      exitCode: 123,
      findingsInfo: {
        '0': '-ph,pkg1:1.2.3,pkg2:5.4.3',
        '1': '-p,pkg3:9.2.44,pkg4:6.4.3',
      },
    );

    final constructedEvent1 = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent1.eventName, DashEvent.flutterWasmDryRunPackage);
    expect(constructedEvent1.eventData['result'], 'success');
    expect(constructedEvent1.eventData['exitCode'], 123);
    expect(constructedEvent1.eventData['0'], '-ph,pkg1:1.2.3,pkg2:5.4.3');
    expect(constructedEvent1.eventData['1'], '-p,pkg3:9.2.44,pkg4:6.4.3');
    expect(constructedEvent1.eventData.length, 4);
  });

  test('Event.flutterInjectDarwinPlugins constructed', () {
    Event generateEvent() => Event.flutterInjectDarwinPlugins(
      platform: 'ios',
      isModule: true,
      swiftPackageManagerUsable: true,
      swiftPackageManagerFeatureEnabled: true,
      projectDisabledSwiftPackageManager: false,
      projectHasSwiftPackageManagerIntegration: true,
      pluginCount: 123,
      swiftPackageCount: 456,
      podCount: 678,
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.flutterInjectDarwinPlugins);
    expect(constructedEvent.eventData['platform'], 'ios');
    expect(constructedEvent.eventData['isModule'], isTrue);
    expect(constructedEvent.eventData['swiftPackageManagerUsable'], isTrue);
    expect(
      constructedEvent.eventData['swiftPackageManagerFeatureEnabled'],
      isTrue,
    );
    expect(
      constructedEvent.eventData['projectDisabledSwiftPackageManager'],
      isFalse,
    );
    expect(
      constructedEvent.eventData['projectHasSwiftPackageManagerIntegration'],
      isTrue,
    );
    expect(constructedEvent.eventData['pluginCount'], 123);
    expect(constructedEvent.eventData['swiftPackageCount'], 456);
    expect(constructedEvent.eventData['podCount'], 678);
    expect(constructedEvent.eventData.length, 9);
  });

  group('Event.flutterTrackAndroidDependencies', () {
    test('constructed', () {
      Event generateEvent() => Event.flutterTrackAndroidDependencies(
        success: true,
        isModule: true,
        agpVersion: '8.2.2',
        minSDK: 24,
        targetSDK: 36,
        compileSDK: 36,
        jdkVersion: 24,
        ndkVersion: '28.0.13004108',
        gradleVersion: '8.10.2',
      );

      final constructedEvent = generateEvent();

      expect(generateEvent, returnsNormally);
      expect(
        constructedEvent.eventName,
        DashEvent.flutterTrackAndroidDependencies,
      );
      expect(constructedEvent.eventData['success'], isTrue);
      expect(constructedEvent.eventData['label'], isNull);
      expect(constructedEvent.eventData['isModule'], isTrue);
      expect(constructedEvent.eventData['agpVersion'], '8.2.2');
      expect(constructedEvent.eventData['minSDK'], 24);
      expect(constructedEvent.eventData['targetSDK'], 36);
      expect(constructedEvent.eventData['compileSDK'], 36);
      expect(constructedEvent.eventData['jdkVersion'], 24);
      expect(constructedEvent.eventData['ndkVersion'], '28.0.13004108');
      expect(constructedEvent.eventData['gradleVersion'], '8.10.2');
      expect(constructedEvent.eventData.length, 9);
    });

    test('constructor arguments default to null if not specified', () {
      Event generateEvent() => Event.flutterTrackAndroidDependencies(
        success: false,
        label: 'failed to download gradle from ...',
        isModule: true,
        agpVersion: '8.2.2',
        targetSDK: 36,
        jdkVersion: 24,
        gradleVersion: '8.10.2',
      );

      final constructedEvent = generateEvent();

      expect(generateEvent, returnsNormally);
      expect(
        constructedEvent.eventName,
        DashEvent.flutterTrackAndroidDependencies,
      );
      expect(constructedEvent.eventData['success'], isFalse);
      expect(
        constructedEvent.eventData['label'],
        'failed to download gradle from ...',
      );
      expect(constructedEvent.eventData['isModule'], isTrue);
      expect(constructedEvent.eventData['agpVersion'], '8.2.2');
      expect(constructedEvent.eventData['minSDK'], null);
      expect(constructedEvent.eventData['targetSDK'], 36);
      expect(constructedEvent.eventData['compileSDK'], null);
      expect(constructedEvent.eventData['jdkVersion'], 24);
      expect(constructedEvent.eventData['ndkVersion'], null);
      expect(constructedEvent.eventData['gradleVersion'], '8.10.2');
      expect(constructedEvent.eventData.length, 7);
    });
  });
  test('Event.codeSizeAnalysis constructed', () {
    Event generateEvent() => Event.codeSizeAnalysis(platform: 'platform');

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.codeSizeAnalysis);
    expect(constructedEvent.eventData['platform'], 'platform');
    expect(constructedEvent.eventData.length, 1);
  });

  test('Event.appleUsageEvent constructed', () {
    Event generateEvent() => Event.appleUsageEvent(
      workflow: 'workflow',
      parameter: 'parameter',
      result: 'result',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.appleUsageEvent);
    expect(constructedEvent.eventData['workflow'], 'workflow');
    expect(constructedEvent.eventData['parameter'], 'parameter');
    expect(constructedEvent.eventData['result'], 'result');
    expect(constructedEvent.eventData.length, 3);
  });

  test('Event.exception constructed', () {
    Event generateEvent() => Event.exception(
      exception: 'exception',
      data: {'foo': 'bar', 'baz': 1, 'shouldBeRemoved': null},
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.exception);
    expect(constructedEvent.eventData['exception'], 'exception');
    expect(constructedEvent.eventData['foo'], 'bar');
    expect(constructedEvent.eventData['baz'], 1);
    expect(constructedEvent.eventData.length, 3);
  });

  test('Event.exception constructor works when no data is provided', () {
    Event generateEvent() => Event.exception(exception: 'exception');

    expect(generateEvent, returnsNormally);
  });

  test('Event.timing constructed', () {
    Event generateEvent() => Event.timing(
      workflow: 'workflow',
      variableName: 'variableName',
      elapsedMilliseconds: 123,
      label: 'label',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.timing);
    expect(constructedEvent.eventData['workflow'], 'workflow');
    expect(constructedEvent.eventData['variableName'], 'variableName');
    expect(constructedEvent.eventData['elapsedMilliseconds'], 123);
    expect(constructedEvent.eventData['label'], 'label');
    expect(constructedEvent.eventData.length, 4);
  });

  test('Event.commandUsageValues constructed', () {
    Event generateEvent() => Event.commandUsageValues(
      workflow: 'workflow',
      commandHasTerminal: true,
      buildBundleTargetPlatform: 'buildBundleTargetPlatform',
      buildBundleIsModule: true,
      buildBundleEnableHcpp: true,
      buildAarProjectType: 'buildAarProjectType',
      buildAarTargetPlatform: 'buildAarTargetPlatform',
      buildAarEnableHcpp: true,
      buildApkTargetPlatform: 'buildApkTargetPlatform',
      buildApkBuildMode: 'buildApkBuildMode',
      buildApkSplitPerAbi: true,
      buildApkEnableHcpp: true,
      buildAppBundleTargetPlatform: 'buildAppBundleTargetPlatform',
      buildAppBundleBuildMode: 'buildAppBundleBuildMode',
      createProjectType: 'createProjectType',
      createAndroidLanguage: 'createAndroidLanguage',
      createIosLanguage: 'createIosLanguage',
      packagesNumberPlugins: 123,
      packagesProjectModule: true,
      packagesAndroidEmbeddingVersion: 'packagesAndroidEmbeddingVersion',
      runIsEmulator: true,
      runTargetName: 'runTargetName',
      runTargetOsVersion: 'runTargetOsVersion',
      runModeName: 'runModeName',
      runProjectModule: true,
      runProjectHostLanguage: 'runProjectHostLanguage',
      runAndroidEmbeddingVersion: 'runAndroidEmbeddingVersion',
      runEnableImpeller: true,
      runIOSInterfaceType: 'runIOSInterfaceType',
      runIsTest: true,
      runEnableHcpp: true,
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.commandUsageValues);
    expect(constructedEvent.eventData['workflow'], 'workflow');
    expect(
      constructedEvent.eventData['buildBundleTargetPlatform'],
      'buildBundleTargetPlatform',
    );
    expect(constructedEvent.eventData['buildBundleEnableHcpp'], true);
    expect(constructedEvent.eventData['buildBundleIsModule'], true);
    expect(
      constructedEvent.eventData['buildAarProjectType'],
      'buildAarProjectType',
    );
    expect(
      constructedEvent.eventData['buildAarTargetPlatform'],
      'buildAarTargetPlatform',
    );
    expect(constructedEvent.eventData['buildAarEnableHcpp'], true);
    expect(
      constructedEvent.eventData['buildApkTargetPlatform'],
      'buildApkTargetPlatform',
    );
    expect(
      constructedEvent.eventData['buildApkBuildMode'],
      'buildApkBuildMode',
    );
    expect(constructedEvent.eventData['buildApkSplitPerAbi'], true);
    expect(constructedEvent.eventData['buildApkEnableHcpp'], true);
    expect(
      constructedEvent.eventData['buildAppBundleTargetPlatform'],
      'buildAppBundleTargetPlatform',
    );
    expect(
      constructedEvent.eventData['buildAppBundleBuildMode'],
      'buildAppBundleBuildMode',
    );
    expect(
      constructedEvent.eventData['createProjectType'],
      'createProjectType',
    );
    expect(
      constructedEvent.eventData['createAndroidLanguage'],
      'createAndroidLanguage',
    );
    expect(
      constructedEvent.eventData['createIosLanguage'],
      'createIosLanguage',
    );
    expect(constructedEvent.eventData['packagesNumberPlugins'], 123);
    expect(constructedEvent.eventData['packagesProjectModule'], true);
    expect(
      constructedEvent.eventData['packagesAndroidEmbeddingVersion'],
      'packagesAndroidEmbeddingVersion',
    );
    expect(constructedEvent.eventData['runIsEmulator'], true);
    expect(constructedEvent.eventData['runTargetName'], 'runTargetName');
    expect(
      constructedEvent.eventData['runTargetOsVersion'],
      'runTargetOsVersion',
    );
    expect(constructedEvent.eventData['runModeName'], 'runModeName');
    expect(constructedEvent.eventData['runProjectModule'], true);
    expect(
      constructedEvent.eventData['runProjectHostLanguage'],
      'runProjectHostLanguage',
    );
    expect(
      constructedEvent.eventData['runAndroidEmbeddingVersion'],
      'runAndroidEmbeddingVersion',
    );
    expect(constructedEvent.eventData['runEnableImpeller'], true);
    expect(
      constructedEvent.eventData['runIOSInterfaceType'],
      'runIOSInterfaceType',
    );
    expect(constructedEvent.eventData['runEnableHcpp'], true);
    expect(constructedEvent.eventData.length, 31);
  });

  test('Event.analyticsException constructed', () {
    Event generateEvent() => Event.analyticsException(
      workflow: 'workflow',
      error: 'error',
      description: 'description',
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.analyticsException);
    expect(constructedEvent.eventData['workflow'], 'workflow');
    expect(constructedEvent.eventData['error'], 'error');
    expect(constructedEvent.eventData['description'], 'description');
    expect(constructedEvent.eventData.length, 3);
  });

  test('Event.devtoolsEvent constructed', () {
    Event generateEvent() => Event.devtoolsEvent(
      screen: 'screen',
      eventCategory: 'eventCategory',
      label: 'label',
      value: 1,
      userInitiatedInteraction: true,
      g3Username: 'g3Username',
      userApp: 'userApp',
      userBuild: 'userBuild',
      userPlatform: 'userPlatform',
      devtoolsPlatform: 'devtoolsPlatform',
      devtoolsChrome: 'devtoolsChrome',
      devtoolsVersion: 'devtoolsVersion',
      ideLaunched: 'ideLaunched',
      isExternalBuild: 'isExternalBuild',
      isEmbedded: 'isEmbedded',
      ideLaunchedFeature: 'ideLaunchedFeature',
      isWasm: 'true',
      additionalMetrics: _TestMetrics(
        stringField: 'test',
        intField: 100,
        boolField: false,
      ),
    );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventData['screen'], 'screen');
    expect(constructedEvent.eventData['eventCategory'], 'eventCategory');
    expect(constructedEvent.eventData['label'], 'label');
    expect(constructedEvent.eventData['value'], 1);
    expect(constructedEvent.eventData['userInitiatedInteraction'], true);
    expect(constructedEvent.eventData['g3Username'], 'g3Username');
    expect(constructedEvent.eventData['userApp'], 'userApp');
    expect(constructedEvent.eventData['userBuild'], 'userBuild');
    expect(constructedEvent.eventData['userPlatform'], 'userPlatform');
    expect(constructedEvent.eventData['devtoolsPlatform'], 'devtoolsPlatform');
    expect(constructedEvent.eventData['devtoolsChrome'], 'devtoolsChrome');
    expect(constructedEvent.eventData['devtoolsVersion'], 'devtoolsVersion');
    expect(constructedEvent.eventData['ideLaunched'], 'ideLaunched');
    expect(constructedEvent.eventData['isExternalBuild'], 'isExternalBuild');
    expect(constructedEvent.eventData['isEmbedded'], 'isEmbedded');
    expect(
      constructedEvent.eventData['ideLaunchedFeature'],
      'ideLaunchedFeature',
    );
    expect(constructedEvent.eventData['isWasm'], 'true');
    expect(constructedEvent.eventData['stringField'], 'test');
    expect(constructedEvent.eventData['intField'], 100);
    expect(constructedEvent.eventData['boolField'], false);
    expect(constructedEvent.eventData.containsKey('nullableField'), false);
    expect(constructedEvent.eventData.length, 20);
  });

  test('Event.dartMCPEvent constructed', () {
    final event = Event.dartMCPEvent(
      client: 'test client',
      clientVersion: '1.0.0',
      serverVersion: '1.1.0',
      type: 'some_event',
      additionalData: _TestMetrics(
        boolField: true,
        stringField: 'hello',
        intField: 1,
      ),
    );
    expect(
      event.eventData,
      equals({
        'client': 'test client',
        'clientVersion': '1.0.0',
        'serverVersion': '1.1.0',
        'type': 'some_event',
        'boolField': true,
        'stringField': 'hello',
        'intField': 1,
      }),
    );
  });

  test('Event.packageSkillsEvent constructed', () {
    final event = Event.packageSkillsEvent(
      version: '1.1.1',
      type: 'some_event',
      additionalData: _TestMetrics(
        boolField: true,
        stringField: 'hello',
        intField: 1,
      ),
    );
    expect(
      event.eventData,
      equals({
        'version': '1.1.1',
        'type': 'some_event',
        'boolField': true,
        'stringField': 'hello',
        'intField': 1,
      }),
    );
  });

  test('Confirm all constructors were checked', () {
    final eventFile = File.fromUri(
      Isolate.resolvePackageUriSync(
        Uri.parse('package:unified_analytics/src/event.dart'),
      )!,
    );
    final sourceWithoutComments = eventFile.readAsStringSync().replaceAll(
      RegExp(r'//.*|/\*[\s\S]*?\*/'),
      '',
    );
    final constructorNames = RegExp(
      r'^\s*(?:factory\s+)?Event\.(?!_|fromJson\b)([a-zA-Z0-9_]+)\(',
      multiLine: true,
    ).allMatches(sourceWithoutComments).map((m) => m.group(1)!).toList();

    expect(
      constructorNames,
      unorderedEquals(
        DashEvent.values.map((e) => e.name).where((name) => name != 'ideEvent'),
      ),
    );

    // Change this integer below if your PR either adds or removes
    // an Event constructor
    final eventsAccountedForInTests = 38;
    expect(
      eventsAccountedForInTests,
      constructorNames.length,
      reason:
          'If you added or removed an event constructor, '
          'ensure you have updated '
          '`pkgs/unified_analytics/test/event_test.dart` '
          'to reflect the changes made',
    );
  });

  test('Serializing event to json successful', () {
    final event = Event.analyticsException(
      workflow: 'workflow',
      error: 'error',
      description: 'description',
    );

    final expectedResult =
        '{"eventName":"analytics_exception",'
        '"eventData":{"workflow":"workflow",'
        '"error":"error",'
        '"description":"description"}}';

    expect(event.toJson(), expectedResult);
  });

  test('Deserializing string to event successful', () {
    final eventJson =
        '{"eventName":"analytics_exception",'
        '"eventData":{"workflow":"workflow",'
        '"error":"error",'
        '"description":"description"}}';

    final eventConstructed = Event.fromJson(eventJson);
    expect(eventConstructed, isNotNull);
    eventConstructed!;

    expect(eventConstructed.eventName, DashEvent.analyticsException);
    expect(eventConstructed.eventData, {
      'workflow': 'workflow',
      'error': 'error',
      'description': 'description',
    });
  });

  test('Deserializing string to event unsuccessful for invalid eventName', () {
    final eventJson =
        '{"eventName":"NOT_VALID_NAME",'
        '"eventData":{"workflow":"workflow",'
        '"error":"error",'
        '"description":"description"}}';

    final eventConstructed = Event.fromJson(eventJson);
    expect(eventConstructed, isNull);
  });

  test('Deserializing string to event unsuccessful for invalid eventData', () {
    final eventJson =
        '{"eventName":"analytics_exception",'
        '"eventData": "not_valid_event_data"}';

    final eventConstructed = Event.fromJson(eventJson);
    expect(eventConstructed, isNull);
  });
}

final class _TestMetrics extends CustomMetrics {
  _TestMetrics({
    required this.stringField,
    required this.intField,
    required this.boolField,
  });

  final String stringField;
  final int intField;
  final bool boolField;

  @override
  Map<String, Object> toMap() => {
    'stringField': stringField,
    'intField': intField,
    'boolField': boolField,
  };
}
