## 2.5.0

- Added an opt-in detailed measurement path for benchmarks where one
  `run()` is at or above the timer noise floor (~100 µs).
  - `BenchmarkBase.measureDetailed({minimumMillis})` returns a new
    `DetailedMeasurement` that retains every per-call elapsed time and
    exposes `meanMicros`, `medianMicros`, `minMicros`, `stddevMicros`,
    and `coefficientOfVariation`.
  - `BenchmarkBase.reportDetailed({minimumMillis})` prints the mean,
    median, coefficient of variation, sample count, and minimum to
    stdout via a new top-level `printDetailedMeasurement(name,
    measurement)` helper.
  - The detailed path bypasses any `exercise` override and times each
    `run()` call individually, so the reported mean is per `run()`, not
    per batch of 10.
- Existing APIs (`measure`, `report`, `Measurement`, `PrintEmitter`,
  `PrintEmitterV2`, `ScoreEmitter`, `ScoreEmitterV2`) are unchanged.

## 2.4.0

- Added a `bench` command.
- Require `sdk: ^3.10.0`.

## 2.3.1

- Move to `dart-lang/tools` monorepo.

## 2.3.0

- Require Dart 3.2.
- Add ScoreEmitterV2 interface, documented with the intention to change
ScoreEmitter interface to match it in the next major release,
 a breaking change.
- Add `PerfBenchmarkBase` class which runs the 'perf stat' command from
linux-tools on a benchmark and reports metrics from the hardware
performance counters and the iteration count, as well as the run time
measurement reported by `BenchmarkBase`.

## 2.2.2

- Added package topics to the pubspec file.
- Require Dart 2.19.

## 2.2.1

- Improve convergence speed of `BenchmarkBase` measuring algorithm by allowing
some degree of measuring jitter.

## 2.2.0

- Change measuring algorithm in `BenchmarkBase` to avoid calling stopwatch
methods repeatedly in the measuring loop. This makes measurement work better
for `run` methods which are small themselves.

## 2.1.0

- Add AsyncBenchmarkBase.

## 2.0.0

- Stable null safety release.

## 2.0.0-nullsafety.0

- Opt in to null safety.

## 1.0.6

- Require at least Dart 2.1.

## 1.0.5

- Updates to support Dart 2.
