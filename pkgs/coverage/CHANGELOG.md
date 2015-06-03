###0.7.0

 * `format_coverage` no longer emits SDK coverage unless --sdk-root is set
   explicitly.

###0.6.5

 * Fixed early collection bug when --wait-paused is set.

###0.6.4

 * Optimized formatters and fixed return value of `format` methods.
 
 * Added `Resolver.packageRoot` – deprecated `Resolver.pkgRoot`.

###0.6.3

 * Support the latest release of `args` package.
 
 * Support the latest release of `logging` package.
 
 * Fixed error when trying to access invalid paths.
 
 * Require at least Dart SDK v1.9.0.

###0.6.2
 * Support observatory protocol changes for VM >= 1.11.0.

###0.6.1
 * Support observatory protocol changes for VM >= 1.10.0.

###0.6.0+1
 * Add support for `pub global run`.

###0.6.0
  * Add support for SDK versions >= 1.9.0. For Dartium/content-shell versions
    past 1.9.0, coverage collection is no longer done over the remote debugging
    port, but via the observatory port emitted on stdout. Backward
    compatibility with SDKs back to 1.5.x is provided.
