# TODO items

- ✅ Update deprecated note in warmup to be clear what the user should do.
- Data classes for JSON output. Encode and decode. So they can be easily used by other systems.
  - Including THIS system when we want to compare runs!
- Investigate how to enable "other procses coordination" with a benchmark.
  - Thinking mostly RE server benchmarks with an external "traffic" driver (like wrk or oha)
- Add mathematically rigorous comparison features:
  - **Fieller's Interval**: Compute mathematically sound confidence intervals for speedup/slowdown ratios rather than simple division.
  - **Cliff's Delta Effect Size**: Categorize performance changes (negligible, small, medium, large) using non-parametric effect sizes to minimize false-alarm CI regressions on micro-jitter.
  - **Report Minimum Estimator**: Expose raw minimum execution timing since OS and VM scheduling interrupts strictly add timing noise.
- Improve mathematical robustness of KBSSD:
  - **Guard calculateMMD against mismatched lengths**: Add a validation guard or clean support to prevent `RangeError` when lists are not equal in size.
- Expose pre-baked logging utilities:
  - Expose custom logger helpers (e.g., `SilentLogger`, `JsonLogger`, `FileLogger`) leveraging the newly injectable `RunnerConfig.logger` callback.
