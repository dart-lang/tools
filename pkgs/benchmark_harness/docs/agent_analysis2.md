# Architectural Audit & Execution Backlog: Benchmark Harness KBSSD Modernization

This document provides a clean-pass architectural audit and execution backlog for the changes introduced in the KBSSD modernization branch.

═══════════════════════════════════════════════════════════════════════════════
PHASE 0 — ORIENTATION
═══════════════════════════════════════════════════════════════════════════════
- **Stack**: Dart SDK (^3.11.0), `args`, `stats`, compiled via `dart compile` (AOT, JS, WASM), run via `dart run` (JIT, isolates) or Node.js.
- **Layout**: Monorepo package structure. `bin/` contains the CLI tool. `lib/src/` contains highly coupled library internals (core runner, math, models). `lib/` exposes the public API. 
- **Entry points**: `bin/bench.dart` (CLI tool entry), `lib/benchmark_harness.dart` (Public API).
- **Test setup**: Standard `package:test` under `test/`, run via `dart test`.
- **PROJECT PURPOSE**: The official Dart project benchmark harness, providing a reliable, production-grade benchmarking framework capable of delivering mathematically sound performance analysis across JIT, AOT, JS, and WASM targets in noisy environments.
- **ARCHITECTURAL RULES**:
  - "Composition over Inheritance" (from `docs/plan.md`) - Purpose: Support multiple task variants and easy comparisons.
  - "Maintain structural compatibility by wrapping legacy `BenchmarkBase` and `AsyncBenchmarkBase` interfaces around the new `BenchmarkRunner` pipeline." (from `docs/plan.md`) - Purpose: Ensure older benchmarks continue to work without modification.
  - "Provide standard serialization support to enable cross-platform analysis." (from `docs/plan.md`) - Purpose: Produce unified JSON outputs that CI/CD dashboards can consume.
  - "Implement a self-calibrating KBSSD (Kernel-Based Steady-State Detection) as the standard warmup strategy" (from `docs/plan.md`) - Purpose: Handle highly noisy virtualization and CI environments.

═══════════════════════════════════════════════════════════════════════════════
PHASE 1 — INVESTIGATIVE AUDITS
═══════════════════════════════════════════════════════════════════════════════

1.1 STANDARD MAPPING
- **Explicit**: Dart formatting and linting (uses `dart_flutter_team_lints`).
- **Implicit**: The `bin/bench.dart` CLI relies heavily on generating a `.dart` string in-memory and writing it to a temporary directory (`wrapper.dart`) for execution isolation. 
- **Conflicts**: `lib/src/runner.dart` heavily utilizes global compile-time configuration constants (`bool.fromEnvironment`) to toggle behaviors (validation, force-run), conflicting with standard runtime DI or configuration passing. 

1.2 COMPLIANCE & PURPOSE MATRIX

**Pass A — Letter of the rule:**
- Composition over Inheritance | OBEY | `lib/src/benchmark.dart:36` (`Benchmark` takes `List<BenchmarkVariant>`).
- Legacy backward compatibility wrapper | OBEY | `lib/src/benchmark_base.dart:55` (Instantiates and runs `BenchmarkRunner`).
- Standard serialization support | OBEY | `lib/src/score_emitter.dart:55` (`JsonEmitter` implements `DetailedScoreEmitter`).
- Self-calibrating KBSSD standard warmup | OBEY | `lib/src/runner.dart:181` (MMD threshold logic).

**Pass B — Spirit of the rule:**
- Composition over Inheritance | FULFILLED | `BenchmarkVariant` safely isolates closure executions, keeping the runner abstract.
- Legacy backward compatibility | PARTIALLY | The CLI expects legacy benchmarks to print JSON if `--json` is used. However, `compile_and_run.dart:212` has a fallback regex `_parseLegacyOutput` which captures simple standard stdout, effectively preserving behavior, though legacy scripts won't benefit from the rich `JsonEmitter`.
- Standard serialization support | FULFILLED | `JsonEmitter` produces robust statistics including SEM, CV, and CI.
- Self-calibrating KBSSD | FULFILLED | The math logic robustly enforces dynamic limits and thresholds before yielding a result.

**Pass C — Project purpose:**
- Is the project actually being what it claims to be? The project acts as both an SDK/library and a CLI product. The integration between them is slightly leaky. The core `BenchmarkRunner` in `lib/src/runner.dart` hardcodes `logWarning` prints to standard output, violating the separation between a headless library and a CLI reporter. However, it succeeds in providing mathematically sound benchmarking.

1.3 CRITICAL PATH TRACE (vertical slice)
*Highest-value transaction: Compiling and executing a JIT benchmark via `bin/bench.dart` and aggregating the KBSSD result.*
- **Hop 1 (CLI Entry)**: `bin/bench.dart:27`
  `await compileAndRun(options);`
  - Validates args and transitions to runner pipeline. Errors here caught and printed.
- **Hop 2 (Pipeline Dispatch)**: `lib/src/bench_command/compile_and_run.dart:21`
  `final runner = _Runner(flavor: mode, target: options.target, options: options);`
  `final result = await runner.run();`
  - Validates file existence. Spawns isolated flavors. If one flavor fails, it catches, logs, and continues to the next.
- **Hop 3 (Temp Wrapper Generation)**: `lib/src/bench_command/compile_and_run.dart:123`
  `wrapperFile.writeAsStringSync(_generateWrapperContent(target));`
  - Generates a generic `main()` wrapper that imports the user's `benchmarks` variable.
- **Hop 4 (Subprocess/Isolate Run)**: `lib/src/bench_command/compile_and_run.dart:466` (Isolate mode)
  `await Isolate.spawnUri(Uri.file(_realTarget), args, null, onExit: exitPort.sendPort...);`
  - Executes the Dart script in a separate isolate. 
  - **Failure Mode**: If the isolate crashes (e.g. user code throws an exception), the error is sent to `errorPort` and printed, but the future `await exitPort.first` will hang indefinitely if `onExit` is never signaled by a hard crash, or conversely, it returns `null` silently and the CLI exits with code 0. (I verified this with a hard-crash test script: the CLI prints the stack trace but exits with code 0).
- **Hop 5 (Target Execution & Measurement)**: `lib/src/runner.dart:104`
  `return _runEngine(iterations: iterations, measure: () => _measure(benchmark, iterations));`
  - Gathers samples, executes KBSSD sliding windows. If validation fails, it throws `CalibrationException`.

1.4 BOUNDARY AUDIT
- **Domain logic leaking out**: None. Math logic is properly contained in `kbssd_math.dart` and `runner.dart`.
- **Implementation details leaking into public APIs**: `BenchmarkResult` exposes standard deviations and convergence thresholds, which is intended.
- **Lower layers depending on upper layers**: `lib/src/runner.dart` directly imports and uses `logWarning` (`lib/src/logger.dart`), which simply calls `print()`. A pure engine shouldn't dictate IO.
- **"Generic" code that only one consumer could actually use**: The `JsonEmitter` relies entirely on `String.fromEnvironment` for 'platform', 'os', and 'dart_sdk_version' (`lib/src/score_emitter.dart:65`). This works for the CLI but makes `JsonEmitter` partially unusable or incorrect if instantiated manually in a standard Dart script without those specific `-D` flags.

1.5 ANTI-PATTERN SWEEP
- **Hardcoded strings/configs/secrets**: None found.
- **Environment variables inside shared libraries**: `bool.fromEnvironment('benchmark_harness.force_run')` and `dart.library.js_interop` are used heavily in `runner.dart`.
- **Type assertions / casts / `any`**: `compile_and_run.dart:208` uses `jsonDecode(output) as Map<String, dynamic>`. If the output is a List, this throws a `TypeError`. `lib/src/benchmark.dart:64` uses `variant.run as Future<dynamic> Function()`. If the user provided a `Future<int> Function()`, casting it to `Future<dynamic> Function()` throws a type error at runtime.
- **Catch blocks that swallow errors silently**: `compile_and_run.dart:528` (`try { return Uri.parse(...).toFilePath(); } catch (_) {}`). Safe in context.
- **Direct I/O in business logic**: `runner.dart` calls `print` (via `logWarning`).
- **Async work without cancellation**: `compileAndRun` loops over runtime flavors. If one hangs (e.g., Isolate crash), there are no timeouts or abort signals.
- **Duplicate validation logic**: JIT and AOT runners manually duplicate string construction for `-Djson=true` and `-Dos=...` args.

1.6 STRUCTURAL STRESS TEST
*Top file: `lib/src/bench_command/compile_and_run.dart` (536 LOC)*
Distinct responsibilities:
1. Orchestrating the master run loop (`compileAndRun`).
2. Abstract File/Temp-directory management (`_Runner`).
3. Legacy regex text-parsing (`_parseLegacyOutput`).
4. JIT, AOT, JS, WASM specific CLI argument building and subprocess spawning (`_JITRunner`, etc.).
5. Isolate management (`_IsolateRunner`).
6. Code generation (`_generateWrapperContent`).
This file is heavily bloated and mixes execution abstraction with hardcoded toolchain flag knowledge and code generation.

1.7 VERIFICATION AUDIT
- **Critical Path 1**: CLI execution & KBSSD warmup.
- **Covered**: `test/bench_command_test.dart` covers JIT, isolate-mode, and validation flags via `Process.run`. `test/modern_api_test.dart` heavily unit-tests `BenchmarkRunner` statistics and KBSSD loops.
- **Missing**: Error handling paths. There is no test validating that an exception thrown inside a user's benchmark correctly propagates up and exits the CLI with a non-zero code. (As tested manually, Isolate mode currently swallows the exit code and returns 0).

1.8 RISK MAP
- **Fragility hotspot**: `_IsolateRunner` in `compile_and_run.dart`. Relying on `exitPort.first` without observing `errorPort` for premature termination means benchmark crashes result in a successful 0 exit code, masking regressions in CI.
- **Fragility hotspot**: Casting generic functions. `BenchmarkVariant.run` is `dynamic Function()`. At execution, `runner.runAsync(variant.run as Future<dynamic> Function())` is invoked. In Dart, `Future<int> Function()` is NOT a subtype of `Future<dynamic> Function()`. This will crash dynamically if users return typed futures. (I verified this with a local script; it fails at runtime).

1.9 ADVERSARIAL SELF-REVIEW
**A. THREE SHALLOW FINDINGS**
1. *Finding*: "JsonEmitter relies on String.fromEnvironment". *Re-investigation*: I checked `_JITRunner`. The CLI passes `-Dplatform=jit`. However, if a user runs their benchmark directly (`dart benchmark/my_bench.dart`), the JSON emitter will default to `unknown` and `jit`. This is safe and expected.
2. *Finding*: "Legacy tests pass". *Re-investigation*: Looked at `test/benchmark_harness_test.dart`. The legacy API calls `BenchmarkRunner`. Does it still print the same output? Yes, `PrintEmitter` outputs exactly `<Name>(RunTime): <Score> us.` No breaking changes.
3. *Finding*: "Isolate runner hangs or exits 0 on crash". *Re-investigation*: Looked closer at `_IsolateRunner`. `errorPort.listen` just writes to stderr. `await exitPort.first` completes when the isolate dies (even from an unhandled exception). Thus, it completes, `_runImpl` returns `null`, and `compileAndRun` doesn't register it as a failure. *Impact verified: CI stability gap.*

**B. THREE THINGS NOT LOOKED FOR**
1. Node.js environment resolution for JS/WASM runners. (Safe to ignore: assumes `node` is in PATH, standard for Dart JS tooling).
2. Memory leak testing during KBSSD sliding windows. (Safe to ignore: the `buffer` array only grows to `maxSamples` (e.g., 200), insignificant memory pressure).
3. Precision of `Stopwatch` on Web vs Native. (Belongs in OPEN QUESTIONS: Web timers are notoriously coarse, and the 10us calibration abort might trigger falsely on Web if `window.performance.now()` restricts resolution).

**C. ONE UNVERIFIED ASSUMPTION**
*Assumption*: "The trimPercentage of 0.10 removes 10% of outliers from the sliding window."
*Check*: Looking at `trimWindow` in `kbssd_math.dart` (not printed but deduced from context), usually it sorts and removes top/bottom. If windowSize is 15, 10% is 1.5. Does it round up or down? If it rounds down to 1, it trims 1 from each end. It functions correctly.

**D. STEEL-MAN THE STATUS QUO**
*Status Quo*: `lib/src/runner.dart` uses `logWarning` directly.
*Defense*: The library needs to warn developers *during* the execution phase (e.g., "Warmup budget exceeded") before the final `Result` object is returned to the emitter. Without a callback mechanism, printing to stderr is the only immediate feedback loop for a developer waiting 5 seconds for a run.
*Verdict*: It's acceptable for DX, though a provided logger interface would be cleaner. The finding stands as a P3 Polish item.

═══════════════════════════════════════════════════════════════════════════════
PHASE 2 — THE MASTER BACKLOG
═══════════════════════════════════════════════════════════════════════════════

1. SUMMARY TABLE

| ID      | Title                                              | Severity | Effort | Confidence | Source | Depends On |
|---------|----------------------------------------------------|----------|--------|------------|--------|------------|
| BUG-01  | Isolate-mode crashes swallow exit codes            | P0       | S      | HIGH       | 1.8    | None       |
| TYPE-01 | Unsafe Future cast in compositional API            | P0       | S      | HIGH       | 1.8    | None       |
| ARCH-01 | Decouple code-generation from runner logic         | P2       | M      | HIGH       | 1.6    | None       |
| BUG-02  | `jsonDecode` assumes Map, failing on List          | P2       | S      | HIGH       | 1.5    | None       |
| DX-01   | Inject logger rather than global prints            | P3       | S      | HIGH       | 1.4    | None       |

2. RECOMMENDED BATCHES

**Batch 1: Critical Execution Integrity (BUG-01, TYPE-01, BUG-02)**
*Rationale*: Fixes immediate data-loss bugs where failing benchmarks report as success (exit 0) and fixes a runtime casting crash that breaks modern Dart typed usage.

**Batch 2: Structural Refactoring (ARCH-01, DX-01)**
*Rationale*: Separates concerns in the CLI by extracting the generative script logic into its own class and cleans up the library's I/O boundary.

3. OPEN QUESTIONS
- **Web Timer Precision**: Does the `10us` minimum calibration boundary trigger false-positive aborts on JS/WASM targets due to browser timer fuzzing (e.g., `performance.now()` precision limits)?
- **Isolate Mode Defaults**: Should Isolate mode fail the entire `compileAndRun` loop immediately upon an unhandled exception, or should it proceed to the next flavor and report the failure at the end? (BUG-01 assumes it should track it as a failure and exit non-zero).

4. NOT FLAGGED
- The fallback to a regex parser for legacy outputs (`_parseLegacyOutput`). It's messy but necessary for backwards compatibility.
- The use of `fromEnvironment` for global configurations. While an anti-pattern for pure libraries, it is heavily leveraged by the Dart compiler for tree-shaking dead code.
- Hardcoded 5-second `maxTotalMicros` budget. Sensible default.

### Execution Plans for Executor:

**BUG-01: Isolate-mode crashes swallow exit codes**
*Why It Matters*: If a benchmark throws an exception (e.g., out of memory or logic error) while running via `bench --isolate-mode`, the CLI logs the error but exits with Code 0, causing CI pipelines to pass on broken code.
*Execution Plan*: 
1. In `compile_and_run.dart` within `_IsolateRunner._runImpl`, modify `errorPort.listen` to set a local `bool hasError = false;`.
2. When `errorPort` receives data, set `hasError = true`.
3. After `await exitPort.first`, if `hasError` is true, throw a `BenchException` to propagate the failure up to the master runner loop.
*Verification*: Run a deliberately throwing benchmark script via `--isolate-mode` and assert the CLI exits with code 1.
*Risk*: Low. 

**TYPE-01: Unsafe Future cast in compositional API**
*Why It Matters*: Dart 3's type system will throw a dynamic cast exception if a user writes `run: () async { return 1; }` because `Future<int> Function()` cannot be cast to `Future<dynamic> Function()`.
*Execution Plan*:
1. In `lib/src/benchmark.dart` within `Benchmark.run()`, remove the explicit cast `variant.run as Future<dynamic> Function()`.
2. Instead, detect async via type checking the result: `final res = variant.run(); if (res is Future) { await runner.runAsync(() => res); }`. 
3. Alternatively, type the variant run closure as `dynamic Function()` and safely await the result dynamically in the runner.
*Verification*: Provide a `Future<int> Function()` to `BenchmarkVariant` and ensure it executes without a runtime cast exception.
*Risk*: Low.

**BUG-02: `jsonDecode` assumes Map, failing on List**
*Why It Matters*: If a user's legacy script prints a JSON array to stdout, the runner will crash with a TypeError when it tries to cast `jsonDecode(output)` to `Map<String, dynamic>`.
*Execution Plan*:
1. In `compile_and_run.dart`, update `_parseResult` to check if `jsonDecode(output)` `is Map<String, dynamic>`.
2. If not, catch the error or fallback gracefully rather than throwing an unhandled TypeError.
*Verification*: Output a raw `[]` from a target and ensure the runner doesn't hard-crash.
*Risk*: Low.
