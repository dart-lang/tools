// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:cli_util/cli_util.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:test/test.dart';

void main() {
  final baseDirectories = BaseDirectories('my_app');

  test('returns a non-empty string', () {
    expect(baseDirectories.cacheHome, isNotEmpty);
    expect(baseDirectories.configHome, isNotEmpty);
    expect(baseDirectories.dataHome, isNotEmpty);
    expect(baseDirectories.runtimeHome, isNotEmpty);
    expect(baseDirectories.stateHome, isNotEmpty);
  });

  test('has an ancestor folder that exists', () {
    void expectAncestorExists(String? path) {
      if (path == null) {
        // runtimeHome may be undefined on Linux.
        return;
      }
      // We expect that first two segments of the path exist. This is really
      // just a dummy check that some part of the path exists.
      final ancestorPath = p.joinAll(p.split(path).take(2));
      expect(Directory(ancestorPath).existsSync(), isTrue);
    }

    expectAncestorExists(baseDirectories.cacheHome);
    expectAncestorExists(baseDirectories.configHome);
    expectAncestorExists(baseDirectories.dataHome);
    expectAncestorExists(baseDirectories.runtimeHome);
    expectAncestorExists(baseDirectories.stateHome);
  });

  test('empty environment throws exception', () async {
    expect(
      () => BaseDirectories('Dart', environment: <String, String>{}).configHome,
      throwsA(isA<EnvironmentNotFoundException>()),
    );
  });

  group('cross-platform with FakePlatform', () {
    test(
      'Windows resolves APPDATA and LOCALAPPDATA with Windows separators',
      () {
        final platform = FakePlatform(
          operatingSystem: 'windows',
          environment: <String, String>{
            'APPDATA': r'C:\Users\TestUser\AppData\Roaming',
            'LOCALAPPDATA': r'C:\Users\TestUser\AppData\Local',
          },
        );
        final dirs = BaseDirectories('Dart', platform: platform);

        expect(dirs.cacheHome, r'C:\Users\TestUser\AppData\Local\Dart');
        expect(dirs.configHome, r'C:\Users\TestUser\AppData\Roaming\Dart');
        expect(dirs.dataHome, r'C:\Users\TestUser\AppData\Roaming\Dart');
        expect(dirs.runtimeHome, r'C:\Users\TestUser\AppData\Local\Dart');
        expect(dirs.stateHome, r'C:\Users\TestUser\AppData\Local\Dart');
      },
    );

    test(
      'Windows throws EnvironmentNotFoundException when env vars missing',
      () {
        final platform = FakePlatform(
          operatingSystem: 'windows',
          environment: <String, String>{},
        );
        final dirs = BaseDirectories('Dart', platform: platform);

        expect(
          () => dirs.configHome,
          throwsA(isA<EnvironmentNotFoundException>()),
        );
        expect(
          () => dirs.stateHome,
          throwsA(isA<EnvironmentNotFoundException>()),
        );
      },
    );

    test('macOS resolves Library paths from HOME', () {
      final platform = FakePlatform(
        operatingSystem: 'macos',
        environment: <String, String>{'HOME': '/Users/testuser'},
      );
      final dirs = BaseDirectories('Dart', platform: platform);

      expect(dirs.cacheHome, '/Users/testuser/Library/Caches/Dart');
      expect(
        dirs.configHome,
        '/Users/testuser/Library/Application Support/Dart',
      );
      expect(dirs.dataHome, '/Users/testuser/Library/Application Support/Dart');
      expect(
        dirs.runtimeHome,
        '/Users/testuser/Library/Caches/TemporaryItems/Dart',
      );
      expect(
        dirs.stateHome,
        '/Users/testuser/Library/Application Support/Dart',
      );
    });

    test('macOS throws EnvironmentNotFoundException when HOME missing', () {
      final platform = FakePlatform(
        operatingSystem: 'macos',
        environment: <String, String>{},
      );
      final dirs = BaseDirectories('Dart', platform: platform);

      expect(
        () => dirs.stateHome,
        throwsA(isA<EnvironmentNotFoundException>()),
      );
    });

    test('Linux resolves default XDG paths from HOME', () {
      final platform = FakePlatform(
        operatingSystem: 'linux',
        environment: <String, String>{'HOME': '/home/testuser'},
      );
      final dirs = BaseDirectories('Dart', platform: platform);

      expect(dirs.cacheHome, '/home/testuser/.cache/Dart');
      expect(dirs.configHome, '/home/testuser/.config/Dart');
      expect(dirs.dataHome, '/home/testuser/.local/share/Dart');
      expect(dirs.runtimeHome, isNull);
      expect(dirs.stateHome, '/home/testuser/.local/state/Dart');
    });

    test('Linux resolves custom XDG environment variables', () {
      final platform = FakePlatform(
        operatingSystem: 'linux',
        environment: <String, String>{
          'HOME': '/home/testuser',
          'XDG_CACHE_HOME': '/custom/cache',
          'XDG_CONFIG_HOME': '/custom/config',
          'XDG_DATA_HOME': '/custom/data',
          'XDG_RUNTIME_DIR': '/custom/runtime',
          'XDG_STATE_HOME': '/custom/state',
        },
      );
      final dirs = BaseDirectories('Dart', platform: platform);

      expect(dirs.cacheHome, '/custom/cache/Dart');
      expect(dirs.configHome, '/custom/config/Dart');
      expect(dirs.dataHome, '/custom/data/Dart');
      expect(dirs.runtimeHome, '/custom/runtime/Dart');
      expect(dirs.stateHome, '/custom/state/Dart');
    });

    test('explicit environment overrides platform.environment', () {
      final platform = FakePlatform(
        operatingSystem: 'linux',
        environment: <String, String>{'HOME': '/home/from_platform'},
      );
      final dirs = BaseDirectories(
        'Dart',
        platform: platform,
        environment: <String, String>{'HOME': '/home/from_arg'},
      );

      expect(dirs.stateHome, '/home/from_arg/.local/state/Dart');
    });

    test('explicit pathContext overrides default path context', () {
      final platform = FakePlatform(
        operatingSystem: 'linux',
        environment: <String, String>{'HOME': r'C:\home\testuser'},
      );
      final dirs = BaseDirectories(
        'Dart',
        platform: platform,
        pathContext: p.windows,
      );

      expect(dirs.stateHome, r'C:\home\testuser\.local\state\Dart');
    });

    test('unsupported platform throws UnsupportedError', () {
      final platform = FakePlatform(
        operatingSystem: 'fuchsia',
        environment: <String, String>{'HOME': '/home/testuser'},
      );
      final dirs = BaseDirectories('Dart', platform: platform);

      expect(() => dirs.stateHome, throwsA(isA<UnsupportedError>()));
    });
  });
}
