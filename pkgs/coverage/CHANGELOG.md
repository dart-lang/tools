## 0.7.6

 * Add [Bazel](http://bazel.io) support to `format_coverage`.

## 0.7.5

 * Bugfix in `collect_coverage`: prevent hang if initial VM service connection
   is slow.
 * Workaround for VM behaviour in which `evaluate:source` ranges may appear in
   the returned source report manifesting in a crash in `collect_coverage`.
   These generally correspond to source evaluations in the debugger and add
   little value to line coverage.
 * `format_coverage`: may be slower for large sets of coverage JSON input
   files. Unlikely to be an issue due to elimination of `--coverage-dir` VM
   flag.

## 0.7.4

 * Require at least Dart SDK 1.16.0.

 * Bugfix in format_coverage: if `--report-on` is not specified, emit all
   coverage, rather than none.

## 0.7.3

 * Added support for the latest Dart SDK.

## 0.7.2

 * `Formatter.format` added two optional arguments: `reportOn` and `pathFilter`.
   They can be used independently to limit the files which are included in the
   output.

 * Added `runAndCollect` API to library.

## 0.7.1

 * Added `collect` top-level method.

 * Updated support for latest `0.11.0` dev build.

 * Replaced `ServiceEvent.eventType` with `ServiceEvent.kind`.
   *  `ServiceEvent.eventType` is deprecated and will be removed in `0.8`.

## 0.7.0

 * `format_coverage` no longer emits SDK coverage unless --sdk-root is set
   explicitly.

 * Removed support for collecting coverage from old (<1.9.0) Dart SDKs.

 * Removed deprecated `Resolver.pkgRoot`.

## 0.6.5

 * Fixed early collection bug when --wait-paused is set.

## 0.6.4

 * Optimized formatters and fixed return value of `format` methods.

 * Added `Resolver.packageRoot` – deprecated `Resolver.pkgRoot`.

## 0.6.3

 * Support the latest release of `args` package.

 * Support the latest release of `logging` package.

 * Fixed error when trying to access invalid paths.

 * Require at least Dart SDK v1.9.0.

## 0.6.2
 * Support observatory protocol changes for VM >= 1.11.0.

## 0.6.1
 * Support observatory protocol changes for VM >= 1.10.0.

## 0.6.0+1
 * Add support for `pub global run`.

## 0.6.0
  * Add support for SDK versions >= 1.9.0. For Dartium/content-shell versions
    past 1.9.0, coverage collection is no longer done over the remote debugging
    port, but via the observatory port emitted on stdout. Backward
    compatibility with SDKs back to 1.5.x is provided.
