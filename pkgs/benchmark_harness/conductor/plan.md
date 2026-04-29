# Implementation Plan - Modernizing benchmark_harness

This plan outlines the steps to upgrade `package:benchmark_harness` with statistical rigor, adaptive sampling, and better cross-platform reporting, leveraging `package:stats` for mathematical calculations.

## Objective
Make `benchmark_harness` the premier tool for Dart performance measurement by:
- Integrating `package:stats` for reliable statistics (Median, Standard Deviation, Confidence Intervals).
- Implementing an original, adaptive sampling engine to automate run durations.
- Enhancing cross-platform reporting (JIT, AOT, JS, WASM) via structured output.

## Key Files & Context
- `lib/src/runner.dart`: New file for the core benchmarking engine.
- `lib/src/benchmark.dart`: New compositional API.
- `lib/src/report.dart`: New file for formatting and statistical analysis.
- `bin/bench.dart`: CLI tool for multi-platform runs.

## Phased Implementation

### Phase 1: Dependencies & Foundation
1. **Add `package:stats`**: Add to `pubspec.yaml` as a dependency.
2. **Define Result Models**:
   - Create `lib/src/result.dart` to hold raw samples and metadata.
   - Use `package:stats`'s `Stats` object to wrap these samples for analysis.

### Phase 2: Adaptive Benchmarking Engine
1. **Calibration logic**:
   - Run the code a small number of times to estimate iterations needed to reach ~10ms.
2. **Warmup logic**:
   - Run for a fixed duration or until standard deviation of recent samples stabilizes.
3. **Sampling logic**:
   - Collect a target number of samples (default 10).
   - If the 95% confidence interval is too wide (relative to the mean), take more samples up to a maximum (e.g., 30 samples or 5 seconds total).

### Phase 3: New Compositional API
1. **Composition over Inheritance**:
   - Introduce `Benchmark` and `BenchmarkVariant` classes.
   - **`BenchmarkVariant`**: A lightweight container for a specific version of a task. It includes:
     - `name`: A descriptive label (e.g., "JSON-Map" vs "JSON-Record").
     - `run`: The function (sync or async) to be measured.
     - This allows users to define multiple "variants" in one script for easy comparison without creating multiple classes.
   - **`Benchmark`**: Orchestrates the measurement of one or more variants, ensuring shared configuration and direct comparison ratios (e.g., "Variant B is 1.5x faster than Variant A").
2. **Backward Compatibility**:
   - Refactor `BenchmarkBase` and `AsyncBenchmarkBase` to use the new `BenchmarkRunner` internally, ensuring zero breakage for existing users.

### Phase 4: Enhanced Reporting & Emitters
1. **Rich Emitters**:
   - Update `ScoreEmitter` to accept a `Stats` object.
   - Implement `JsonEmitter` for CI/CD integration and multi-platform aggregation.
2. **Statistical Interpretation**:
   - Add logic to `lib/src/report.dart` to flag "unreliable" benchmarks (high CV% or wide confidence intervals).

### Phase 5: CLI Tool & Platform Aggregation
1. **Structured Output**: 
   - Update `bin/bench.dart` to request JSON output from the target benchmark scripts.
2. **Multi-platform Aggregator**:
   - Gather JSON results from JIT, AOT, JS, and WASM runs.
   - Output a combined Markdown table comparing performance across ALL platforms.

## Future Phase: Delta Comparison (Controller Mode)
1. **Repository Orchestration**:
   - Allow `bench` to run as a globally activated tool.
   - Point the tool at a git repository and a set of benchmarks.
2. **Commit-to-Commit Comparisons**:
   - Provide a list of git refs (commits, branches, or tags).
   - The tool will:
     - Checkout each ref.
     - Run `dart pub get`.
     - Execute the benchmarks and collect JSON results.
     - Automatically restore the original state of the repo.
3. **Regression Analysis**:
   - Generate a "Delta Report" showing performance changes between commits.
   - Highlight significant regressions using the statistical confidence intervals calculated in Phase 1.

## Verification & Testing
- Integration tests for the adaptive engine (ensure it hits timing targets).
- Verify `package:stats` integration for correctness.
- Cross-platform verification of the `bench` command.
- Benchmark the harness itself to ensure minimal overhead.
