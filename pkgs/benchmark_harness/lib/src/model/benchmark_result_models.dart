// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Structured data classes representing standard JSON results of the
/// benchmark harness to support strong-typed serialization and comparisons.
library;

import 'dart_environment.dart';

class HostEnvironment {
  final String os;
  final String dartSdkVersion;

  const HostEnvironment({required this.os, required this.dartSdkVersion});

  HostEnvironment.fromDartEnvironment()
    : os = DartEnvironment.os.value,
      dartSdkVersion = DartEnvironment.dartSdkVersion.value;

  factory HostEnvironment.fromJson(Map<String, dynamic> json) {
    return HostEnvironment(
      os: json['os'] as String? ?? 'unknown',
      dartSdkVersion: json['dart_sdk_version'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() => {
    'os': os,
    'dart_sdk_version': dartSdkVersion,
  };
}

class WarmupDiagnostics {
  final bool warmupConverged;

  const WarmupDiagnostics({required this.warmupConverged});

  factory WarmupDiagnostics.fromJson(Map<String, dynamic> json) {
    return WarmupDiagnostics(
      warmupConverged: json['warmup_converged'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {'warmup_converged': warmupConverged};
}

class RunMetrics {
  final int samplesCount;
  final double meanUs;
  final double medianUs;
  final double stdDevUs;
  final double cv;
  final List<double> confidenceInterval95;
  final bool isStable;
  final double convergenceThreshold;

  const RunMetrics({
    required this.samplesCount,
    required this.meanUs,
    required this.medianUs,
    required this.stdDevUs,
    required this.cv,
    required this.confidenceInterval95,
    required this.isStable,
    required this.convergenceThreshold,
  });

  factory RunMetrics.fromJson(Map<String, dynamic> json) {
    return RunMetrics(
      samplesCount: json['samples_count'] as int,
      meanUs: (json['mean_us'] as num).toDouble(),
      medianUs: (json['median_us'] as num).toDouble(),
      stdDevUs: (json['std_dev_us'] as num).toDouble(),
      cv: (json['cv'] as num).toDouble(),
      confidenceInterval95: (json['confidence_interval_95'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      isStable: json['isStable'] as bool? ?? true,
      convergenceThreshold: (json['convergence_threshold'] as num? ?? 0.0)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'samples_count': samplesCount,
    'mean_us': meanUs,
    'median_us': medianUs,
    'std_dev_us': stdDevUs,
    'cv': cv,
    'confidence_interval_95': confidenceInterval95,
    'isStable': isStable,
    'convergence_threshold': convergenceThreshold,
  };
}

class BenchmarkVariantResult {
  final String name;
  final String variant;
  final String platform;
  final DateTime timestamp;
  final HostEnvironment environment;
  final RunMetrics metrics;
  final WarmupDiagnostics warmupDiagnostics;
  final List<double> rawSamplesUs;

  const BenchmarkVariantResult({
    required this.name,
    required this.variant,
    required this.platform,
    required this.timestamp,
    required this.environment,
    required this.metrics,
    required this.warmupDiagnostics,
    required this.rawSamplesUs,
  });

  factory BenchmarkVariantResult.fromJson(Map<String, dynamic> json) {
    return BenchmarkVariantResult(
      name: json['name'] as String,
      variant: json['variant'] as String,
      platform: json['platform'] as String? ?? 'jit',
      timestamp: DateTime.parse(json['timestamp'] as String),
      environment: HostEnvironment.fromJson(
        json['environment'] as Map<String, dynamic>,
      ),
      metrics: RunMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      warmupDiagnostics: WarmupDiagnostics.fromJson(
        json['warmup_diagnostics'] as Map<String, dynamic>,
      ),
      rawSamplesUs: (json['raw_samples_us'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'variant': variant,
    'platform': platform,
    'timestamp': timestamp.toIso8601String(),
    'environment': environment.toJson(),
    'metrics': metrics.toJson(),
    'warmup_diagnostics': warmupDiagnostics.toJson(),
    'raw_samples_us': rawSamplesUs,
  };
}
