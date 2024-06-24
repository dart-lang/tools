// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:mirrors';

import 'package:test/test.dart';

import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
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
        constructedEvent.eventData['openWorkspacePaths'], 'openWorkspacePaths');
    expect(constructedEvent.eventData['removed'], 'removed');
    expect(constructedEvent.eventData.length, 9);
  });

  test('Event.commandExecuted constructed', () {
    Event generateEvent() => Event.commandExecuted(
          count: 5,
          name: 'name',
        );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.commandExecuted);
    expect(constructedEvent.eventData['count'], 5);
    expect(constructedEvent.eventData['name'], 'name');
    expect(constructedEvent.eventData.length, 2);
  });

  test('Event.contextStructure constructed', () {
    Event generateEvent() => Event.contextStructure(
          contextsFromBothFiles: 1,
          contextsFromOptionsFiles: 2,
          contextsFromPackagesFiles: 3,
          contextsWithoutFiles: 4,
          immediateFileCount: 5,
          immediateFileLineCount: 6,
          numberOfContexts: 7,
          transitiveFileCount: 8,
          transitiveFileLineCount: 9,
          transitiveFileUniqueCount: 10,
          transitiveFileUniqueLineCount: 11,
        );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.contextStructure);
    expect(constructedEvent.eventData['contextsFromBothFiles'], 1);
    expect(constructedEvent.eventData['contextsFromOptionsFiles'], 2);
    expect(constructedEvent.eventData['contextsFromPackagesFiles'], 3);
    expect(constructedEvent.eventData['contextsWithoutFiles'], 4);
    expect(constructedEvent.eventData['immediateFileCount'], 5);
    expect(constructedEvent.eventData['immediateFileLineCount'], 6);
    expect(constructedEvent.eventData['numberOfContexts'], 7);
    expect(constructedEvent.eventData['transitiveFileCount'], 8);
    expect(constructedEvent.eventData['transitiveFileLineCount'], 9);
    expect(constructedEvent.eventData['transitiveFileUniqueCount'], 10);
    expect(constructedEvent.eventData['transitiveFileUniqueLineCount'], 11);
    expect(constructedEvent.eventData.length, 11);
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
        constructedEvent.eventData['enabledExperiments'], 'enabledExperiments');
    expect(constructedEvent.eventData['exitCode'], 0);
    expect(constructedEvent.eventData.length, 3);
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
    Event generateEvent() => Event.lintUsageCount(
          count: 5,
          name: 'name',
        );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.lintUsageCount);
    expect(constructedEvent.eventData['count'], 5);
    expect(constructedEvent.eventData['name'], 'name');
    expect(constructedEvent.eventData.length, 2);
  });

  test('Event.memoryInfo constructed', () {
    Event generateEvent() => Event.memoryInfo(
          rss: 4,
          periodSec: 5,
          mbPerSec: 5.55,
        );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.memoryInfo);
    expect(constructedEvent.eventData['rss'], 4);
    expect(constructedEvent.eventData['periodSec'], 5);
    expect(constructedEvent.eventData['mbPerSec'], 5.55);
    expect(constructedEvent.eventData.length, 3);
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

  test('Event.pluginUse constructed', () {
    Event generateEvent() => Event.pluginUse(
          count: 5,
          enabled: 'enabled',
          pluginId: 'pluginId',
        );

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
    expect(constructedEvent.eventData.length, 5);
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
    Event generateEvent() => Event.surveyAction(
          surveyId: 'surveyId',
          status: 'status',
        );

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
          maxRss: 123,
        );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.flutterCommandResult);
    expect(constructedEvent.eventData['commandPath'], 'commandPath');
    expect(constructedEvent.eventData['result'], 'result');
    expect(constructedEvent.eventData['commandHasTerminal'], true);
    expect(constructedEvent.eventData['maxRss'], 123);
    expect(constructedEvent.eventData.length, 4);
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
    Event generateEvent() => Event.exception(exception: 'exception');

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.exception);
    expect(constructedEvent.eventData['exception'], 'exception');
    expect(constructedEvent.eventData.length, 1);
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
          buildAarProjectType: 'buildAarProjectType',
          buildAarTargetPlatform: 'buildAarTargetPlatform',
          buildApkTargetPlatform: 'buildApkTargetPlatform',
          buildApkBuildMode: 'buildApkBuildMode',
          buildApkSplitPerAbi: true,
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
        );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.commandUsageValues);
    expect(constructedEvent.eventData['workflow'], 'workflow');
    expect(constructedEvent.eventData['buildBundleTargetPlatform'],
        'buildBundleTargetPlatform');
    expect(constructedEvent.eventData['buildBundleIsModule'], true);
    expect(constructedEvent.eventData['buildAarProjectType'],
        'buildAarProjectType');
    expect(constructedEvent.eventData['buildAarTargetPlatform'],
        'buildAarTargetPlatform');
    expect(constructedEvent.eventData['buildApkTargetPlatform'],
        'buildApkTargetPlatform');
    expect(
        constructedEvent.eventData['buildApkBuildMode'], 'buildApkBuildMode');
    expect(constructedEvent.eventData['buildApkSplitPerAbi'], true);
    expect(constructedEvent.eventData['buildAppBundleTargetPlatform'],
        'buildAppBundleTargetPlatform');
    expect(constructedEvent.eventData['buildAppBundleBuildMode'],
        'buildAppBundleBuildMode');
    expect(
        constructedEvent.eventData['createProjectType'], 'createProjectType');
    expect(constructedEvent.eventData['createAndroidLanguage'],
        'createAndroidLanguage');
    expect(
        constructedEvent.eventData['createIosLanguage'], 'createIosLanguage');
    expect(constructedEvent.eventData['packagesNumberPlugins'], 123);
    expect(constructedEvent.eventData['packagesProjectModule'], true);
    expect(constructedEvent.eventData['packagesAndroidEmbeddingVersion'],
        'packagesAndroidEmbeddingVersion');
    expect(constructedEvent.eventData['runIsEmulator'], true);
    expect(constructedEvent.eventData['runTargetName'], 'runTargetName');
    expect(
        constructedEvent.eventData['runTargetOsVersion'], 'runTargetOsVersion');
    expect(constructedEvent.eventData['runModeName'], 'runModeName');
    expect(constructedEvent.eventData['runProjectModule'], true);
    expect(constructedEvent.eventData['runProjectHostLanguage'],
        'runProjectHostLanguage');
    expect(constructedEvent.eventData['runAndroidEmbeddingVersion'],
        'runAndroidEmbeddingVersion');
    expect(constructedEvent.eventData['runEnableImpeller'], true);
    expect(constructedEvent.eventData['runIOSInterfaceType'],
        'runIOSInterfaceType');
    expect(constructedEvent.eventData.length, 27);
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
          uiDurationMicros: 123,
          rasterDurationMicros: 123,
          shaderCompilationDurationMicros: 123,
          traceEventCount: 123,
          cpuSampleCount: 123,
          cpuStackDepth: 123,
          heapDiffObjectsBefore: 123,
          heapDiffObjectsAfter: 123,
          heapObjectsTotal: 123,
          rootSetCount: 123,
          rowCount: 123,
          inspectorTreeControllerId: 123,
        );

    final constructedEvent = generateEvent();

    expect(generateEvent, returnsNormally);
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
        constructedEvent.eventData['ideLaunchedFeature'], 'ideLaunchedFeature');
    expect(constructedEvent.eventData['uiDurationMicros'], 123);
    expect(constructedEvent.eventData['rasterDurationMicros'], 123);
    expect(constructedEvent.eventData['shaderCompilationDurationMicros'], 123);
    expect(constructedEvent.eventData['traceEventCount'], 123);
    expect(constructedEvent.eventData['cpuSampleCount'], 123);
    expect(constructedEvent.eventData['cpuStackDepth'], 123);
    expect(constructedEvent.eventData['heapDiffObjectsBefore'], 123);
    expect(constructedEvent.eventData['heapDiffObjectsAfter'], 123);
    expect(constructedEvent.eventData['heapObjectsTotal'], 123);
    expect(constructedEvent.eventData['rootSetCount'], 123);
    expect(constructedEvent.eventData['rowCount'], 123);
    expect(constructedEvent.eventData['inspectorTreeControllerId'], 123);
    expect(constructedEvent.eventData.length, 27);
  });

  test('Confirm all constructors were checked', () {
    var constructorCount = 0;
    for (final declaration in reflectClass(Event).declarations.keys) {
      // Count public constructors but omit private constructors
      if (declaration.toString().contains('Event.') &&
          !declaration.toString().contains('Event._')) constructorCount++;
    }

    // Change this integer below if your PR either adds or removes
    // an Event constructor
    final eventsAccountedForInTests = 27;
    expect(eventsAccountedForInTests, constructorCount,
        reason: 'If you added or removed an event constructor, '
            'ensure you have updated '
            '`pkgs/unified_analytics/test/event_test.dart` '
            'to reflect the changes made');
  });

  test('Serializing event to json successful', () {
    final event = Event.analyticsException(
      workflow: 'workflow',
      error: 'error',
      description: 'description',
    );

    final expectedResult = '{"eventName":"analytics_exception",'
        '"eventData":{"workflow":"workflow",'
        '"error":"error",'
        '"description":"description"}}';

    expect(event.toJson(), expectedResult);
  });

  test('Deserializing string to event successful', () {
    final eventJson = '{"eventName":"analytics_exception",'
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
    final eventJson = '{"eventName":"NOT_VALID_NAME",'
        '"eventData":{"workflow":"workflow",'
        '"error":"error",'
        '"description":"description"}}';

    final eventConstructed = Event.fromJson(eventJson);
    expect(eventConstructed, isNull);
  });

  test('Deserializing string to event unsuccessful for invalid eventData', () {
    final eventJson = '{"eventName":"analytics_exception",'
        '"eventData": "not_valid_event_data"}';

    final eventConstructed = Event.fromJson(eventJson);
    expect(eventConstructed, isNull);
  });
}
