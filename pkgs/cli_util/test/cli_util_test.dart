// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';
import 'dart:io';

import 'package:cli_util/cli_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('sdkPath & dartExecutable', () {
    test('resolves in active VM environment', () {
      final path = sdkPath;
      if (path == null) {
        markTestSkipped('sdkPath is not available in this environment');
        return;
      }
      expect(Directory(path).existsSync(), isTrue);
      expect(isValidSdkPath(path), isTrue);

      expect(dartExecutable, isNotNull);
      expect(File(dartExecutable!).existsSync(), isTrue);
    });

    test('isValidSdkPath validation', () {
      expect(isValidSdkPath(''), isFalse);
      if (sdkPath case final path?) {
        expect(isValidSdkPath(path), isTrue);
      }

      final tempDir = Directory.systemTemp.createTempSync('invalid_sdk_test');
      try {
        expect(isValidSdkPath(tempDir.path), isFalse);

        // Add dummy libraries.json
        final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();
        File(p.join(libDir.path, 'libraries.json')).writeAsStringSync('{}');
        expect(
          isValidSdkPath(tempDir.path),
          isFalse,
        ); // Missing bin/dart or version

        // Add dummy version file
        File(p.join(tempDir.path, 'version')).writeAsStringSync('3.8.0');
        expect(isValidSdkPath(tempDir.path), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('DART_ROOT / DART_SDK environment overrides', () {
      final mockSdk = Directory.systemTemp.createTempSync('mock_sdk');
      try {
        Directory(p.join(mockSdk.path, 'lib')).createSync();
        File(
          p.join(mockSdk.path, 'lib', 'libraries.json'),
        ).writeAsStringSync('{}');
        File(p.join(mockSdk.path, 'version')).writeAsStringSync('3.8.0');

        runZoned(
          () {
            expect(sdkPath, mockSdk.path);
          },
          zoneValues: {
            environmentOverridesKey: <String, String>{
              'DART_ROOT': mockSdk.path,
              '_DART_RESOLVED_EXECUTABLE': '',
            },
          },
        );

        runZoned(
          () {
            expect(sdkPath, mockSdk.path);
          },
          zoneValues: {
            environmentOverridesKey: <String, String>{
              'DART_SDK': mockSdk.path,
              '_DART_RESOLVED_EXECUTABLE': '',
            },
          },
        );
      } finally {
        mockSdk.deleteSync(recursive: true);
      }
    });

    test('PATH traversal with Flutter wrapper structure', () {
      final tempDir = Directory.systemTemp.createTempSync('mock_path');
      try {
        final mockFlutter = Directory(p.join(tempDir.path, 'flutter'))
          ..createSync();
        final mockFlutterBin = Directory(p.join(mockFlutter.path, 'bin'))
          ..createSync();
        final mockDartSdk = Directory(
          p.join(mockFlutter.path, 'bin', 'cache', 'dart-sdk'),
        )..createSync(recursive: true);
        Directory(p.join(mockDartSdk.path, 'lib')).createSync();
        File(
          p.join(mockDartSdk.path, 'lib', 'libraries.json'),
        ).writeAsStringSync('{}');
        File(p.join(mockDartSdk.path, 'version')).writeAsStringSync('3.8.0');

        File(p.join(mockFlutterBin.path, 'dart')).createSync();
        File(p.join(mockFlutterBin.path, 'dart.bat')).createSync();
        File(p.join(mockFlutterBin.path, 'dart.exe')).createSync();

        runZoned(
          () {
            expect(sdkPath, mockDartSdk.resolveSymbolicLinksSync());
          },
          zoneValues: {
            environmentOverridesKey: <String, String>{
              'DART_ROOT': '',
              'DART_SDK': '',
              'FLUTTER_ROOT': '',
              '_DART_RESOLVED_EXECUTABLE': '',
              'PATH': mockFlutterBin.path,
            },
          },
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('PATH traversal handles quoted directory entries', () {
      final tempDir = Directory.systemTemp.createTempSync('mock_path_quoted');
      try {
        final mockSdk = Directory(p.join(tempDir.path, 'dart-sdk'))
          ..createSync();
        Directory(p.join(mockSdk.path, 'lib')).createSync();
        File(
          p.join(mockSdk.path, 'lib', 'libraries.json'),
        ).writeAsStringSync('{}');
        File(p.join(mockSdk.path, 'version')).writeAsStringSync('3.8.0');
        final binDir = Directory(p.join(mockSdk.path, 'bin'))..createSync();
        File(p.join(binDir.path, 'dart')).createSync();
        File(p.join(binDir.path, 'dart.bat')).createSync();
        File(p.join(binDir.path, 'dart.exe')).createSync();

        runZoned(
          () {
            expect(sdkPath, mockSdk.resolveSymbolicLinksSync());
          },
          zoneValues: {
            environmentOverridesKey: <String, String>{
              'DART_ROOT': '',
              'DART_SDK': '',
              'FLUTTER_ROOT': '',
              '_DART_RESOLVED_EXECUTABLE': '',
              'PATH': '  "${binDir.path}"  ',
            },
          },
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('FLUTTER_ROOT fallback override', () {
      final mockFlutter = Directory.systemTemp.createTempSync('mock_flutter');
      try {
        final mockDartSdk = Directory(
          p.join(mockFlutter.path, 'bin', 'cache', 'dart-sdk'),
        )..createSync(recursive: true);
        Directory(p.join(mockDartSdk.path, 'lib')).createSync();
        File(
          p.join(mockDartSdk.path, 'lib', 'libraries.json'),
        ).writeAsStringSync('{}');
        File(p.join(mockDartSdk.path, 'version')).writeAsStringSync('3.8.0');

        runZoned(
          () {
            expect(sdkPath, mockDartSdk.path);
          },
          zoneValues: {
            environmentOverridesKey: <String, String>{
              'DART_ROOT': '',
              'DART_SDK': '',
              '_DART_RESOLVED_EXECUTABLE': '',
              'PATH': '',
              'FLUTTER_ROOT': mockFlutter.path,
            },
          },
        );
      } finally {
        mockFlutter.deleteSync(recursive: true);
      }
    });

    test('returns null when SDK is not found and environment is empty', () {
      runZoned(
        () {
          expect(sdkPath, isNull);
          expect(dartExecutable, isNull);
        },
        zoneValues: {
          environmentOverridesKey: <String, String>{
            'DART_ROOT': '',
            'DART_SDK': '',
            'FLUTTER_ROOT': '',
            'PATH': '',
            '_DART_RESOLVED_EXECUTABLE': '',
          },
        },
      );
    });
  });

  group('applicationConfigHome', () {
    test('returns a non-empty string', () {
      expect(applicationConfigHome('dart'), isNotEmpty);
    });

    test('has an ancestor folder that exists', () {
      final path = p.split(applicationConfigHome('dart'));
      // We expect that first two segments of the path exist. This is really
      // just a dummy check that some part of the path exists.
      expect(Directory(p.joinAll(path.take(2))).existsSync(), isTrue);
    });

    test('empty environment throws exception', () async {
      expect(() {
        runZoned(
          () => applicationConfigHome('dart'),
          zoneValues: {environmentOverridesKey: <String, String>{}},
        );
      }, throwsA(isA<EnvironmentNotFoundException>()));
    });
  });
}
