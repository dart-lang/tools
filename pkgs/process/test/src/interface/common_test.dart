// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';
import 'package:process/src/interface/common.dart';
import 'package:test/test.dart';

void main() {
  group('getExecutablePath', () {
    late FileSystem fs;
    late Directory workingDir, dir1, dir2, dir3;

    void initialize(FileSystemStyle style) {
      setUp(() {
        fs = MemoryFileSystem(style: style);
        workingDir = fs.systemTempDirectory.createTempSync('work_dir_');
        dir1 = fs.systemTempDirectory.createTempSync('dir1_');
        dir2 = fs.systemTempDirectory.createTempSync('dir2_');
        dir3 = fs.systemTempDirectory.createTempSync('dir3_');
      });
    }

    tearDown(() {
      for (final Directory directory in <Directory>[
        workingDir,
        dir1,
        dir2,
        dir3
      ]) {
        directory.deleteSync(recursive: true);
      }
    });

    group('on windows', () {
      late Platform platform;

      initialize(FileSystemStyle.windows);

      setUp(() {
        platform = FakePlatform(
          operatingSystem: 'windows',
          environment: <String, String>{
            'PATH': '${dir1.path};${dir2.path}',
            'PATHEXT': '.exe;.bat'
          },
        );
      });

      test('absolute', () {
        String command = fs.path.join(dir3.path, 'bla.exe');
        final String expectedPath = command;
        fs.file(command).createSync();

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);

        command = fs.path.withoutExtension(command);
        executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('in path', () {
        String command = 'bla.exe';
        final String expectedPath = fs.path.join(dir2.path, command);
        fs.file(expectedPath).createSync();

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);

        command = fs.path.withoutExtension(command);
        executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('in path multiple times', () {
        String command = 'bla.exe';
        final String expectedPath = fs.path.join(dir1.path, command);
        final String wrongPath = fs.path.join(dir2.path, command);
        fs.file(expectedPath).createSync();
        fs.file(wrongPath).createSync();

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);

        command = fs.path.withoutExtension(command);
        executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('in subdir of work dir', () {
        String command = fs.path.join('.', 'foo', 'bla.exe');
        final String expectedPath = fs.path.join(workingDir.path, command);
        fs.file(expectedPath).createSync(recursive: true);

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);

        command = fs.path.withoutExtension(command);
        executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('in work dir', () {
        String command = fs.path.join('.', 'bla.exe');
        final String expectedPath = fs.path.join(workingDir.path, command);
        final String wrongPath = fs.path.join(dir2.path, command);
        fs.file(expectedPath).createSync();
        fs.file(wrongPath).createSync();

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);

        command = fs.path.withoutExtension(command);
        executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('with multiple extensions', () {
        const String command = 'foo';
        final String expectedPath = fs.path.join(dir1.path, '$command.exe');
        final String wrongPath1 = fs.path.join(dir1.path, '$command.bat');
        final String wrongPath2 = fs.path.join(dir2.path, '$command.exe');
        fs.file(expectedPath).createSync();
        fs.file(wrongPath1).createSync();
        fs.file(wrongPath2).createSync();

        final String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('not found', () {
        const String command = 'foo.exe';

        final String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        expect(executablePath, isNull);
      });

      test('not found with throwOnFailure throws exception with match state',
          () {
        const String command = 'foo.exe';
        expect(
            () => getExecutablePath(
                  command,
                  workingDir.path,
                  platform: platform,
                  fs: fs,
                  throwOnFailure: true,
                ),
            throwsA(isA<ProcessPackageExecutableNotFoundException>()
                .having(
                    (ProcessPackageExecutableNotFoundException
                            notFoundException) =>
                        notFoundException.candidates,
                    'candidates',
                    isEmpty)
                .having(
                    (ProcessPackageExecutableNotFoundException
                            notFoundException) =>
                        notFoundException.workingDirectory,
                    'workingDirectory',
                    equals(workingDir.path))
                .having(
                    (ProcessPackageExecutableNotFoundException
                            notFoundException) =>
                        notFoundException.toString(),
                    'toString',
                    contains(
                        '  Working Directory: C:\\.tmp_rand0\\work_dir_rand0\n'
                        '  Search Path:\n'
                        '    C:\\.tmp_rand0\\dir1_rand0\n'
                        '    C:\\.tmp_rand0\\dir2_rand0\n'))));
      });

      test('with absolute path when currentDirectory getter throws', () {
        final FileSystem fsNoCwd = MemoryFileSystemNoCwd(fs);
        final String command = fs.path.join(dir3.path, 'bla.exe');
        final String expectedPath = command;
        fs.file(command).createSync();

        final String? executablePath = getExecutablePath(
          command,
          null,
          platform: platform,
          fs: fsNoCwd,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('with relative path when currentDirectory getter throws', () {
        final FileSystem fsNoCwd = MemoryFileSystemNoCwd(fs);
        final String command = fs.path.join('.', 'bla.exe');

        final String? executablePath = getExecutablePath(
          command,
          null,
          platform: platform,
          fs: fsNoCwd,
        );
        expect(executablePath, isNull);
      });
    });

    group('on Linux', () {
      late Platform platform;

      initialize(FileSystemStyle.posix);

      setUp(() {
        platform = FakePlatform(
            operatingSystem: 'linux',
            environment: <String, String>{'PATH': '${dir1.path}:${dir2.path}'});
      });

      test('absolute', () {
        final String command = fs.path.join(dir3.path, 'bla');
        final String expectedPath = command;
        final String wrongPath = fs.path.join(dir3.path, 'bla.bat');
        fs.file(command).createSync();
        fs.file(wrongPath).createSync();

        final String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('in path multiple times', () {
        const String command = 'xxx';
        final String expectedPath = fs.path.join(dir1.path, command);
        final String wrongPath = fs.path.join(dir2.path, command);
        fs.file(expectedPath).createSync();
        fs.file(wrongPath).createSync();

        final String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('not found', () {
        const String command = 'foo';

        final String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        expect(executablePath, isNull);
      });

      test('not found with throwOnFailure throws exception with match state',
          () {
        const String command = 'foo';
        expect(
            () => getExecutablePath(
                  command,
                  workingDir.path,
                  platform: platform,
                  fs: fs,
                  throwOnFailure: true,
                ),
            throwsA(isA<ProcessPackageExecutableNotFoundException>()
                .having(
                    (ProcessPackageExecutableNotFoundException
                            notFoundException) =>
                        notFoundException.candidates,
                    'candidates',
                    isEmpty)
                .having(
                    (ProcessPackageExecutableNotFoundException
                            notFoundException) =>
                        notFoundException.workingDirectory,
                    'workingDirectory',
                    equals(workingDir.path))
                .having(
                    (ProcessPackageExecutableNotFoundException
                            notFoundException) =>
                        notFoundException.toString(),
                    'toString',
                    contains('  Working Directory: /.tmp_rand0/work_dir_rand0\n'
                        '  Search Path:\n'
                        '    /.tmp_rand0/dir1_rand0\n'
                        '    /.tmp_rand0/dir2_rand0\n'))));
      });
    });
  });
  group('Real Filesystem', () {
    // These tests don't use the memory filesystem because Dart can't modify file
    // executable permissions, so we have to create them with actual commands.

    late Platform platform;
    late Directory tmpDir;
    late Directory pathDir1;
    late Directory pathDir2;
    late Directory pathDir3;
    late Directory pathDir4;
    late Directory pathDir5;
    late File command1;
    late File command2;
    late File command3;
    late File command4;
    late File command5;
    const Platform localPlatform = LocalPlatform();
    late FileSystem fs;

    setUp(() {
      fs = const LocalFileSystem();
      tmpDir = fs.systemTempDirectory.createTempSync();
      pathDir1 = tmpDir.childDirectory('path1')..createSync();
      pathDir2 = tmpDir.childDirectory('path2')..createSync();
      pathDir3 = tmpDir.childDirectory('path3')..createSync();
      pathDir4 = tmpDir.childDirectory('path4')..createSync();
      pathDir5 = tmpDir.childDirectory('path5')..createSync();
      command1 = pathDir1.childFile('command')..createSync();
      command2 = pathDir2.childFile('command')..createSync();
      command3 = pathDir3.childFile('command')..createSync();
      command4 = pathDir4.childFile('command')..createSync();
      command5 = pathDir5.childFile('command')..createSync();
      platform = FakePlatform(
        operatingSystem: localPlatform.operatingSystem,
        environment: <String, String>{
          'PATH': <Directory>[
            pathDir1,
            pathDir2,
            pathDir3,
            pathDir4,
            pathDir5,
          ].map<String>((Directory dir) => dir.absolute.path).join(':'),
        },
      );
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('Only returns executables in PATH', () {
      if (localPlatform.isWindows) {
        // Windows doesn't check for executable-ness, and we can't run 'chmod'
        // on Windows anyhow.
        return;
      }

      // Make the second command in the path executable, but not the first.
      // No executable permissions
      io.Process.runSync('chmod', <String>['0644', '--', command1.path]);
      // Only group executable permissions
      io.Process.runSync('chmod', <String>['0645', '--', command2.path]);
      // Only other executable permissions
      io.Process.runSync('chmod', <String>['0654', '--', command3.path]);
      // All executable permissions, but not readable
      io.Process.runSync('chmod', <String>['0311', '--', command4.path]);
      // All executable permissions
      io.Process.runSync('chmod', <String>['0755', '--', command5.path]);

      final String? executablePath = getExecutablePath(
        'command',
        tmpDir.path,
        platform: platform,
        fs: fs,
      );

      // Make sure that the path returned is for the last command, since that
      // one comes last in the PATH, but is the only one executable by the
      // user.
      _expectSamePath(executablePath, command5.absolute.path);
    });

    test(
        'Test that finding non-executable paths throws with proper information',
        () {
      if (localPlatform.isWindows) {
        // Windows doesn't check for executable-ness, and we can't run 'chmod'
        // on Windows anyhow.
        return;
      }

      // Make the second command in the path executable, but not the first.
      // No executable permissions
      io.Process.runSync('chmod', <String>['0644', '--', command1.path]);
      // Only group executable permissions
      io.Process.runSync('chmod', <String>['0645', '--', command2.path]);
      // Only other executable permissions
      io.Process.runSync('chmod', <String>['0654', '--', command3.path]);
      // All executable permissions, but not readable
      io.Process.runSync('chmod', <String>['0311', '--', command4.path]);

      expect(
          () => getExecutablePath(
                'command',
                tmpDir.path,
                platform: platform,
                fs: fs,
                throwOnFailure: true,
              ),
          throwsA(isA<ProcessPackageExecutableNotFoundException>()
              .having(
                  (ProcessPackageExecutableNotFoundException
                          notFoundException) =>
                      notFoundException.candidates,
                  'candidates',
                  equals(<String>[
                    '${tmpDir.path}/path1/command',
                    '${tmpDir.path}/path2/command',
                    '${tmpDir.path}/path3/command',
                    '${tmpDir.path}/path4/command',
                    '${tmpDir.path}/path5/command',
                  ]))
              .having(
                  (ProcessPackageExecutableNotFoundException
                          notFoundException) =>
                      notFoundException.toString(),
                  'toString',
                  contains(
                      'ProcessPackageExecutableNotFoundException: Found candidates, but lacked sufficient permissions to execute "command".\n'
                      '  Command: command\n'
                      '  Working Directory: ${tmpDir.path}\n'
                      '  Candidates:\n'
                      '    ${tmpDir.path}/path1/command\n'
                      '    ${tmpDir.path}/path2/command\n'
                      '    ${tmpDir.path}/path3/command\n'
                      '    ${tmpDir.path}/path4/command\n'
                      '    ${tmpDir.path}/path5/command\n'
                      '  Search Path:\n'
                      '    ${tmpDir.path}/path1\n'
                      '    ${tmpDir.path}/path2\n'
                      '    ${tmpDir.path}/path3\n'
                      '    ${tmpDir.path}/path4\n'
                      '    ${tmpDir.path}/path5\n'))));
    });

    test('Test that finding no executable paths throws with proper information',
        () {
      if (localPlatform.isWindows) {
        // Windows doesn't check for executable-ness, and we can't run 'chmod'
        // on Windows anyhow.
        return;
      }

      expect(
          () => getExecutablePath(
                'non-existent-command',
                tmpDir.path,
                platform: platform,
                fs: fs,
                throwOnFailure: true,
              ),
          throwsA(isA<ProcessPackageExecutableNotFoundException>()
              .having(
                  (ProcessPackageExecutableNotFoundException
                          notFoundException) =>
                      notFoundException.candidates,
                  'candidates',
                  isEmpty)
              .having(
                  (ProcessPackageExecutableNotFoundException
                          notFoundException) =>
                      notFoundException.toString(),
                  'toString',
                  contains(
                      'ProcessPackageExecutableNotFoundException: Failed to find "non-existent-command" in the search path.\n'
                      '  Command: non-existent-command\n'
                      '  Working Directory: ${tmpDir.path}\n'
                      '  Search Path:\n'
                      '    ${tmpDir.path}/path1\n'
                      '    ${tmpDir.path}/path2\n'
                      '    ${tmpDir.path}/path3\n'
                      '    ${tmpDir.path}/path4\n'
                      '    ${tmpDir.path}/path5\n'))));
    });

    group('can actually execute files', () {
      void testCompileAndExecute(File mainFile) {
        final localProcessManager = LocalProcessManager();
        final exePath = '${mainFile.path}.exe';
        // Create an executable we can actually run.
        expect(
            localProcessManager.runSync([
              io.Platform.resolvedExecutable,
              'compile',
              'exe',
              mainFile.path,
              '-o',
              exePath
            ]).exitCode,
            0);

        for (final runInShell in const [true, false]) {
          final result =
              localProcessManager.runSync([exePath], runInShell: runInShell);
          expect(result.exitCode, 0,
              reason: 'runInShell: $runInShell\nstdout: ${result.stdout}\n'
                  'stderr: ${result.stderr}');
          expect(result.stdout, contains('hello'));
        }
      }

      test('with spaces in the command name', () {
        final dir = tmpDir.childDirectory('the path');
        final main = dir.childFile('main.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('''
void main() {
  print('hello');
}''');
        testCompileAndExecute(main);
      });

      test('with parenthesis in the command name', () async {
        final dir = tmpDir.childDirectory('theP()ath');
        final main = dir.childFile('main.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('''
void main() {
  print('hello');
}''');
        testCompileAndExecute(main);
      },
          skip: io.Platform.isWindows
              ? 'https://github.com/dart-lang/tools/issues/2139'
              : null);

      test('with spaces and parenthesis in the command name', () async {
        final dir = tmpDir.childDirectory('the P()ath');
        final main = dir.childFile('main.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('''
void main() {
  print('hello');
}''');
        testCompileAndExecute(main);
      });

      test('with spaces inside parenthesis in the command name', () async {
        final dir = tmpDir.childDirectory('the P( )ath');
        final main = dir.childFile('main.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('''
void main() {
  print('hello');
}''');
        testCompileAndExecute(main);
      });
    });
  });
}

void _expectSamePath(String? actual, String? expected) {
  expect(actual, isNotNull);
  expect(actual!.toLowerCase(), expected!.toLowerCase());
}

class MemoryFileSystemNoCwd extends ForwardingFileSystem {
  MemoryFileSystemNoCwd(super.delegate);

  @override
  Directory get currentDirectory {
    throw const FileSystemException('Access denied');
  }
}
