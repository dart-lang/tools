# Benchmark Harness Modernization - Implementation Backlog

This file tracks the active implementation tasks derived from the comprehensive architectural review in [agent_analysis.md](file:///Users/kevmoo/github/tools/pkgs/benchmark_harness/docs/agent_analysis.md).

---

## 🚀 Batch 1: Stability, Safety, & Namespacing

These tasks address critical runtime crashes, protect core mathematical algorithms against invalid configurations, and secure compile-time flags from global namespace pollution.

### [x] Task 1: Fix legacy benchmark `--json` crash (`BUG-01`)
- **Impact**: P1 (Critical)
- **Files to Modify**:
  - [lib/src/bench_command/compile_and_run.dart](file:///Users/kevmoo/github/tools/pkgs/benchmark_harness/lib/src/bench_command/compile_and_run.dart)
- **Requirements**:
  - Detect if the target file is legacy (using `!_hasBenchmarksDeclaration(target)`).
  - When executing a legacy target under `--json`, do **not** pass `-Djson=true` or `--json` to the compiler/runtime subprocesses.
  - Intercept the standard stdout stream of the legacy process (which outputs in standard `MyBenchmark(RunTime): 123.45 us.` format).
  - Parse this text output line-by-line using the RegExp:
    ```dart
    final regex = RegExp(r'^(.+?)\((.+?)\):\s+([\d.]+)\s*(.*)$');
    ```
  - Dynamically assemble the standard JSON results map inside `compileAndRun` to match the schema expected by the orchestrator.
- **Verification**:
  - Verify that `dart run benchmark_harness:bench --json example/template.dart` runs and outputs valid aggregated JSON without throwing any `FormatException`.

### [x] Task 2: Enforce mathematical constraints in `RunnerConfig` (`BUG-02`)
- **Impact**: P2 (High)
- **Files to Modify**:
  - [lib/src/runner.dart](file:///Users/kevmoo/github/tools/pkgs/benchmark_harness/lib/src/runner.dart)
- **Requirements**:
  - Add explicit assertions in the `RunnerConfig` constructor to prevent division-by-zero, out-of-bounds indexing, or infinite loops on bad custom parameters:
    ```dart
    assert(maxSamples >= 4, 'maxSamples must be at least 4');
    assert(windowSize >= 2, 'windowSize must be at least 2');
    assert(stabilityRequired > 0, 'stabilityRequired must be positive');
    ```
- **Verification**:
  - Run existing unit tests (`dart test`) and add a test case in `test/modern_api_test.dart` confirming that instantiating an invalid `RunnerConfig` throws an `AssertionError`.

### [x] Task 3: Namespace generic compile-time environment flags (`ARCH-01`)
- **Impact**: P2 (High)
- **Files to Modify**:
  - [lib/src/runner.dart](file:///Users/kevmoo/github/tools/pkgs/benchmark_harness/lib/src/runner.dart)
  - [lib/src/bench_command/compile_and_run.dart](file:///Users/kevmoo/github/tools/pkgs/benchmark_harness/lib/src/bench_command/compile_and_run.dart)
- **Requirements**:
  - Rename `validate` to `benchmark_harness.validate` in the `bool.fromEnvironment` calls in `runner.dart`.
  - Rename `force-run` to `benchmark_harness.force_run` in `runner.dart`.
  - Update the CLI compile options in `compile_and_run.dart` to supply the namespaced defines:
    - Change `-Dvalidate=true` to `-Dbenchmark_harness.validate=true`.
    - Change `-Dforce-run=true` to `-Dbenchmark_harness.force_run=true`.
- **Verification**:
  - Run the bench command validation mode and verify it functions exactly as expected without regressions.

---

## 🏛️ Batch 2: Architectural Integrity

These tasks focus on modularizing the codebase to improve maintainability, keep files focused on a single responsibility, and support deep statistical testing.

### [x] Task 4: Extract KBSSD mathematical functions (`ARCH-02`)
- **Impact**: P3 (Medium)
- **Files to Modify / Create**:
  - Create `lib/src/kbssd_math.dart`
  - Modify [lib/src/runner.dart](file:///Users/kevmoo/github/tools/pkgs/benchmark_harness/lib/src/runner.dart)
- **Requirements**:
  - Move the pure statistical helper methods out of `BenchmarkRunner`:
    - `_calculateMAD`
    - `_trimWindow`
    - `_estimateSigma`
    - `_calculateMMD`
    - `_checkSEM`
  - Define them as package-private top-level functions in `lib/src/kbssd_math.dart`.
  - Update `BenchmarkRunner` to delegate to the new functions.
- **Verification**:
  - Confirm `dart analyze` is clean and all existing tests pass perfectly.
  - (Optional) Add unit tests in `test/kbssd_math_test.dart` verifying the algorithms directly against known static input/output datasets.

### [x] Task 5: Support custom compiler/runner flags (`DX-01`)
- **Impact**: P3 (Low)
- **Files to Modify**:
  - [lib/src/bench_command/compile_and_run.dart](file:///Users/kevmoo/github/tools/pkgs/benchmark_harness/lib/src/bench_command/compile_and_run.dart)
  - [lib/src/bench_command/bench_options.dart](file:///Users/kevmoo/github/tools/pkgs/benchmark_harness/lib/src/bench_command/bench_options.dart)
- **Requirements**:
  - Implement CLI argument handling to allow users to specify custom compilation and runtime flags to be forwarded to the runner subprocesses.
- **Verification**:
  - Verify custom compiler flags are successfully passed down and accepted.
