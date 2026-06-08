# Kernel-Based Steady-State Detection (KBSSD) in Real-World Environments

When executing benchmarks in modern, shared virtualization or containerized environments (such as GitHub Actions, GCP Cloud Build, or Kubernetes), the timing metrics are often subjected to significant background operating system noise. CPU core sharing, thread scheduling interrupts, and thermal throttling create artificial timing spikes that can prevent mathematical steady-state detectors (like Maximum Mean Discrepancy) from ever proving convergence.

This guide details the production-grade architectural patterns for managing high noise and non-converging environments when using KBSSD.

---

## 1. The "Patience Budget" & Best-Effort Fallback

We must never allow a benchmark warmup phase to execute indefinitely. We define a hard sample budget (or total elapsed time budget). If the budget is exceeded without proving convergence:
1. **Fallback to Best-Effort**: The detector should track the **historically most stable window** (the sliding window that produced the absolute lowest MMD score during the entire run) and return those samples.
2. **Traditional Averaging & Warning**: Declare that steady state could not be mathematically proven, and report the mean of the best-effort window alongside a high Coefficient of Variation (CV) to notify the user of the environmental noise.
3. **Strict CI Failure**: In automated performance regression suites, flag the environment as "insufficiently stable for statistical guarantees" to prevent false-positive alarms.

### Implementation Pattern

```dart
class SteadyStateResult {
  final bool isSteady;
  final double mmdScore;
  final List<int> samples;

  SteadyStateResult(this.isSteady, this.mmdScore, this.samples);
}

class KBSteadyStateDetector {
  final int windowSize;
  final double threshold;
  final int stabilityRequired;

  final List<int> _buffer = [];
  int _stabilityCount = 0;
  int _totalSamples = 0;
  double _sigma = 0.0;

  // Track the historically best window as a fallback
  double _bestMMD = double.infinity;
  List<int> _bestSamples = [];

  KBSteadyStateDetector({
    this.windowSize = 15,
    this.threshold = 0.04,
    this.stabilityRequired = 8,
  });

  Stream<SteadyStateResult> analyze(Stream<int> benchmarkStream, {int maxSamples = 200}) async* {
    await for (int sample in benchmarkStream) {
      _buffer.add(sample);
      _totalSamples++;

      if (_buffer.length < windowSize * 2) continue;
      if (_buffer.length > windowSize * 2) {
        _buffer.removeAt(0);
      }

      _sigma = _estimateSigma(_buffer);
      var past = _buffer.sublist(0, windowSize);
      var present = _buffer.sublist(windowSize);
      
      var mmd = _calculateMMD(past, present);

      // Track the historically most stable window
      if (mmd < _bestMMD) {
        _bestMMD = mmd;
        _bestSamples = List.from(present);
      }

      var isCurrentlySteady = mmd < threshold;
      if (isCurrentlySteady) {
        _stabilityCount++;
      } else {
        _stabilityCount = 0;
      }

      var reachedGoal = _stabilityCount >= stabilityRequired;
      var budgetExceeded = _totalSamples >= maxSamples;
      var stopExecution = reachedGoal || budgetExceeded;

      if (reachedGoal) {
        print('✅ Steady State Detected after $_totalSamples samples.');
      } else if (budgetExceeded) {
        print('⚠️ Warmup budget exceeded ($maxSamples samples) without proving convergence.');
        print('   Falling back to historically best-effort window (MMD: ${_bestMMD.toStringAsFixed(5)}).');
      }

      yield SteadyStateResult(
        reachedGoal || budgetExceeded,
        mmd,
        reachedGoal ? present : _bestSamples,
      );

      if (stopExecution) return;
    }
  }

  // ... rest of KBSteadyStateDetector implementation ...
}
```

---

## 2. Dynamic Threshold Tuning (Self-Adaptive Calibration)

In ultra-quiet environments (bare metal), a threshold of `0.01` is easily reached. In extremely noisy runners, the baseline MMD distance may float around `0.06` even during perfect steady state due to background jitter.

* **The Strategy**: Calibrate the threshold dynamically during the initial cold-buffer filling phase (the first $2 \times \text{windowSize}$ samples). 
* **The Math**: Measure the Mean Absolute Deviation (MAD) of the initial samples and set `threshold = baselineMAD * multiplier`. 
* **Why it works**: The detector expects the system to stabilize *relative* to its environment. A noisy VM calibrates a wider threshold, preventing the benchmark from hanging, while a clean bare-metal environment calibrates a tight threshold for extreme precision.

---

## 3. Outlier Rejection (Median Pre-Filtering)

OS background interruptions typically manifest as massive isolated timing spikes (e.g., standard execution is `3700us` but jumps to `8500us` once every 2 seconds because of GC or context switching).

* **The Strategy**: Apply a rolling **Trimmed Mean** or **Outlier Filter** to the window buffers *before* passing them to the MMD calculations. For example, drop the top and bottom 10% of timing values in the sliding window.
* **Why it works**: By stripping out isolated scheduling and GC interruptions, you isolate the evaluation of the VM JIT compiler's actual warmup state from background noise.

---

## 4. Practical Steady State (Confidence Interval Width)

If MMD struggles to stabilize due to small, high-frequency noise, you can combine the Kernel Detector with the **Standard Error of the Mean (SEM)**:

$$\text{SEM} = \frac{\text{Standard Deviation}}{\sqrt{\text{Sample Size}}}$$

If the 95% confidence interval width of the present window's mean is less than a small percentage (e.g., $\pm3\%$) of the window's overall mean:

$$\text{Confidence Interval Width} = 1.96 \times \text{SEM} \le 0.03 \times \text{Mean}$$

We declare a **Practical Steady State**. For the purposes of microbenchmarking, the workload is sufficiently stable for taking measurements, even if the underlying distribution is experiencing minor micro-jitter.
