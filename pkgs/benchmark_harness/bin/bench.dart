import 'dart:io';

// TODO: cleanup temp directories

Future<void> main(List<String> args) async {
  final mode = args[0];
  final target = args[1];

  await switch (mode) {
    'aot' => _aot(target),
    'jit' => _jit(target),
    'js' => _js(target),
    'wasm' => _wasm(target),
    _ => throw UnimplementedError('Unsupported mode: $mode'),
  };
}

Future<void> _aot(String target) async {
  final outFile = _outputFile('exe');
  await _runProc(Platform.executable, [
    'compile',
    'exe',
    target,
    '-o',
    outFile,
  ]);

  await _runProc(outFile, []);
}

Future<void> _js(String target) async {
  final outFile = _outputFile('js');
  await _runProc(Platform.executable, [
    'compile',
    'js',
    target,
    '-o',
    outFile,
  ]);

  await _runProc('node', [outFile]);
}

Future<void> _wasm(String target) async {
  final tempDirectory = _tempDirectory();
  final outFile = _outputFile('wasm', dir: tempDirectory);
  await _runProc(Platform.executable, [
    'compile',
    'wasm',
    target,
    '-o',
    outFile,
  ]);

  final jsFile = File.fromUri(tempDirectory.uri.resolve('out.js'));
  jsFile.writeAsStringSync(_jsStuff);

  await _runProc('node', [jsFile.path]);
}

Future<void> _jit(String target) async {
  await _runProc(Platform.executable, [target]);
}

Directory _tempDirectory() => Directory.systemTemp
    .createTempSync('bench_${DateTime.now().millisecondsSinceEpoch}_');

String _outputFile(String ext, {Directory? dir}) {
  dir ??= _tempDirectory();
  return dir.uri.resolve('out.$ext').toFilePath();
}

Future<void> _runProc(String executable, List<String> args) async {
  final proc = await Process.start(executable, args,
      mode: ProcessStartMode.inheritStdio);

  final exitCode = await proc.exitCode;

  if (exitCode != 0) {
    throw ProcessException(executable, args, 'Process errored', exitCode);
  }
}

const _jsStuff = r'''
import { readFile } from 'node:fs/promises'; // For async file reading
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Get the current directory name
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const dartModule = await import('./out.mjs');
const {compile, invoke} = dartModule;

const wasmFilePath = join(__dirname, 'out.wasm');
const wasmBytes = await readFile(wasmFilePath); // This returns a Node.js Buffer, which is a Uint8Array.

let compiledApp = await compile(wasmBytes);

let instantiatedApp = await compiledApp.instantiate({});

await instantiatedApp.invokeMain();
''';
