# Design Document: The Zero-Cost Benchmark "Blackhole" in Dart

This document presents a comprehensive compiler review and implementation design for a **`Blackhole`** utility in Dart's benchmarking libraries (such as `benchmark_harness`).

A benchmarking `Blackhole` (similar to JMH's `Blackhole.consume()`) prevents the compiler from performing **dead-code elimination (DCE)** on unused benchmark return values, while introducing **zero runtime execution overhead**.

---

## 1. Compiler Optimization Analysis

We analyzed how Dart's production compilers—**Dart VM (JIT/AOT)**, **dart2js**, and **dart2wasm**—manage dead-code elimination, tree-shaking, and custom optimization hints.

### The Standard Solution: `@pragma('external-effect')`

Dart features a standardized compiler-recognized pragma called `'external-effect'`. This pragma instructs the Common Front-End (CFE) and the back-end compilers to treat an `external` static/top-level function as a "live code sink."

#### Definition Requirements
A method annotated with `@pragma('external-effect')` must satisfy:
1. It must be `external`.
2. It must be a static or top-level method.
3. It must have a signature compatible with `void Function(Object?)`.

---

## 2. How Each Compiler Handles `external-effect`

### A. Common Front-End (CFE)
During kernel compilation, the CFE (via `ExternalEffect.validatePragma` in [external_effect.dart](file:///Users/kevmoo/github/dart/sdk/pkg/front_end/lib/src/kernel/external_effect.dart)) checks all methods annotated with `'external-effect'`. If the signature and modifier requirements are met, it marks the method AST node with `hasExternalEffectPragma = true`.

### B. Dart VM (Native / JIT / AOT)
* **Global Analysis / Tree-Shaking (TFA)**: The VM treats `external-effect` methods as entry-point roots. Because of this, any value passed to an `external-effect` method is considered **live**. Global optimizations like tree-shaking or aggressive dead-code elimination will not touch the code computing the passed value.
* **Code Generation**: During graph building (in [kernel_binary_flowgraph.h](file:///Users/kevmoo/github/dart/sdk/runtime/vm/compiler/frontend/kernel_binary_flowgraph.h)), the VM recognizes the `external-effect` call and **drops both the call itself and its arguments** from the generated machine code. 
* **Result**: Zero native instructions are generated for the call. The computed value is kept alive but never actually passed to any function at runtime.

### C. dart2js
* **Modular Compilation**: In the modular SSA builder ([builder.dart](file:///Users/kevmoo/github/dart/sdk/pkg/compiler/lib/src/ssa/builder.dart)), static invocations annotated with `external-effect` are intercepted.
* **Code Generation**: The compiler builds an empty body (a no-op) for the external function and drops the call from the generated JavaScript code.
* **Result**: The expression computing the benchmark value is preserved, but the compiled JavaScript contains zero calls or runtime overhead.

### D. dart2wasm
* **Code Generation**: During Wasm code generation ([code_generator.dart](file:///Users/kevmoo/github/dart/sdk/pkg/dart2wasm/lib/code_generator.dart#L1629-L1631)), the compiler explicitly checks `ExternalEffect.isExternalEffect(node)`:
  ```dart
  if (ExternalEffect.isExternalEffect(node)) {
    return voidMarker;
  }
  ```
* **Result**: It returns a `voidMarker` immediately and emits **zero Wasm instructions** for the call. Tree-shaking is prevented by the global TFA, but the Wasm binary has absolutely no runtime execution penalty.

---

## 3. Recommended Implementation Strategy

To expose a clean, object-oriented `Blackhole` API while guaranteeing that the compiler inlines the call site (to eliminate the wrapper call overhead), we combine `@pragma('external-effect')` with target-specific **inlining overrides**:

```dart
/// A utility to prevent the compiler from optimizing away benchmark computations via dead-code elimination.
///
/// Passing a value to [consume] ensures that the compiler treats the value's computation as live,
/// while introducing zero runtime execution overhead.
class Blackhole {
  const Blackhole();

  /// Consumes [value] to prevent dead-code elimination of its computation.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @pragma('wasm:prefer-inline')
  void consume(Object? value) {
    _reach(value);
  }
}

/// The compiler-recognized zero-cost live sink.
@pragma('external-effect')
external void _reach(Object? value);
```

### Why This is Perfect:
1. **Zero Overhead**: The combination of aggressive inlining pragmas (`vm:prefer-inline`, `dart2js:prefer-inline`, `wasm:prefer-inline`) ensures that `blackhole.consume(x)` is inlined directly to `_reach(x)` at the call site. 
2. **Complete DCE Protection**: Once inlined, the compiler treats `_reach(x)` as a live use of `x`, preserving the computation of `x`.
3. **Zero Instruction Emission**: The compilers drop the actual `_reach` call entirely during code generation.

---

## 4. Loop Optimization Defense

JMH also identifies the **LOOP** bad practice, where developers try to prevent DCE by accumulating values inside a loop:
```dart
// BAD PRACTICE: Enables aggressive loop optimizations / unrolling that distort real-world usage
int accumulator = 0;
for (int i = 0; i < 1000; i++) {
  accumulator += computeValue();
}
```
By instead using the zero-cost `Blackhole.consume`, the loop remains unpolluted by arbitrary accumulators:
```dart
// GOOD PRACTICE: Real-world loop characteristics, zero-cost DCE protection
for (int i = 0; i < 1000; i++) {
  blackhole.consume(computeValue());
}
```
