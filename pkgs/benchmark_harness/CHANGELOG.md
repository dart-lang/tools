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
