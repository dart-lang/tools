// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:unified_analytics/src/constants.dart';
import 'package:unified_analytics/src/ga_client.dart';
import 'package:unified_analytics/src/utils.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  final envVar = DashEnvVar.tool.name;

  group('resolveRootToolIn', () {
    test('uses DASH__TOOL when it names a tool', () {
      expect(
        resolveRootToolIn(
          {envVar: 'vscode-plugins'},
          tool: DashTool.analysisServer,
          fallbackRootTool: DashTool.intellijPlugins,
        ),
        DashTool.vscodePlugins,
      );
    });

    test('DASH__TOOL takes precedence over a top-level tool', () {
      expect(
        resolveRootToolIn({envVar: 'vscode-plugins'}, tool: DashTool.dartTool),
        DashTool.vscodePlugins,
      );
    });

    for (final value in ['not-a-tool', '', 'vscodePlugins']) {
      test('ignores the invalid DASH__TOOL value "$value"', () {
        expect(
          resolveRootToolIn({envVar: value}, tool: DashTool.dartTool),
          DashTool.dartTool,
        );
      });
    }

    test('ignores a shared-component label in DASH__TOOL', () {
      expect(
        resolveRootToolIn({
          envVar: 'analysis-server',
        }, tool: DashTool.dartMcpServer),
        isNull,
      );
      expect(
        resolveRootToolIn({
          envVar: 'analysis-server',
        }, tool: DashTool.flutterTool),
        DashTool.flutterTool,
      );
    });

    test('uses fallbackRootTool when DASH__TOOL is unset', () {
      expect(
        resolveRootToolIn(
          {},
          tool: DashTool.analysisServer,
          fallbackRootTool: DashTool.intellijPlugins,
        ),
        DashTool.intellijPlugins,
      );
    });

    test('uses fallbackRootTool when DASH__TOOL is invalid', () {
      expect(
        resolveRootToolIn(
          {envVar: 'not-a-tool'},
          tool: DashTool.analysisServer,
          fallbackRootTool: DashTool.vscodePlugins,
        ),
        DashTool.vscodePlugins,
      );
    });

    test('asserts that fallbackRootTool can be a root tool', () {
      expect(
        () => resolveRootToolIn(
          {},
          tool: DashTool.devtools,
          fallbackRootTool: DashTool.analysisServer,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    for (final tool in [
      DashTool.dartTool,
      DashTool.flutterTool,
      DashTool.devtools,
    ]) {
      test('falls back to ${tool.label} as its own root tool', () {
        expect(resolveRootToolIn({}, tool: tool), tool);
      });
    }

    for (final tool in [
      DashTool.analysisServer,
      DashTool.dartMcpServer,
      DashTool.skillsCli,
    ]) {
      test('returns null for ${tool.label} with no root tool', () {
        expect(resolveRootToolIn({}, tool: tool), isNull);
      });
    }
  });

  late MemoryFileSystem fs;
  late Directory home;

  FakeAnalytics createAnalytics({
    DashTool tool = DashTool.flutterTool,
    Map<String, String> environment = const {},
    DashTool? fallbackRootTool,
    DashTool? rootTool,
    bool isExternal = true,
    GAClient? gaClient,
  }) => Analytics.fake(
    tool: tool,
    homeDirectory: home,
    dartVersion: 'dartVersion',
    fs: fs,
    environment: environment,
    fallbackRootTool: fallbackRootTool,
    rootTool: rootTool,
    isExternal: isExternal,
    gaClient: gaClient,
  );

  setUp(() {
    fs = MemoryFileSystem.test(
      style: io.Platform.isWindows
          ? FileSystemStyle.windows
          : FileSystemStyle.posix,
    );
    home = fs.directory('home');
  });

  group('Analytics root tool', () {
    Object? rootToolProperty(Analytics analytics) =>
        analytics.userPropertyMap['root_tool']?['value'];

    test('defaults to the tool for a top-level tool', () {
      final analytics = createAnalytics(tool: DashTool.dartTool);
      expect(analytics.rootTool, DashTool.dartTool);
      expect(rootToolProperty(analytics), 'dart-tool');
    });

    test('reads DASH__TOOL from the environment', () {
      final analytics = createAnalytics(
        tool: DashTool.analysisServer,
        environment: {envVar: 'vscode-plugins'},
      );
      expect(analytics.tool, DashTool.analysisServer);
      expect(analytics.rootTool, DashTool.vscodePlugins);
      expect(analytics.userPropertyMap['tool']?['value'], 'analysis-server');
      expect(rootToolProperty(analytics), 'vscode-plugins');
    });

    test('uses fallbackRootTool when DASH__TOOL is unset', () {
      final analytics = createAnalytics(
        tool: DashTool.analysisServer,
        fallbackRootTool: DashTool.intellijPlugins,
      );
      expect(analytics.rootTool, DashTool.intellijPlugins);
      expect(rootToolProperty(analytics), 'intellij-plugins');
    });

    test('is null for a shared component with no root tool', () {
      final analytics = createAnalytics(tool: DashTool.dartMcpServer);
      expect(analytics.rootTool, isNull);
      expect(analytics.userPropertyMap.containsKey('root_tool'), isTrue);
      expect(rootToolProperty(analytics), isNull);
    });

    test('asserts that the rootTool override can be a root tool', () {
      expect(
        () => createAnalytics(rootTool: DashTool.analysisServer),
        throwsA(isA<AssertionError>()),
      );
    });

    test('the rootTool override skips resolution', () {
      final analytics = createAnalytics(
        tool: DashTool.analysisServer,
        environment: {envVar: 'vscode-plugins'},
        fallbackRootTool: DashTool.intellijPlugins,
        rootTool: DashTool.androidStudioPlugins,
      );
      expect(analytics.rootTool, DashTool.androidStudioPlugins);
      expect(rootToolProperty(analytics), 'android-studio-plugins');
    });

    test('every event carries both tool and root_tool', () async {
      final environment = {envVar: 'vscode-plugins'};
      createAnalytics(
        tool: DashTool.analysisServer,
        environment: environment,
      ).clientShowedMessage();

      final gaClient = _RecordingGAClient();
      final analytics = createAnalytics(
        tool: DashTool.analysisServer,
        environment: environment,
        gaClient: gaClient,
      );
      expect(analytics.okToSend, isTrue);

      // Events sent through `send`, which are logged locally.
      final events = [
        Event.hotReloadTime(timeMs: 50),
        Event.analyticsException(workflow: 'workflow', error: 'error'),
        Event.commandUsageValues(workflow: 'analyze', commandHasTerminal: true),
      ];
      events.forEach(analytics.send);
      expect(analytics.sentEvents, events);

      final logRecords = home
          .childDirectory(kDartToolDirectoryName)
          .childFile(kLogFileName)
          .readAsLinesSync()
          .where((line) => line.isNotEmpty)
          .map((line) => jsonDecode(line) as Map<String, Object?>)
          .toList();
      expect(logRecords, hasLength(events.length));

      // The opt-out event, which `setTelemetry` sends directly to GA without
      // going through `send`.
      await analytics.setTelemetry(false);
      expect(gaClient.sentBodies, hasLength(1));

      for (final body in [...logRecords, ...gaClient.sentBodies]) {
        final userProperties = body['user_properties'] as Map<String, Object?>;
        expect(userProperties['tool'], {'value': 'analysis-server'});
        expect(userProperties['root_tool'], {'value': 'vscode-plugins'});
      }
    });

    test('sent events carry both tool and root_tool', () {
      final environment = {envVar: 'intellij-plugins'};
      // Complete the first run so that the next instance can send events.
      createAnalytics(environment: environment).clientShowedMessage();

      final analytics = createAnalytics(environment: environment);
      expect(analytics.okToSend, isTrue);
      analytics.send(Event.hotReloadTime(timeMs: 50));
      expect(analytics.sentEvents, hasLength(1));

      final logLines = home
          .childDirectory(kDartToolDirectoryName)
          .childFile(kLogFileName)
          .readAsLinesSync()
          .where((line) => line.isNotEmpty);
      expect(logLines, hasLength(1));
      final userProperties =
          (jsonDecode(logLines.single)
                  as Map<String, Object?>)['user_properties']
              as Map<String, Object?>;
      expect(userProperties['tool'], {'value': 'flutter-tool'});
      expect(userProperties['root_tool'], {'value': 'intellij-plugins'});
    });
  });

  group('getEnvironmentIn', () {
    final suppressVar = DashEnvVar.suppressAnalytics.name;

    test('writes the label, which DashTool.fromLabel accepts', () {
      final env = getEnvironmentIn({}, currentTool: DashTool.vscodePlugins);
      expect(env[envVar], 'vscode-plugins');
      expect(DashTool.fromLabel(env[envVar]!), DashTool.vscodePlugins);
    });

    test('a top-level tool with no DASH__TOOL passes on itself', () {
      expect(
        getEnvironmentIn({}, currentTool: DashTool.flutterTool)[envVar],
        'flutter-tool',
      );
    });

    test('passes on an inherited root tool', () {
      expect(
        getEnvironmentIn({
          envVar: 'intellij-plugins',
        }, currentTool: DashTool.dartTool)[envVar],
        'intellij-plugins',
      );
    });

    test('a shared component passes on its root tool, not itself', () {
      expect(
        getEnvironmentIn({
          envVar: 'vscode-plugins',
        }, currentTool: DashTool.analysisServer)[envVar],
        'vscode-plugins',
      );
    });

    test('leaves out DASH__TOOL when no root tool resolves', () {
      expect(
        getEnvironmentIn({}, currentTool: DashTool.dartMcpServer),
        isNot(contains(envVar)),
      );
    });

    for (final inherited in [
      'analysis-server',
      'not-a-tool',
      'vscodePlugins',
    ]) {
      test('drops the inherited invalid value "$inherited" when no root tool '
          'resolves', () {
        expect(
          getEnvironmentIn({
            envVar: inherited,
          }, currentTool: DashTool.skillsCli),
          isNot(contains(envVar)),
        );
      });

      test('replaces the inherited invalid value "$inherited" with the '
          'current tool', () {
        expect(
          getEnvironmentIn({
            envVar: inherited,
          }, currentTool: DashTool.dartTool)[envVar],
          'dart-tool',
        );
      });
    }

    test('keeps unrelated variables', () {
      expect(
        getEnvironmentIn({'OTHER': 'value'}, currentTool: DashTool.dartTool),
        containsPair('OTHER', 'value'),
      );
    });

    test('sets DASH__SUPPRESS_ANALYTICS', () {
      expect(
        getEnvironmentIn({}, currentTool: DashTool.dartTool)[suppressVar],
        'false',
      );
      expect(
        getEnvironmentIn(
          {},
          currentTool: DashTool.dartTool,
          suppressAnalytics: true,
        )[suppressVar],
        'true',
      );
      expect(
        getEnvironmentIn({
          suppressVar: 'true',
        }, currentTool: DashTool.dartTool)[suppressVar],
        'true',
      );
    });
  });

  group('Consent keyed on root tool', () {
    File configFile() =>
        home.childDirectory(kDartToolDirectoryName).childFile(kConfigFileName);

    group('shared component with no root tool', () {
      FakeAnalytics createRootless({bool isExternal = true}) =>
          createAnalytics(tool: DashTool.dartMcpServer, isExternal: isExternal);

      test('disables analytics for the session', () {
        final analytics = createRootless();
        expect(analytics.rootTool, isNull);
        expect(analytics.okToSend, isFalse);

        analytics.send(Event.hotReloadTime(timeMs: 50));
        expect(analytics.sentEvents, isEmpty);
      });

      test('internal builds keep sending without a root tool', () {
        final analytics = createRootless(isExternal: false);
        expect(analytics.rootTool, isNull);
        expect(analytics.okToSend, isTrue);
        expect(analytics.shouldShowMessage, isFalse);

        analytics.send(Event.hotReloadTime(timeMs: 50));
        expect(analytics.sentEvents, hasLength(1));
        expect(analytics.userPropertyMap['tool']?['value'], 'dart-mcp-server');
        expect(analytics.userPropertyMap['root_tool']?['value'], isNull);
      });

      test('shows no consent message', () {
        final analytics = createRootless();
        expect(analytics.shouldShowMessage, isFalse);
        expect(analytics.getConsentMessage, isEmpty);
      });

      test('never writes to the config file', () async {
        final analytics = createRootless();
        final before = configFile().readAsStringSync();

        analytics.clientShowedMessage();
        await analytics.setTelemetry(false);

        expect(configFile().readAsStringSync(), before);
        expect(analytics.parsedTools, isEmpty);
      });
    });

    test('a shared component records consent under its root tool', () {
      final environment = {envVar: 'vscode-plugins'};
      final analytics = createAnalytics(
        tool: DashTool.analysisServer,
        environment: environment,
      );

      expect(analytics.shouldShowMessage, isTrue);
      expect(analytics.okToSend, isFalse);

      analytics.clientShowedMessage();

      final config = configFile().readAsStringSync();
      expect(config, contains('vscode-plugins='));
      expect(config, isNot(contains('analysis-server=')));

      // The next session for the same root tool can send without a prompt.
      final next = createAnalytics(
        tool: DashTool.analysisServer,
        environment: environment,
      );
      expect(next.shouldShowMessage, isFalse);
      expect(next.okToSend, isTrue);
    });

    test('consent given through one tool covers others with the same root', () {
      final environment = {envVar: 'intellij-plugins'};
      createAnalytics(environment: environment).clientShowedMessage();

      for (final tool in [DashTool.analysisServer, DashTool.dartTool]) {
        final analytics = createAnalytics(tool: tool, environment: environment);
        expect(analytics.shouldShowMessage, isFalse, reason: tool.label);
        expect(analytics.okToSend, isTrue, reason: tool.label);
      }
    });

    test('a top-level tool still needs consent under a new root tool', () {
      // Onboard flutter-tool as its own root.
      createAnalytics().clientShowedMessage();

      final analytics = createAnalytics(
        environment: {envVar: 'vscode-plugins'},
      );
      expect(analytics.rootTool, DashTool.vscodePlugins);
      expect(analytics.shouldShowMessage, isTrue);
      expect(analytics.okToSend, isFalse);
    });

    test('the consent message describes the root tool', () {
      final analytics = createAnalytics(
        tool: DashTool.analysisServer,
        environment: {envVar: 'flutter-tool'},
      );
      expect(
        analytics.getConsentMessage,
        contains(DashTool.flutterTool.description),
      );
      expect(analytics.getConsentMessage, contains('flutter --disable'));
      expect(
        analytics.getConsentMessage,
        isNot(contains(DashTool.analysisServer.description)),
      );
    });

    test('consent for a top-level tool on its own is unchanged', () {
      final analytics = createAnalytics();
      expect(analytics.rootTool, DashTool.flutterTool);
      expect(analytics.shouldShowMessage, isTrue);
      expect(
        analytics.getConsentMessage,
        contains(DashTool.flutterTool.description),
      );

      analytics.clientShowedMessage();
      expect(configFile().readAsStringSync(), contains('flutter-tool='));
    });
  });
}

/// A [GAClient] that records request bodies instead of sending them.
class _RecordingGAClient extends GAClient {
  _RecordingGAClient() : super(measurementId: 'test', apiSecret: 'test');

  final List<Map<String, Object?>> sentBodies = [];

  @override
  Future<http.Response> sendData(Map<String, Object?> body) {
    sentBodies.add(body);
    return Future.value(http.Response('', 200));
  }
}
