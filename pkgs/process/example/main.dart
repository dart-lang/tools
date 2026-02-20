import 'dart:io';

import 'package:process/process.dart';

Future<void> main() async {
  const processManager = LocalProcessManager();

  final executable = Platform.resolvedExecutable;
  if (!processManager.canRun(executable)) {
    stderr.writeln('Unable to run: $executable');
    exitCode = 1;
    return;
  }

  final result = await processManager.run([executable, '--version']);
  stdout.write(result.stdout);
  if (result.exitCode != 0) {
    stderr.writeln('Command failed with exit code ${result.exitCode}.');
    stderr.write(result.stderr);
    exitCode = result.exitCode;
  }
}
