// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'blackhole.dart';
import 'kbssd_math.dart';
import 'logger.dart' if (dart.library.js_interop) 'logger_web.dart';
import 'model/dart_environment.dart';
import 'result.dart';

/// Configuration for the [BenchmarkRunner].
class RunnerConfig {
  /// The target duration for a single sample in microseconds.
  ///
  /// Default is 10,000 us (10 ms).
  final int targetSampleMicros;

  /// The minimum number of samples to collect.
  final int minSamples;

  /// The maximum number of samples to collect if variance is high or during
  /// warmup.
  final int maxSamples;

  /// The maximum total time to spend on a single variant in microseconds.
  final int maxTotalMicros;

  /// The target relative margin of error (as a ratio of the mean).
  ///
  /// If the 95% confidence interval width / mean is greater than this,
  /// the runner will continue taking samples up to [maxSamples].
  final double targetRelativeError;

  /// The size of the past and present sliding windows for KBSSD.
  final int windowSize;

  /// The number of consecutive stable MMD scores required to declare steady
  /// state.
  final int stabilityRequired;

  /// The percentage of extreme values to trim from each window (top and bottom)
  /// before convergence checks.
  final double trimPercentage;

  /// Scale factor multiplied by the cold-buffer relative MAD to get the
  /// convergence threshold.
  final double scaleFactor;

  /// Whether to force running the benchmark even if operational guidelines are
  /// violated.
  final bool forceRun;

  /// Optional custom callback to capture warnings.
  ///
  /// If null, the runner defaults to standard printing / stderr.
  final void Function(String)? logger;

  const RunnerConfig({
    this.targetSampleMicros = 10000,
    this.minSamples = 10,
    this.maxSamples = 200,
    this.maxTotalMicros = 5000000, // 5 seconds
    this.targetRelativeError = 0.05, // 5%
    this.windowSize = 15,
    this.stabilityRequired = 8,
    this.trimPercentage = 0.10,
    this.scaleFactor = 2.0,
    this.forceRun = DartEnvironment.forceRunValue,
    this.logger,
  }) : assert(maxSamples >= 4, 'maxSamples must be at least 4'),
       assert(windowSize >= 2, 'windowSize must be at least 2'),
       assert(stabilityRequired > 0, 'stabilityRequired must be positive');
}

/// A runner that performs adaptive benchmarking of a function.
class BenchmarkRunner {
  final String name;
  final RunnerConfig config;

  BenchmarkRunner(this.name, {this.config = const RunnerConfig()}) {
    Blackhole.preventDCE();
  }

  void _logWarning(String message) {
    final logger = config.logger;
    if (logger != null) {
      logger(message);
    } else {
      logWarning(message);
    }
  }

  /// Runs the [benchmark] function and returns a [BenchmarkResult].
  BenchmarkResult run(dynamic Function() benchmark) {
    const validate = DartEnvironment.validateValue;
    if (validate) {
      final sw = Stopwatch()..start();
      Blackhole.sink = benchmark();
      final elapsed = sw.elapsedMicroseconds;
      if (elapsed < 1) {
        _logWarning(
          'Validation Warning: Benchmark "$name" may be optimized away by '
          'the compiler (took 0us, under 1us). Consider using blackhole() '
          'to prevent dead-code elimination.',
        );
      } else {
        _logWarning(
          'Validation: Benchmark "$name" passed smoke run (took ${elapsed}us).',
        );
      }
      return BenchmarkResult(
        name: name,
        samples: [elapsed.toDouble(), elapsed.toDouble()],
        isStable: true,
        convergenceThreshold: 0.0,
      );
    }
    final iterations = _calibrate(benchmark);
    return _runEngine(
      iterations: iterations,
      measure: () => _measure(benchmark, iterations),
    );
  }

  /// Runs the [benchmark] async function and returns a [BenchmarkResult].
  Future<BenchmarkResult> runAsync(Future<dynamic> Function() benchmark) async {
    const validate = DartEnvironment.validateValue;
    if (validate) {
      final sw = Stopwatch()..start();
      await benchmark();
      final elapsed = sw.elapsedMicroseconds;
      if (elapsed < 1) {
        _logWarning(
          'Validation Warning: Benchmark "$name" may be optimized away by '
          'the compiler (took 0us, under 1us). Consider using blackhole() '
          'to prevent dead-code elimination.',
        );
      } else {
        _logWarning(
          'Validation: Benchmark "$name" passed smoke run (took ${elapsed}us).',
        );
      }
      return BenchmarkResult(
        name: name,
        samples: [elapsed.toDouble(), elapsed.toDouble()],
        isStable: true,
        convergenceThreshold: 0.0,
      );
    }
    final iterations = await _calibrateAsync(benchmark);
    return _runEngineAsync(
      iterations: iterations,
      measure: () => _measureAsync(benchmark, iterations),
    );
  }

  BenchmarkResult _runEngine({
    required int iterations,
    required int Function() measure,
  }) {
    final buffer = <double>[];
    final totalWatch = Stopwatch()..start();
    final windowSize = math.max(
      2,
      math.min(config.windowSize, config.maxSamples ~/ 2),
    );
    final coldBufferSize = windowSize * 2;

    // 1. Fill Cold-Buffer
    while (buffer.length < coldBufferSize) {
      final sampleMicros = measure();
      buffer.add(sampleMicros / iterations);
    }

    // Calculate Dynamic Threshold via MAD of cold buffer
    final coldBuffer = List<double>.from(buffer)..sort();
    final medianIndex = coldBuffer.length ~/ 2;
    final coldMedian = coldBuffer.length.isOdd
        ? coldBuffer[medianIndex]
        : (coldBuffer[medianIndex - 1] + coldBuffer[medianIndex]) / 2.0;
    final coldMAD = calculateMAD(coldBuffer, coldMedian);

    final relativeMAD = coldMedian > 0 ? (coldMAD / coldMedian) : 0.0;
    final convergenceThreshold = relativeMAD > 0
        ? relativeMAD * config.scaleFactor
        : 0.01;

    var stabilityCount = 0;
    var bestMMD = double.infinity;
    var bestSamples = buffer.sublist(buffer.length - windowSize);
    var converged = false;

    // 2. Sliding Window Warmup & Convergence
    while (buffer.length < config.maxSamples) {
      if (totalWatch.elapsedMicroseconds > config.maxTotalMicros) {
        break;
      }

      final sampleMicros = measure();
      buffer.add(sampleMicros / iterations);

      if (buffer.length > coldBufferSize) {
        buffer.removeAt(0);
      }

      final past = trimWindow(
        buffer.sublist(0, windowSize),
        config.trimPercentage,
      );
      final present = trimWindow(
        buffer.sublist(windowSize),
        config.trimPercentage,
      );

      final sigma = estimateSigma(past + present);
      final mmd = calculateMMD(past, present, sigma);

      if (mmd < bestMMD) {
        bestMMD = mmd;
        bestSamples = List.from(present);
      }

      final currentlySteady = mmd < convergenceThreshold || checkSEM(present);
      if (currentlySteady) {
        stabilityCount++;
      } else {
        stabilityCount = 0;
      }

      if (stabilityCount >= config.stabilityRequired) {
        converged = true;
        break;
      }
    }

    final isStable = converged;
    if (!isStable) {
      _logWarning(
        '⚠️ Warmup budget exceeded (${buffer.length} samples) '
        'without proving convergence for "$name".\n'
        '   Falling back to historically best-effort window '
        '(MMD: ${bestMMD.toStringAsFixed(5)}).',
      );
    }

    final measurementSamples = isStable
        ? buffer.sublist(windowSize)
        : bestSamples;

    return BenchmarkResult(
      name: name,
      samples: measurementSamples,
      isStable: isStable,
      convergenceThreshold: convergenceThreshold,
    );
  }

  Future<BenchmarkResult> _runEngineAsync({
    required int iterations,
    required Future<int> Function() measure,
  }) async {
    final buffer = <double>[];
    final totalWatch = Stopwatch()..start();
    final windowSize = math.max(
      2,
      math.min(config.windowSize, config.maxSamples ~/ 2),
    );
    final coldBufferSize = windowSize * 2;

    // 1. Fill Cold-Buffer
    while (buffer.length < coldBufferSize) {
      final sampleMicros = await measure();
      buffer.add(sampleMicros / iterations);
    }

    // Calculate Dynamic Threshold via MAD of cold buffer
    final coldBuffer = List<double>.from(buffer)..sort();
    final medianIndex = coldBuffer.length ~/ 2;
    final coldMedian = coldBuffer.length.isOdd
        ? coldBuffer[medianIndex]
        : (coldBuffer[medianIndex - 1] + coldBuffer[medianIndex]) / 2.0;
    final coldMAD = calculateMAD(coldBuffer, coldMedian);

    final relativeMAD = coldMedian > 0 ? (coldMAD / coldMedian) : 0.0;
    final convergenceThreshold = relativeMAD > 0
        ? relativeMAD * config.scaleFactor
        : 0.01;

    var stabilityCount = 0;
    var bestMMD = double.infinity;
    var bestSamples = buffer.sublist(buffer.length - windowSize);
    var converged = false;

    // 2. Sliding Window Warmup & Convergence
    while (buffer.length < config.maxSamples) {
      if (totalWatch.elapsedMicroseconds > config.maxTotalMicros) {
        break;
      }

      final sampleMicros = await measure();
      buffer.add(sampleMicros / iterations);

      if (buffer.length > coldBufferSize) {
        buffer.removeAt(0);
      }

      final past = trimWindow(
        buffer.sublist(0, windowSize),
        config.trimPercentage,
      );
      final present = trimWindow(
        buffer.sublist(windowSize),
        config.trimPercentage,
      );

      final sigma = estimateSigma(past + present);
      final mmd = calculateMMD(past, present, sigma);

      if (mmd < bestMMD) {
        bestMMD = mmd;
        bestSamples = List.from(present);
      }

      final currentlySteady = mmd < convergenceThreshold || checkSEM(present);
      if (currentlySteady) {
        stabilityCount++;
      } else {
        stabilityCount = 0;
      }

      if (stabilityCount >= config.stabilityRequired) {
        converged = true;
        break;
      }
    }

    final isStable = converged;
    if (!isStable) {
      _logWarning(
        '⚠️ Warmup budget exceeded (${buffer.length} samples) '
        'without proving convergence for "$name".\n'
        '   Falling back to historically best-effort window '
        '(MMD: ${bestMMD.toStringAsFixed(5)}).',
      );
    }

    final measurementSamples = isStable
        ? buffer.sublist(windowSize)
        : bestSamples;

    return BenchmarkResult(
      name: name,
      samples: measurementSamples,
      isStable: isStable,
      convergenceThreshold: convergenceThreshold,
    );
  }

  int _calibrate(dynamic Function() f) {
    var iterations = 1;
    while (true) {
      final elapsed = _measure(f, iterations);
      if (iterations == 1) {
        _checkCalibration(elapsed);
      }
      if (elapsed >= config.targetSampleMicros ~/ 2) {
        return (iterations * (config.targetSampleMicros / elapsed)).ceil();
      }
      iterations *= 2;
      if (iterations > 1000000) return iterations;
    }
  }

  Future<int> _calibrateAsync(Future<dynamic> Function() f) async {
    var iterations = 1;
    while (true) {
      final elapsed = await _measureAsync(f, iterations);
      if (iterations == 1) {
        _checkCalibration(elapsed);
      }
      if (elapsed >= config.targetSampleMicros ~/ 2) {
        return (iterations * (config.targetSampleMicros / elapsed)).ceil();
      }
      iterations *= 2;
      if (iterations > 100000) return iterations;
    }
  }

  void _checkCalibration(int elapsedMicros) {
    if (elapsedMicros < 1000) {
      _logWarning(
        'Warning: Single invocation of "$name" takes under 1 millisecond '
        '(${elapsedMicros}us). Timing overhead may dominate. '
        'Consider bundling more iterations inside your benchmark.',
      );
    }
    if (elapsedMicros < 10 || elapsedMicros > 200000) {
      const isWeb = bool.fromEnvironment('dart.library.js_interop');
      if (isWeb && elapsedMicros == 0) {
        return; // Safe to bypass due to JS timer virtualization
      }
      if (config.forceRun) {
        _logWarning(
          'Warning: Calibration guidelines violated for "$name" '
          '(${elapsedMicros}us), but proceeding because forceRun is active.',
        );
      } else {
        throw CalibrationException(
          'Benchmark "$name" violated operational guidelines: a single run '
          'took ${elapsedMicros}us (must be between 10us and 200ms to avoid '
          'unreliable timings or hangs). Use --force-run to override.',
        );
      }
    }
  }

  int _measure(dynamic Function() f, int iterations) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      Blackhole.sink = f();
    }
    return sw.elapsedMicroseconds;
  }

  Future<int> _measureAsync(
    Future<dynamic> Function() f,
    int iterations,
  ) async {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      Blackhole.sink = await f();
    }
    return sw.elapsedMicroseconds;
  }
}

/// Thrown when a benchmark violates timing or setup operational guidelines.
class CalibrationException implements Exception {
  final String message;
  CalibrationException(this.message);

  @override
  String toString() => 'CalibrationException: $message';
}
