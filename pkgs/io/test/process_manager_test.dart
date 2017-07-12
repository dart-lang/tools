// Copyright 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// TODO: Change to io.dart once these features are published.
import 'package:io/io.dart' hide sharedStdIn;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  StreamController<String> fakeStdIn;
  ProcessManager processManager;
  SharedStdIn sharedStdIn;
  List<String> stdoutLog;
  List<String> stderrLog;

  group('spawn', () {
    setUp(() async {
      fakeStdIn = new StreamController<String>(sync: true);
      sharedStdIn = new SharedStdIn(fakeStdIn.stream.map((s) => s.codeUnits));
      stdoutLog = <String>[];
      stderrLog = <String>[];

      final stdoutController = new StreamController<List<int>>(sync: true);
      stdoutController.stream.map(UTF8.decode).listen(stdoutLog.add);
      final stdout = new IOSink(stdoutController);
      final stderrController = new StreamController<List<int>>(sync: true);
      stderrController.stream.map(UTF8.decode).listen(stderrLog.add);
      final stderr = new IOSink(stderrController);

      processManager = new ProcessManager(
        stdin: sharedStdIn,
        stdout: stdout,
        stderr: stderr,
      );
    });

    test('should output Hello from another process [via stdout]', () async {
      final spawn = await processManager.spawn(
        'dart',
        arguments: [p.join('test', '_files', 'stdout_hello.dart')],
      );
      await spawn.exitCode;
      expect(stdoutLog, ['Hello']);
    });

    test('should output Hello from another process [via stderr]', () async {
      final spawn = await processManager.spawn(
        'dart',
        arguments: [p.join('test', '_files', 'stderr_hello.dart')],
      );
      await spawn.exitCode;
      expect(stderrLog, ['Hello']);
    });

    test('should forward stdin to another process', () async {
      final spawn = await processManager.spawn(
        'dart',
        arguments: [p.join('test', '_files', 'stdin_echo.dart')],
      );
      spawn.stdin.writeln('Ping');
      await spawn.exitCode;
      // TODO: https://github.com/dart-lang/sdk/issues/30119.
      // expect(stdoutLog, ['You said: Ping', '\n']);
      expect(stdoutLog.join(''), contains('You said: Ping'));
    });
  });
}
