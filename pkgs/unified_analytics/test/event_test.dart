// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
}
