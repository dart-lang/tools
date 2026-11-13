// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Timeout.factor(3)
library;

import 'dart:convert';
import 'dart:io';
import 'package:api_summary/api_summary.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

void main() {
  late Directory tempKernelDir;
  late String compiledCliDill;

  setUpAll(() async {
    final packageDir = _pkgDir();
    Directory.current = packageDir;
    tempKernelDir = Directory.systemTemp.createTempSync(
      'api_summary_cli_test_',
    );
    compiledCliDill = p.join(tempKernelDir.path, 'api_summary.dill');
    final compileRes = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      if (Platform.packageConfig != null)
        '--packages=${Uri.parse(Platform.packageConfig!).toFilePath()}',
      p.join(packageDir, 'bin', 'api_summary.dart'),
      '-o',
      compiledCliDill,
    ], workingDirectory: packageDir);
    if (compileRes.exitCode != 0) {
      throw StateError(
        'Failed to compile bin/api_summary.dart to kernel:\n'
        '${compileRes.stderr}',
      );
    }
  });

  tearDownAll(() {
    if (tempKernelDir.existsSync()) {
      tempKernelDir.deleteSync(recursive: true);
    }
  });

  Future<ProcessResult> runCli(List<String> args) {
    final packageDir = _pkgDir();
    return Process.run(Platform.resolvedExecutable, [
      if (Platform.packageConfig != null)
        '--packages=${Platform.packageConfig}',
      compiledCliDill,
      ...args,
    ], workingDirectory: packageDir);
  }

  test('text output matches api.txt', expectApiSummaryClean);

  test(
    'json output matches api.json',
    () => expectApiSummaryClean(format: ApiSummaryFormat.json),
  );

  test(
    'yaml output matches api.yaml',
    () => expectApiSummaryClean(format: ApiSummaryFormat.yaml),
  );

  test(
    'checked-in api.json and api.yaml rehydrate to identical api.txt',
    () async {
      final pkgDir = _pkgDir();
      final expectedText = File(p.join(pkgDir, 'api.txt')).readAsStringSync();
      final jsonRaw = File(p.join(pkgDir, 'api.json')).readAsStringSync();
      final yamlRaw = File(p.join(pkgDir, 'api.yaml')).readAsStringSync();

      final fromJson = ApiSummary.fromJson(
        jsonDecode(jsonRaw) as Map<String, dynamic>,
      );
      final fromYaml = ApiSummary.fromJson(
        jsonDecode(jsonEncode(loadYaml(yamlRaw))) as Map<String, dynamic>,
      );

      expect(fromJson.toString(), equals(expectedText));
      expect(fromYaml.toString(), equals(expectedText));
      expect(fromYaml.toJson(), equals(fromJson.toJson()));

      final livePackage = await apiSummary(pkgDir);
      verifySummaryRoundTrip(livePackage);
    },
  );

  test('expectApiSummaryClean throws when golden file is missing', () async {
    final samplePkgDir = await _createSandboxPackage();
    final missingPath = p.join(samplePkgDir, 'missing_api.txt');
    await expectLater(
      expectApiSummaryClean(
        packagePath: samplePkgDir,
        goldenFilePath: missingPath,
      ),
      throwsA(
        isA<ApiSummaryVerificationException>()
            .having((e) => e.goldenFilePath, 'goldenFilePath', missingPath)
            .having((e) => e.expected, 'expected', isNull)
            .having(
              (e) => e.toString(),
              'toString',
              allOf(
                contains('does not exist'),
                contains('dart run api_summary --output=missing_api.txt'),
              ),
            ),
      ),
    );
  });

  test('expectApiSummaryClean throws with diff on mismatch', () async {
    final samplePkgDir = await _createSandboxPackage();
    File(
      p.join(samplePkgDir, 'api.txt'),
    ).writeAsStringSync('environment:\n  stale_line\n');

    await expectLater(
      expectApiSummaryClean(packagePath: samplePkgDir),
      throwsA(
        isA<ApiSummaryVerificationException>()
            .having((e) => e.expected, 'expected', contains('stale_line'))
            .having(
              (e) => e.toString(),
              'toString',
              allOf(
                contains('does not match the current public API'),
                contains('@@ line 2 @@'),
                contains('-   stale_line'),
                contains('dart run api_summary --write'),
              ),
            ),
      ),
    );
  });

  test('expectApiSummaryClean and --check fail on lib/src/ non-public types '
      'unless allowNonPublicTypes is true', () async {
    final samplePkgDir = await _createSandboxPackage(
      libFiles: {
        'src/internal.dart': 'class HiddenType {}\n',
        'sample_pkg.dart': '''
import 'src/internal.dart';

HiddenType leak() => HiddenType();
''',
      },
    );

    final writeRes = await runCli(['-p', samplePkgDir, '--write']);
    expect(writeRes.exitCode, equals(0), reason: '${writeRes.stderr}');

    await expectLater(
      expectApiSummaryClean(packagePath: samplePkgDir),
      throwsA(
        isA<ApiSummaryVerificationException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('HiddenType'),
            contains('package:sample_pkg/src/internal.dart'),
          ),
        ),
      ),
    );

    final checkRes = await runCli(['-p', samplePkgDir, '--check']);
    expect(checkRes.exitCode, equals(1));
    expect(checkRes.stderr, contains('HiddenType'));

    await expectApiSummaryClean(
      packagePath: samplePkgDir,
      customizer: const ApiSummaryCustomizer(allowNonPublicTypes: true),
    );
  });

  test('expectApiSummaryClean and --check fail when primary barrel references '
      'types only exported by sibling libraries', () async {
    final samplePkgDir = await _createSandboxPackage(
      libFiles: {
        'src/shared_a.dart': 'class SameName {}\n',
        'src/shared_b.dart': 'class SameName {}\n',
        'protocol.dart': '''
export 'src/shared_a.dart';

class ProtocolPacket {}
enum ColumnType { text, integer }
class CallbackArg {}
class RecordFieldType {}
class BoundType {}
class AliasTarget {}
class ExtendedTarget {}
''',
        'sample_pkg.dart': '''
import 'protocol.dart' as proto;
import 'src/shared_b.dart';

export 'src/shared_b.dart';

class ResultSet<T extends proto.BoundType> {
  ResultSet({required proto.ProtocolPacket packet});
  List<proto.ColumnType> get columns => const [];
  (int, {proto.RecordFieldType meta}) readRow(
    void Function(proto.CallbackArg) onItem,
  ) => throw UnimplementedError();
  proto.SameName get wrongSameName => throw UnimplementedError();
  SameName get rightSameName => throw UnimplementedError();
}

typedef LeakedAlias = proto.AliasTarget;

extension LeakedExt on proto.ExtendedTarget {
  int get size => 0;
}
''',
      },
    );

    final writeRes = await runCli(['-p', samplePkgDir, '--write']);
    expect(writeRes.exitCode, equals(0), reason: '${writeRes.stderr}');

    await expectLater(
      expectApiSummaryClean(packagePath: samplePkgDir),
      throwsA(
        isA<ApiSummaryVerificationException>().having(
          (e) => e.message,
          'message',
          allOf([
            contains('package:sample_pkg/sample_pkg.dart'),
            contains('AliasTarget'),
            contains('BoundType'),
            contains('CallbackArg'),
            contains('ColumnType'),
            contains('ExtendedTarget'),
            contains('ProtocolPacket'),
            contains('RecordFieldType'),
            contains('SameName (package:sample_pkg/src/shared_a.dart'),
            contains('package:sample_pkg/protocol.dart'),
            isNot(contains('package:sample_pkg/src/shared_b.dart')),
          ]),
        ),
      ),
    );

    final checkRes = await runCli(['-p', samplePkgDir, '--check']);
    expect(checkRes.exitCode, equals(1));
    expect(checkRes.stderr, contains('ProtocolPacket'));

    await expectApiSummaryClean(
      packagePath: samplePkgDir,
      customizer: const ApiSummaryCustomizer(allowNonPublicTypes: true),
    );
  });

  test('expectApiSummaryClean and --check allow secondary entrypoints to '
      'reference primary barrel types', () async {
    final samplePkgDir = await _createSandboxPackage(
      libFiles: {
        'sample_pkg.dart': '''
class Request {}
typedef Handler = void Function(Request);
''',
        'sample_pkg_io.dart': '''
import 'sample_pkg.dart';

void serve(Handler handler, Request initial) {}
''',
      },
    );

    final writeRes = await runCli(['-p', samplePkgDir, '--write']);
    expect(writeRes.exitCode, equals(0), reason: '${writeRes.stderr}');

    await expectApiSummaryClean(packagePath: samplePkgDir);

    final checkRes = await runCli(['-p', samplePkgDir, '--check']);
    expect(checkRes.exitCode, equals(0), reason: '${checkRes.stderr}');
  });

  test('expectApiSummaryClean reports both non-public types and unexported '
      'primary-barrel sibling types in one pass', () async {
    final samplePkgDir = await _createSandboxPackage(
      libFiles: {
        'src/private_writer.dart': 'class ByteWriter {}\n',
        'protocol.dart': 'class PacketOk {}\n',
        'sample_pkg.dart': '''
import 'protocol.dart';
import 'src/private_writer.dart';

PacketOk send(ByteWriter writer) => PacketOk();
''',
      },
    );

    final writeRes = await runCli(['-p', samplePkgDir, '--write']);
    expect(writeRes.exitCode, equals(0), reason: '${writeRes.stderr}');

    await expectLater(
      expectApiSummaryClean(packagePath: samplePkgDir),
      throwsA(
        isA<ApiSummaryVerificationException>().having(
          (e) => e.message,
          'message',
          allOf(contains('ByteWriter'), contains('PacketOk')),
        ),
      ),
    );
  });

  test(
    'expectApiSummaryClean allows opaque extension types and part files, and '
    'flags exposed representation types across formats',
    () async {
      final samplePkgDir = await _createSandboxPackage(
        libFiles: {
          'src/internal.dart': 'class InternalRep {}\n',
          'src/part_impl.dart': '''
part of '../sample_pkg.dart';

class PartDefined {}
''',
          'protocol.dart': '''
class SiblingRep {}
class LeakySiblingRep {}
''',
          'protocol_extra.dart':
              "export 'protocol.dart' show LeakySiblingRep;\n",
          'sample_pkg.dart': '''
import 'protocol.dart';
import 'src/internal.dart';

part 'src/part_impl.dart';

extension type SafeInternal._(InternalRep _rep) {
  factory SafeInternal.create() => SafeInternal._(InternalRep());
  int get id => 0;
}

extension type SafeSibling._(SiblingRep _rep) {
  factory SafeSibling.create() => SafeSibling._(SiblingRep());
  PartDefined get fromPart => PartDefined();
}
''',
        },
      );

      final writeJson = await runCli([
        '-p',
        samplePkgDir,
        '--write',
        '--format=json',
      ]);
      expect(writeJson.exitCode, equals(0), reason: '${writeJson.stderr}');
      await expectApiSummaryClean(
        packagePath: samplePkgDir,
        format: ApiSummaryFormat.json,
      );

      File(p.join(samplePkgDir, 'lib', 'sample_pkg.dart')).writeAsStringSync('''
import 'protocol.dart';
import 'src/internal.dart';

part 'src/part_impl.dart';

extension type SafeInternal._(InternalRep _rep) {
  int get id => 0;
}

extension type LeakyHandle(LeakySiblingRep rep) {}
''');

      await expectLater(
        expectApiSummaryClean(
          packagePath: samplePkgDir,
          format: ApiSummaryFormat.json,
        ),
        throwsA(
          isA<ApiSummaryVerificationException>().having(
            (e) => e.message,
            'message',
            allOf([
              contains(
                'LeakySiblingRep (package:sample_pkg/protocol.dart, '
                'exported by package:sample_pkg/protocol_extra.dart)',
              ),
              isNot(contains('InternalRep')),
              isNot(contains('PartDefined')),
            ]),
          ),
        ),
      );
    },
  );

  test(
    'packages without a primary barrel allow cross-entrypoint types',
    () async {
      final samplePkgDir = await _createSandboxPackage(
        libFiles: {
          'core.dart': 'class CoreType {}\n',
          'io.dart': '''
import 'core.dart';

void serve(CoreType value) {}
''',
        },
      );

      final writeRes = await runCli(['-p', samplePkgDir, '--write']);
      expect(writeRes.exitCode, equals(0), reason: '${writeRes.stderr}');
      await expectApiSummaryClean(packagePath: samplePkgDir);
    },
  );

  test('CLI --write and --check round-trip in sandbox package', () async {
    final samplePkgDir = await _createSandboxPackage();

    // 1. --check fails with exit code 1 before api.txt exists
    final checkMissing = await runCli(['-p', samplePkgDir, '--check']);
    expect(checkMissing.exitCode, equals(1));
    expect(checkMissing.stderr, contains('does not exist'));
    expect(checkMissing.stderr, contains('dart run api_summary --write'));

    // 2. --write creates api.txt
    final writeRes = await runCli(['-p', samplePkgDir, '--write']);
    expect(writeRes.exitCode, equals(0), reason: '${writeRes.stderr}');
    final generatedFile = File(p.join(samplePkgDir, 'api.txt'));
    expect(generatedFile.existsSync(), isTrue);
    expect(
      generatedFile.readAsStringSync(),
      contains('add (function: int Function(int, int))'),
    );

    // 3. --check now succeeds with exit code 0
    final checkClean = await runCli(['-p', samplePkgDir, '--check']);
    expect(checkClean.exitCode, equals(0), reason: '${checkClean.stderr}');

    // 4. Relative -o with -p resolves relative to packagePath for writing
    final writeCustom = await runCli([
      '-p',
      samplePkgDir,
      '-o',
      'custom_api.txt',
    ]);
    expect(writeCustom.exitCode, equals(0), reason: '${writeCustom.stderr}');
    expect(File(p.join(samplePkgDir, 'custom_api.txt')).existsSync(), isTrue);

    // 5. Mutually exclusive flag combinations exit with code 64
    for (final (args, expectedMessage) in [
      (
        ['-p', samplePkgDir, '--write', '--check'],
        'Cannot specify both --write and --check.',
      ),
      (
        ['-p', samplePkgDir, '--write', '-o', 'custom_api.txt'],
        'Cannot specify both --write and --output.',
      ),
      (
        ['-p', samplePkgDir, '--check', '-o', 'custom_api.txt'],
        'Cannot specify both --check and --output.',
      ),
      (
        ['some_positional_arg'],
        'Unexpected positional arguments: "some_positional_arg".',
      ),
    ]) {
      final res = await runCli(args);
      expect(res.exitCode, equals(64), reason: 'Args: $args');
      expect(res.stderr, contains(expectedMessage), reason: 'Args: $args');
    }
  });

  test('throws ArgumentError on missing pubspec.yaml', () async {
    await expectLater(
      apiSummary('/non_existent_directory_12345'),
      throwsArgumentError,
    );
  });

  test('exits with code 64 on invalid arguments', () async {
    final result = await runCli(['--invalid-option']);

    expect(result.exitCode, equals(64));
    expect(result.stderr, contains('Usage: api_summary'));
  });

  test('exits with code 64 on invalid pubspec.yaml', () async {
    await d.file('pubspec.yaml', 'not_a_map').create();

    final result = await runCli(['-p', d.sandbox]);

    expect(result.exitCode, equals(64));
    expect(result.stderr, contains('Failed to parse pubspec.yaml'));
  });

  test(
    'exits with code 64 when no analysis context is found (missing lib/)',
    () async {
      await d.file('pubspec.yaml', 'name: foo\n').create();

      final result = await runCli(['-p', d.sandbox]);

      expect(result.exitCode, equals(64));
      expect(result.stderr, contains('No "lib" directory found'));
    },
  );
}

Future<String> _createSandboxPackage({
  Map<String, String> libFiles = const {
    'sample_pkg.dart': 'int add(int a, int b) => a + b;\n',
  },
}) async {
  final pkgDir = p.join(d.sandbox, 'pkg');
  await d.dir('pkg', [
    d.file('pubspec.yaml', 'name: sample_pkg\nenvironment:\n  sdk: ^3.12.0\n'),
    d.dir('.dart_tool', [
      d.file(
        'package_config.json',
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'sample_pkg',
              'rootUri': '../',
              'packageUri': 'lib/',
              'languageVersion': '3.12',
            },
          ],
        }),
      ),
    ]),
  ]).create();
  for (final MapEntry(:key, :value) in libFiles.entries) {
    final file = File(p.join(pkgDir, 'lib', key));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(value);
  }
  return pkgDir;
}

// Dynamically locate the api_summary package root
String _pkgDir() {
  var packageDir = p.normalize(p.absolute(Directory.current.path));
  if (!_isApiSummaryDir(packageDir)) {
    for (final dir in ['pkgs', 'pkg']) {
      final candidate = p.join(packageDir, dir, 'api_summary');
      if (_isApiSummaryDir(candidate)) {
        packageDir = candidate;
        break;
      }
    }
  }

  return packageDir;
}

bool _isApiSummaryDir(String dir) {
  final pubspec = File(p.join(dir, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return false;
  return pubspec.readAsStringSync().contains('name: api_summary');
}
