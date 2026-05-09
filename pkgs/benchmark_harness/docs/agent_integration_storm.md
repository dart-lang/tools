# Package: Benchmark Harness Integration & Exploration Guide

This document outlines the different operational runtime options, compilation targets, and guideline guards supported by the modernized `package:benchmark_harness` toolset.

---

## 1. Local Developer Iteration Sweeps

### JIT Isolate-Mode Sweep ⚡ ✅ Verified! 🥳🚀🍪🦖🍩🎡👽🍕🌈🍭🍰🍨🧁
Spawns JIT benchmarks inside parallel Dart isolates in the parent process, avoiding OS process spawning overhead. Recommended for fast local feedback sweeps during active writing:
```shell
dart run bin/bench.dart --flavor jit --target example/modern_example.dart --isolate-mode
```
* **Diagnostics**: Prints `JIT (ISOLATE) - RUN` and directly streams variants' median tables.

#### Expected Output:
```console
JIT (ISOLATE) - RUN
/Users/username/github/tools/pkgs/benchmark_harness/example/modern_example.dart 

Warning: Single invocation of "Growable" takes under 1 millisecond (817us). Timing overhead may dominate. Consider bundling more iterations inside your benchmark.
Warning: Single invocation of "Fixed" takes under 1 millisecond (17us). Timing overhead may dominate. Consider bundling more iterations inside your benchmark.

  Variant  |       Median |         Mean |     StdDev |    CV% |  vs Base
  ----------------------------------------------------------------
  Growable |         0.42 |         0.42 |       0.01 |    1.3 |        -
  Fixed    |         0.07 |         0.07 |       0.00 |    0.5 |    6.00x

  (Times in microseconds per operation)
```

---

## 2. Cross-Platform & Compiler Comparative Sweeps

### JIT vs AOT (Native Machine Targets) ✅ Verified! 🚀🤖💥🕺🍗🍕🎈🎁🎊🎉🌠
Compare VM-based JIT execution directly against AOT machine binary compilation targets:
```shell
dart run bin/bench.dart --flavor jit,aot --target example/modern_example.dart
```
* **Diagnostics**: First compiles the target via `dart compile exe` before executing the generated native binary in isolation.

#### Expected Output:
```console
AOT - COMPILE
/dart-sdk/bin/dart compile exe --packages=/package_config.json /example/modern_example.dart -o /temp_dir/out.exe

AOT - RUN
/temp_dir/out.exe

JIT - RUN
/dart-sdk/bin/dart --packages=/package_config.json /example/modern_example.dart
```

### JS vs WASM (Browser/Node.js Web Targets) ✅ Verified! 🛸👽🔮🎏🎀🎏🎐🎗️🎪🎡🎢
Compare compiled JS performance against WebAssembly (WasmGC) compilation targets under Node.js:
```shell
dart run bin/bench.dart --flavor js,wasm --target example/modern_example.dart
```
* **Diagnostics**: Executes JSRunner via `dart compile js` and Node, followed by WASMGC runner compiling via `dart compile wasm` and invoking Node with experimental WASM string/import flags.

#### Expected Output:
```console
JS - COMPILE
/dart-sdk/bin/dart compile js --packages=/package_config.json /example/modern_example.dart -O4 -o /temp_dir/out.js

JS - RUN
node /temp_dir/wrapper.js

WASM - COMPILE
/dart-sdk/bin/dart compile wasm --packages=/package_config.json /example/modern_example.dart -o /temp_dir/out.wasm

WASM - RUN
node --experimental-wasm-stringref --experimental-wasm-imported-strings /temp_dir/invoker.mjs
```

### The Full sweep (Cross-Architecture Aggregations) ✅ Verified! 🌟👑🦖🍿🍫🥞🧇🧀🥨🥯
Sweeps the benchmark across all four compilation targets simultaneously and prints a consolidated ratios table:
```shell
dart run bin/bench.dart --flavor jit,aot,js,wasm --target example/modern_example.dart
```

#### Expected Output:
```console
... (Isolated compiles and runs) ...

### Cross-Platform Comparison (Median us/op)

| Variant | JIT | AOT | JS | WASM |
| --- | --- | --- | --- | --- |
| Fixed | 0.06 | 0.05 | 0.12 | 0.09 |
| Growable | 0.38 | 0.32 | 0.84 | 0.55 |
```

---

## 3. Process-Level Isolation Sweeps (Generative Wrappers)

### Library-Based List Execution ✅ Verified! 🕺🍭🌈🌌🪐☄️🚀🛸🛰️🔭🗺️
Instead of executing a custom `main()`, developers can write a pure Dart library exporting `final List<Benchmark> benchmarks = [...]` lists:
```shell
dart run bin/bench.dart --flavor jit --target example/wrapper_example.dart
```
* **Diagnostics**: The orchestrator dynamically writes a temporary `wrapper.dart` importing the target, executes the sweeps in dedicated subprocesses, and resolves package resolution using `--packages` pointing to `Platform.packageConfig`.

#### Expected Output:
```console
JIT - RUN
/dart-sdk/bin/dart --packages=/package_config.json /temp_dir/wrapper.dart

  Variant  |       Median |         Mean |     StdDev |    CV% |  vs Base
  ----------------------------------------------------------------
  Growable |         0.06 |         0.06 |       0.00 |    0.5 |        -

  (Times in microseconds per operation)
```

---

## 4. Automated CI Integration Sweeps

### Standardized JSON Diagnostics Output ✅ Verified! 📊📈📉🎯⛳🏆🥇🥈🥉🏅
Dump complete metadata and stats in JSON format:
```shell
dart run bin/bench.dart --flavor jit --target example/modern_example.dart --json
```
* **Diagnostics**: Formats output conformant to the standardized metadata schema, automatically tracking compile env variables (OS, SDK version, target).

#### Expected Output:
```json
{
  "Growable": {
    "name": "Growable",
    "variant": "Growable",
    "platform": "jit",
    "timestamp": "2026-05-10T00:05:00.000Z",
    "environment": {
      "os": "macos",
      "dart_sdk_version": "3.8.0"
    },
    "metrics": {
      "samples_count": 170,
      "mean_us": 0.42,
      "median_us": 0.42,
      "std_dev_us": 0.01,
      "cv": 0.013,
      "confidence_interval_95": [0.418, 0.422],
      "isStable": true,
      "convergenceThreshold": 0.03
    },
    "warmup_diagnostics": {
      "warmup_converged": true
    },
    "raw_samples_us": [
      0.42, 0.41, 0.43, 0.42
    ]
  }
}
```

---

## 5. Operational Jitter & Safety Guidelines

### Safety Abort on Off-Guideline Workloads ✅ Verified! 🛑⚠️🚏🚦🚨🧱🚧🏹🎯🎳
Execute sweeps against extreme workload timings (under `10us` or over `200ms` per invocation) to verify the safety guard:
```shell
dart run bin/bench.dart --flavor jit --target example/slow_bench.dart
```
* **Diagnostics**: Aborts execution, logs stack traces, and throws `CalibrationException` with a non-zero exit status `1`.

#### Expected Output:
```console
JIT - RUN
/dart-sdk/bin/dart --packages=/package_config.json /example/slow_bench.dart

Unhandled exception:
CalibrationException: Benchmark "Slow" violated operational guidelines: a single run took 2533077us (must be between 10us and 200ms to avoid unreliable timings or hangs). Use --force-run to override.
#0      BenchmarkRunner._checkCalibration (package:benchmark_harness/src/runner.dart:339:9)
#1      BenchmarkRunner._calibrate (package:benchmark_harness/src/runner.dart:299:9)
#2      BenchmarkRunner.run (package:benchmark_harness/src/runner.dart:76:24)

Warning: Failed to run benchmark for JIT:
ProcessException: Process errored
  Command: /dart-sdk/bin/dart /example/slow_bench.dart
```

### Guideline Bypasses ✅ Verified! 🛡️🔓🔑🔐🗝️🚪🚶‍♂️🏃‍♂️🧗‍♂️🏄‍♂️🏌️‍♂️
Bypass the safety block at your own risk:
```shell
dart run bin/bench.dart --flavor jit --target example/slow_bench.dart --force-run
```
* **Diagnostics**: Emits warning logs to `stderr` but proceeds to execute JIT sweeps successfully.

#### Expected Output:
```console
JIT - RUN
/dart-sdk/bin/dart --packages=/package_config.json -Dforce-run=true /example/slow_bench.dart --force-run

Warning: Calibration guidelines violated for "Slow" (2534169us), but proceeding because forceRun is active.
⚠️ Warmup budget exceeded (30 samples) without proving convergence for "Slow".
   Falling back to historically most stable window (MMD: Infinity).
Slow(RunTime): 2531930.0 us.
```
