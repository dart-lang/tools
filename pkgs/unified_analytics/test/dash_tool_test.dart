// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:unified_analytics/src/utils.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  const topLevelTools = [
    DashTool.androidStudioPlugins,
    DashTool.dartTool,
    DashTool.devtools,
    DashTool.flutterTool,
    DashTool.intellijPlugins,
    DashTool.vscodePlugins,
  ];
  const sharedComponents = [
    DashTool.analysisServer,
    DashTool.dartMcpServer,
    DashTool.skillsCli,
  ];

  group('DashTool', () {
    test('every value is either a top-level tool or a shared component', () {
      expect(
        DashTool.values,
        unorderedEquals([...topLevelTools, ...sharedComponents]),
      );
    });

    for (final tool in topLevelTools) {
      test('${tool.label} is a top-level tool that can be the root tool', () {
        expect(tool.kind, DashToolKind.tool);
        expect(tool.canBeRootTool, isTrue);
      });
    }

    for (final tool in sharedComponents) {
      test('${tool.label} is a shared component that cannot be the root '
          'tool', () {
        expect(tool.kind, DashToolKind.sharedComponent);
        expect(tool.canBeRootTool, isFalse);
      });
    }

    test('shared components have the expected labels', () {
      expect(DashTool.analysisServer.label, 'analysis-server');
      expect(DashTool.dartMcpServer.label, 'dart-mcp-server');
      expect(DashTool.skillsCli.label, 'skills-cli');
    });

    test('fromLabel round-trips every value', () {
      for (final tool in DashTool.values) {
        expect(DashTool.fromLabel(tool.label), tool);
      }
    });
  });

  group('topLevelToolIn', () {
    final envVar = DashEnvVar.tool.name;

    test('returns current when DASH__TOOL is unset', () {
      expect(topLevelToolIn({}, current: DashTool.devtools), DashTool.devtools);
    });

    test('returns current when DASH__TOOL is invalid', () {
      expect(
        topLevelToolIn({envVar: 'not-a-tool'}, current: DashTool.devtools),
        DashTool.devtools,
      );
    });

    for (final tool in topLevelTools) {
      test('returns ${tool.label} from DASH__TOOL', () {
        expect(
          topLevelToolIn({envVar: tool.label}, current: DashTool.devtools),
          tool,
        );
      });
    }

    for (final tool in sharedComponents) {
      test('rejects the shared component ${tool.label} in DASH__TOOL', () {
        expect(
          topLevelToolIn({envVar: tool.label}, current: DashTool.flutterTool),
          DashTool.flutterTool,
        );
      });
    }
  });
}
