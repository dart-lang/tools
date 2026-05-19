The sources detail a wide variety of mathematical, statistical, and algorithmic techniques that are crucial for building a rigorous benchmarking library. These techniques address everything from experiment design to steady-state detection, and final statistical evaluation.

Here are the most important algorithms and statistical techniques highlighted in the sources:

**Steady-State and Change Point Detection**
*   **Kernel-based Kelly's Steady State Detection (KB-KSSD):** Adapted from the chemical reactor domain, this approach models time series as a "random walk with drift". It uses **convolution with asymmetric kernels** to directly look for "step-down" patterns in performance, which visually represent the sudden drop in execution time when a warmup phase ends.
*   **PELT (Pruned Exact Linear Time):** A standard change-point detection algorithm used to automatically identify changes in benchmark execution times to determine if and when steady-state performance is reached.
*   **Time-Series Visual Statistics:** To determine if benchmark iterations have reached a statistically independent state, you can use **Autocorrelation Function (ACF) plots** (which check the correlation of a time series with its lagged version) and **lag plots** to detect systemic dependencies.

**Estimators, Distributions, and Outliers**
*   **The Minimum Estimator:** Because timing measurements are rarely independent and identically distributed (i.i.d.) and suffer from heavy-tailed noise, standard estimators like the mean or median can be easily skewed. The sources mathematically justify using the **minimum estimator** because environmental factors (like OS jitter) strictly *add* delay; therefore, the smallest timing measurement has the smallest magnitude of error.
*   **Poisson Binomial Distribution:** The total number of times a delay factor is triggered during a program's execution can be modeled as a sum of independent Bernoulli random variables with nonidentical success probabilities, meaning the delay follows a Poisson binomial distribution.
*   **Median-Based Filtering:** To prevent single outliers from skewing the interpretation of steadiness, a time series can be divided into subsets. Data points falling outside specific percentiles are detected as outliers and replaced with the **local median** to smooth the data.

**Significance Testing and Analysis of Variance**
*   **Wilcoxon Non-parametric Test:** Used to determine if the distributions of two sets of performance counters are statistically significantly different without assuming a normal distribution.
*   **Student’s t-test:** A standard probabilistic method used for comparing the means of two groups to establish if performance differences are statistically significant.
*   **Analysis of Variance (ANOVA):** Used to summarize variations across multiple layers of an experiment (e.g., between benchmark iterations, executions, and compilations).

**Quantifying Performance Changes**
*   **Cliff's Delta Effect Size:** A statistical technique used to quantify the actual magnitude of a difference between two benchmarks (rather than just its statistical significance), categorizing the effect size into discrete thresholds: negligible, small, medium, or large.
*   **Fieller’s Interval (Confidence Interval for Ratios):** When comparing the speedup of a new system versus a baseline, researchers generally report a ratio of execution times. Fieller's theorem is used to accurately calculate the confidence interval for this ratio, which is superior to other methods because it does not assume the ratios themselves are normally distributed.

**Experimental Design and Heuristics**
*   **$2^k$ Factorial and Fractional Factorial Designs:** Mathematical experiment designs used to evaluate systems with multiple interacting variables (e.g., different memory sizes, processors, and network speeds). These designs, often analyzed using the **Sign Table Method**, allow you to isolate the specific impact of individual factors and their multi-factor interactions without having to test every single possible combination.
*   **Oracle Functions and the Generalized Logistic Function:** To automatically guess the optimal number of benchmark repetitions needed to overcome system timer error, an "oracle function" is used. This often takes the mathematical form of a **generalized logistic function** to map expected run times to the optimal number of executions.
*   **Sobol's Indices:** A global sensitivity analysis technique used to quantify how much each individual input parameter (and the interactions between parameters) contributes to the total variance of an algorithm's output.
