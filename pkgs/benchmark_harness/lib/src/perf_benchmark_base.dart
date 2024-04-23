// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'benchmark_base.dart';
import 'score_emitter.dart';

class PerfBenchmarkBase extends BenchmarkBase {
  late final Directory fifoDir;
  late final String perfControlFifo;
  late final RandomAccessFile openedFifo;
  late final String perfControlAck;
  late final RandomAccessFile openedAck;
  late final Process perfProcess;
  late final List<String> perfProcessArgs;

  PerfBenchmarkBase(super.name,
      {ScoreEmitterV2 super.emitter = const PrintEmitterV2()});

  ScoreEmitterV2 get _emitterV2 => emitter as ScoreEmitterV2;

  Future<void> _createFifos() async {
    perfControlFifo = '${fifoDir.path}/perf_control_fifo';
    perfControlAck = '${fifoDir.path}/perf_control_ack';
    for (final path in [perfControlFifo, perfControlAck]) {
      final fifoResult = await Process.run('mkfifo', [path]);
      if (fifoResult.exitCode != 0) {
        throw ProcessException('mkfifo', [path],
            'Cannot create fifo: ${fifoResult.stderr}', fifoResult.exitCode);
      }
    }
  }

  Future<void> _startPerfStat() async {
    await _createFifos();
    perfProcessArgs = [
      'stat',
      '--delay=-1',
      '--control=fifo:$perfControlFifo,$perfControlAck',
      '-x\\t',
      '--pid=$pid',
    ];
    perfProcess = await Process.start('perf', perfProcessArgs);
  }

  void _enablePerf() {
    openedFifo = File(perfControlFifo).openSync(mode: FileMode.writeOnly);
    openedAck = File(perfControlAck).openSync();
    openedFifo.writeStringSync('enable\n');
    _waitForAck();
  }

  Future<void> _stopPerfStat(int totalIterations) async {
    openedFifo.writeStringSync('disable\n');
    openedFifo.closeSync();
    _waitForAck();
    openedAck.closeSync();
    perfProcess.kill(ProcessSignal.sigint);
    unawaited(perfProcess.stdout.drain());
    final lines = await perfProcess.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .toList();
    final exitCode = await perfProcess.exitCode;
    // Exit code from perf is -SIGINT when terminated with SIGINT.
    if (exitCode != 0 && exitCode != -ProcessSignal.sigint.signalNumber) {
      throw ProcessException(
          'perf', perfProcessArgs, lines.join('\n'), exitCode);
    }

    const metrics = {
      'cycles': 'CpuCycles',
      'page-faults': 'MajorPageFaults',
    };
    for (final line in lines) {
      if (line.split('\t')
          case [
            String counter,
            _,
            String event && ('cycles' || 'page-faults'),
            ...
          ]) {
        _emitterV2.emit(name, double.parse(counter) / totalIterations,
            metric: metrics[event]!);
      }
    }
    _emitterV2.emit('$name.totalIterations', totalIterations.toDouble(),
        metric: 'Count');
  }

  /// Measures the score for the benchmark and returns it.
  Future<double> measurePerf() async {
    Measurement result;
    setup();
    try {
      fifoDir = await Directory.systemTemp.createTemp('fifo');
      try {
        // Warmup for at least 100ms. Discard result.
        measureForImpl(warmup, 100);
        await _startPerfStat();
        try {
          _enablePerf();
          // Run the benchmark for at least 2000ms.
          result = measureForImpl(exercise, minimumMeasureDurationMillis);
          await _stopPerfStat(result.totalIterations);
        } catch (_) {
          perfProcess.kill(ProcessSignal.sigkill);
          rethrow;
        }
      } finally {
        await fifoDir.delete(recursive: true);
      }
    } finally {
      teardown();
    }
    return result.score;
  }

  Future<void> reportPerf() async {
    _emitterV2.emit(name, await measurePerf(), unit: 'us.');
  }

  void _waitForAck() {
    // Perf writes 'ack\n\x00' to the acknowledgement fifo.
    const ackLength = 'ack\n\x00'.length;
    var ack = <int>[...openedAck.readSync(ackLength)];
    while (ack.length < ackLength) {
      ack.addAll(openedAck.readSync(ackLength - ack.length));
    }
  }
}
