# Reflections on Aligning benchmark_harness with Slava's Microbenchmarking Principles

Based on a review of the `better_bench` branch (PR #2394), the local modernization plans (`plan.md` and `benchmark_blackhole_alternatives.md`), and Slava Egorov's blog post on Dart microbenchmarking, here are reflections on the current approach and recommendations to fully align the package with VM-level best practices.

## 1. Where We Are Already Making Slava Happy

*   **Defeating Dead Code Elimination (DCE):** Slava's biggest pet peeve is benchmarking "empty loops" because the compiler optimized the code away. The research in `benchmark_blackhole_alternatives.md` and the implementation of a `Blackhole` sink using an opaque static guard condition is excellent. This directly addresses the Type Flow Analysis (TFA) and SSA optimizations that frequently ruin microbenchmarks. 
*   **Statistical Rigor vs. Environmental Noise:** The implementation of KBSSD (Kernel-Based Steady-State Detection) in `plan.md` to mathematically prove steady states and filter outliers is a huge step up. Slava acknowledges that JIT compilers and underlying OS environments are incredibly noisy, and dynamic thresholding with MAD (Mean Absolute Deviation) helps smooth over context switches and background GC.

## 2. The Gap: Harness Overhead vs. Environmental Noise

Slava explicitly calls out older versions of `package:benchmark_harness` for introducing its *own* noise:
> *"Standard tools like `package:benchmark_harness` can introduce significant noise through frequent `Stopwatch` calls and virtual dispatch."*

While the KBSSD plan brilliantly solves **environmental noise** (GC, OS scheduling), it doesn't inherently solve **harness noise**. 

**How to fix this:**
*   **Devirtualize the Hot Loop:** Ensure that the tight inner loop of the `BenchmarkRunner` is monomorphic. If the harness uses virtual dispatch (calling interface methods over and over inside the timed section), the Dart VM has to do extra work. 
*   **Batching / Stopwatch Discipline:** Avoid starting and stopping the `Stopwatch` around single iterations of micro-tasks. The `Stopwatch` itself takes time. Ensure the harness runs the target function in batches ($N$ times), takes one `Stopwatch` measurement, and divides by $N$.

## 3. Recommendations to Push Further

To push `benchmark_harness` into the realm of being a truly "compiler-aware" and robust tool that a VM engineer would recommend without caveats:

*   **Elevate AOT over JIT:** The plan mentions supporting JIT, AOT, JS, and WASM. Slava warns that JIT microbenchmarks are inherently unstable due to background optimization threads and tiered compilation. In the aggregator/reporting tool (`bin/bench.dart`), consider adding warnings when analyzing JIT results, or visually elevating AOT results as the "source of truth."
*   **Explore `@pragma('vm:no-interrupts')`:** For the absolute tightest loops, investigate using the `vm:no-interrupts` pragma around the actual measurement execution block. This prevents the VM from yielding to background threads or GC during the split-second the measurement is occurring.
*   **Add Profiling/Disassembly Hooks:** Slava's ultimate advice is "never trust the benchmark; look at the assembly." It would be a standout feature if `dart run benchmark_harness:bench` had a `--disassemble` or `--perf` flag that automatically passed `--disassemble` to the Dart VM or hooked into native tools (like `simpleperf` on Linux/macOS) to output exactly what the JIT/AOT compiler decided to generate for the benchmark loop. 

**Summary:** The shift toward mathematical steady-state detection (KBSSD) and compiler-safe blackholes is exactly the right direction. The final 10% to completely align with Slava's philosophy is ensuring the harness itself (virtual calls, stopwatch timing) is practically invisible to the VM during the measurement phase.
