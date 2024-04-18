## 2.2.3

- Require Dart 3.2.
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
