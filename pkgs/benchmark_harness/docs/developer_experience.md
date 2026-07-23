# Developer Experience: Writing & Running Benchmarks

This guide outlines the design patterns, execution models, and verification
steps for developers creating performance benchmarks using the modernized
`package:benchmark_harness` API.

---

## 1. Programming Models

Developers can write benchmarks using either the **Functional Compositional API**
(recommended for lightweight comparisons) or the **Class-Based API**
(recommended for complex setups).

### Option A: Functional Compositional API (`BenchmarkVariant`)

Best for comparing simple, isolated implementations (e.g., different
algorithms or data structures) without the boilerplate of multiple classes.

```dart
import 'package:benchmark_harness/benchmark_harness.dart';

void main() {
  // Define variants using simple top-level functions
  final jsonComparison = Benchmark(
    name: 'JSON Serialization',
    variants: [
      BenchmarkVariant(
        name: 'Map-based',
        run: () => serializeWithMap(testData),
        setup: () => prepareTestData(), // Optional setup code
      ),
      BenchmarkVariant(
        name: 'Record-based',
        run: () => serializeWithRecord(testData),
        setup: () => prepareTestData(),
      ),
    ],
  );

  jsonComparison.report();
}
```

### Option B: Class-Based API (`BenchmarkBase`)

Best when the benchmark requires managing state, complex lifecycles, or
backward compatibility.

```dart
import 'package:benchmark_harness/benchmark_harness.dart';

class ParserBenchmark extends BenchmarkBase {
  ParserBenchmark() : super('Parser Benchmark');

  // Optional: Setup code executed once before calibration/warmup
  @override
  void setup() {
    loadSourceFiles();
  }

  // Required: The simple function that exercises the code under test
  @override
  void run() {
    parseExpression('x + y * z');
  }

  // Optional: Teardown code executed after measurement is complete
  @override
  void teardown() {
    clearCache();
  }
}

void main() {
  ParserBenchmark().report();
}
```

### Option C: Multi-Benchmark Module Pattern (Top-Level `benchmarks` List)

When building complex performance suites, you often want to group multiple related benchmarks in a single file, but have the `bench` CLI tool execute and measure **each benchmark in complete isolation** (e.g. in its own compiler invocation or Dart isolate) to prevent VM warmup or garbage collection interference.

To support this, the orchestrator automatically detects if a file declares a top-level **`benchmarks`** variable of type `List<Benchmark>`. 

If detected, the CLI spawner dynamically generates isolated execution wrappers for each entry in your `benchmarks` list, compiling and measuring them independently.

#### Target File (`benchmark/json_suite.dart`)
```dart
import 'package:benchmark_harness/benchmark_harness.dart';

// Expose a top-level List<Benchmark> variable
final List<Benchmark> benchmarks = [
  Benchmark(
    title: 'JSON Encoding',
    variants: [
      BenchmarkVariant(name: 'Map', run: () => encodeMap()),
      BenchmarkVariant(name: 'List', run: () => encodeList()),
    ],
  ),
  Benchmark(
    title: 'JSON Decoding',
    variants: [
      BenchmarkVariant(name: 'Map', run: () => decodeMap()),
      BenchmarkVariant(name: 'List', run: () => decodeList()),
    ],
  ),
];
```

#### Running via CLI
Simply pass the target file to the `bench` command:
```shell
dart run benchmark_harness:bench --target benchmark/json_suite.dart
```
The orchestrator will automatically discover your `benchmarks` list and execute JIT, AOT, JS, and WASM sweeps in complete isolation!

---

## 2. Operational Guidelines for the Measured Function

To ensure the self-calibrating engine produces statistically rigorous results,
follow these guidelines when implementing your `run()` function or variant
closure:

### 1. Exercise a Single Unit of Work
* **Do not** write loops (e.g., `for (var i = 0; i < 100000; i++)`) inside
  your measured function to increase duration.
* The framework's adaptive calibration engine automatically handles loops and
  optimizes iterations to fit the target time window.
* **Incorrect**:
  ```dart
  void run() {
    for (int i = 0; i < 1000; i++) {
      doWork();
    }
  }
  ```
* **Correct**:
  ```dart
  void run() {
    doWork();
  }
  ```

### 2. Target Execution Duration
* **Minimum Target**: The operations inside a single `run()` invocation should
  ideally take at least **1 millisecond** (ideally **5 milliseconds** or more)
  of continuous CPU activity.
  * *Why*: Executing operations that take mere nanoseconds introduces extreme
    timing overhead and measurement jitter. If your operation is extremely
    fast, bundle multiple iterations into a single task unit inside `run()`.
* **Maximum Target**: Keep the individual execution time below **50 milliseconds**
  to prevent adaptive calibration and the KBSSD warmup phase from running
  excessively long.

### 3. Automatic Pre-Run Calibration & Guideline Enforcement
To protect developers from inaccurate results, the framework executes a mini
calibration phase at the start of **every** benchmark run. The calibration
engine automatically runs the workload a few times to estimate its runtime and
verify compliance with execution guidelines:

* **Slightly Off Guidelines (e.g., 100 microseconds to 1 millisecond)**:
  The engine prints a diagnostic warning advising the developer to bundle more
  iterations, but proceeds with the benchmark run.
* **Way Off Guidelines (e.g., under 10 microseconds or over 200 milliseconds)**:
  The engine immediately **aborts** execution to prevent unreliable timings
  (or endless runs) and points the developer to troubleshooting steps.
* **Force Override**: If a developer has a unique use-case and wishes to bypass
  this safety abort, they can run the benchmark with the `--force-run` flag (or
  equivalent API parameter) to execute the benchmark at their own risk.

### 4. Ensure Determinism
* Minimize side effects, non-deterministic I/O, or network round-trips within
  the measured block.
* Perform non-deterministic actions (such as seeding random number generators
  or fetching remote resources) inside the `setup()` phase.

### 5. Avoid Compiler Optimizations (Dead Code Elimination)
* Ensure the output of the measured function is consumed or has side effects
  that prevent the compiler from optimizing the entire function call away.

---

## 3. Process-Level Isolation Architecture

Running multiple benchmarks or variants within the same OS process leads to
**JIT state pollution, garbage collection interference, and VM compilation
leakage** (where the compilation profile of Benchmark A affects the performance
of Benchmark B).

To achieve mathematically sound results, the framework supports and recommends
**Process-Level Isolation**:

```
[Orchestrator CLI]
       │
       ├───► Fork Process 1 (JIT) ────► Compile/Run Benchmark A ──► JSON Result
       ├───► Fork Process 2 (AOT) ────► Compile/Run Benchmark A ──► JSON Result
       │
       ├───► Fork Process 3 (JIT) ────► Compile/Run Benchmark B ──► JSON Result
       └───► Fork Process 4 (WASM) ───► Compile/Run Benchmark B ──► JSON Result
```

### Library-Based API Export
For orchestrator integration, benchmarks can export their declarations as a
library-level property instead of executing directly in `main()`:

```dart
// lib/benchmarks/json_benchmarks.dart
import 'package:benchmark_harness/benchmark_harness.dart';

// Expose the benchmarks as a top-level list
final List<Benchmark> benchmarks = [
  Benchmark(
    name: 'JSON-Map',
    variants: [
      BenchmarkVariant(name: 'Map-based', run: () => serializeWithMap(testData)),
    ],
  ),
];
```

The orchestrator tool compiles a temporary wrapper application targeting the
selected variant, executing it in a dedicated subprocess.

### Isolate-Mode Optimization for Fast JIT Iterations (`--isolate-mode`)
While process isolation is the gold standard for production benchmarks, spawning
subprocesses introduces overhead that can slow down local developer feedback.

To optimize local JIT iteration speeds, the CLI provides an optional
`--isolate-mode` flag:
* **Process Mode (Default)**: Fully isolated runs using dedicated OS subprocesses
  for each variant and platform target.
* **Isolate Mode (`--isolate-mode`)**: The orchestrator runs all target VM
  variants in separate Dart `Isolate` containers within the parent process. This
  eliminates OS process-fork overhead, offering rapid feedback during active
  development. *Note: Isolate-mode is not recommended for final CI regression
  testing due to VM-level compiler and GC thread sharing.*

---

## 4. Verification & Validation Command (`bench validate`)

To streamline developer workflows, the CLI provides a validation command:

```bash
dart run benchmark_harness:bench validate path/to/benchmark.dart
```

This command executes the benchmark briefly across all target platforms (JIT,
AOT, JS, WASM) and performs the following checks:
1. **Duration Jitter Check**: Warns if the measured run duration is under
   **1 millisecond** (suggesting timing overhead could dominate).
2. **Warmup Budget Check**: Warns if the operation takes longer than
   **100 milliseconds** (suggesting calibration will exceed time budgets).
3. **Optimizations Check**: Flags potential dead-code elimination if the
   run time is near-zero (under 1 nanosecond).
4. **Cross-Platform Consistency**: Verifies that the setup, run, and teardown
   routines execute successfully without throwing runtime exceptions on all
   targets.

---

## 5. Technical Reference: Orchestration Design Decisions

The following technical choices govern how the orchestrator command and
subprocesses interact:

### 1. Subprocess Execution Isolation (Generative Wrappers)
* The Orchestrator dynamically generates a temporary wrapper file that
  directly imports the user's library and invokes the specific variant's
  execution function inside its own `main()`. This avoids complex command-line
  parsing on the user's side.

### 2. Inter-Process Communication (JSON over stdout)
* The subprocess communicates its statistical metrics back to the parent
  process by printing a standardized JSON line prefixed with
  `__BENCHMARK_RESULT__` directly to standard output:
  ```
  __BENCHMARK_RESULT__ {"name":"JSON-Map","mean_us":1420.5,"cv":0.021}
  ```
* The Orchestrator parses this prefix from stdout, filtering out user prints
  or diagnostic warning logs.

### 3. Toolchain Handling (Graceful Degrade / Skip)
* The `bench validate` and run suites check for the local availability of
  compiling engines (`dart2js`, `dart compile exe`, `dart2wasm`) and target
  runtimes (`node`, `wasmtime`, `chrome`).
* If a component is missing, the Orchestrator skips the corresponding platform
  validation and logs a diagnostic warning instead of failing the validation
  run.

---

## 6. Standardized JSON Output Schema

To enable robust after-the-fact data analysis, CI regression checks, and deep
performance diagnostic visualization, the harness outputs a structured JSON
payload for every benchmark execution.

### JSON Schema Specification

```json
{
  "name": "JSON-Map",
  "variant": "Map-based",
  "platform": "wasm",
  "timestamp": "2026-05-09T23:15:00.000Z",
  "environment": {
    "os": "macos",
    "dart_sdk_version": "3.8.0",
    "v8_version": "12.4.254"
  },
  "metrics": {
    "samples_count": 30,
    "total_duration_us": 45000,
    "mean_us": 1500.0,
    "median_us": 1495.0,
    "min_us": 1480.0,
    "max_us": 1620.0,
    "std_dev_us": 25.5,
    "std_err_us": 4.65,
    "cv": 0.017,
    "confidence_interval_95": [1490.88, 1509.12]
  },
  "warmup_diagnostics": {
    "warmup_samples_count": 45,
    "warmup_converged": true,
    "warmup_mmd_score": 0.021,
    "warmup_best_mmd_fallback": false
  },
  "raw_samples_us": [
    1480, 1490, 1505, 1495, 1620, 1485
  ]
}
```

### Field Index & Description

*   **`metrics.samples_count`**: The total number of measured sample windows
    collected post-warmup.
*   **`metrics.mean_us` / `metrics.median_us`**: Central tendency values
    essential for computing standard ratio delta reports.
*   **`metrics.min_us`**: The Minimum Estimator (best-case scenario), highly
    useful under heavy OS jitter.
*   **`metrics.std_err_us` (SEM)**: Enables calculation of standard confidence
    bounds and overlaps.
*   **`metrics.cv`**: Coefficient of variation ($CV = \frac{\sigma}{\mu}$). Used to
    determine if a run is statistically unreliable or too noisy ($CV > 0.05$).
*   **`warmup_diagnostics`**: Captures details from the KBSSD phase to help
    developers diagnose why a benchmark failed to settle.
*   **`raw_samples_us`**: Optional array of individual sample values (in
    microseconds), allowing external data science tools to perform non-parametric
    distribution modeling, Wilcoxon tests, or Cliff's Delta estimations.

