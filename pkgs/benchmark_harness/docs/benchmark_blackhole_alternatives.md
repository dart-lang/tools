# Research & Design: Compiler-Safe "Blackhole" Alternatives for Older Dart SDKs

This document presents alternative design strategies for a zero-overhead, compiler-safe benchmarking **`Blackhole`** utility that supports older Dart SDKs (such as Dart 3.10 and 3.11) across all compilation pipelines: **Dart VM (JIT/AOT)**, **`dart2js`**, and **`dart2wasm`**.

---

## 1. The Core Compiler Challenge

In modern optimizing compilers, **Dead Code Elimination (DCE)** and **Tree-Shaking** rely on global analysis to identify and discard unused code or data. 

### A. Global Type Flow Analysis (TFA)
In Dart's Native AOT and `dart2wasm` pipelines, the compiler performs **Type Flow Analysis (TFA)** to construct a closed-world view of the program. 
* If a value is computed but never read, or if it is written to a field that is strictly **write-only** (never read anywhere in the closed world), the compiler determines that the field and all assignments to it are dead.
* The compiler then completely eliminates the expressions computing those values.

### B. SSA Optimization
In `dart2js`, the compiler performs Static Single Assignment (SSA) optimization.
* If the `blackhole(value)` function is inlined and the compiler discovers the value is never read, the entire inline block and the target computation are discarded from the generated JavaScript.

### C. The Limitation of `@pragma('external-effect')` in Pre-3.13 SDKs
In newer Dart SDKs, the `'external-effect'` pragma instructs the compilers to treat an `external` static method as a "live code sink," dynamically dropping the call at code generation time while keeping the arguments alive. 
However, in Dart 3.10 and 3.11:
* The compilers do not recognize this pragma.
* The compiler will treat the `external` method as lacking a concrete implementation and throw **link-time / compilation errors** during code generation.

---

## 2. Alternative Design A: Opaque Static Sink with De-optimization Guard (Recommended)

This approach leverages a public static field (`_sink`) to record the benchmark computations, combined with a **runtime-opaque read guard** that prevents the Type Flow Analysis (TFA) from classifying the field as "write-only."

### Implementation
```dart
import 'dart:math' as math;

/// A compiler-safe utility to prevent dead-code elimination of benchmark computations
/// on older Dart SDKs (Dart 3.10 - 3.11+).
class Blackhole {
  static dynamic _sink;

  /// Consumes [value] to prevent dead-code elimination.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @pragma('wasm:prefer-inline')
  void consume(Object? value) {
    _sink = value;
  }

  /// Opaque guard that reads [_sink] under a condition that the compiler
  /// cannot statically resolve to false at compile time.
  /// 
  /// Call this method once at the beginning of your benchmark suite's `main()`.
  @pragma('vm:never-inline')
  @pragma('dart2js:never-inline')
  @pragma('wasm:never-inline')
  static void preventDCE() {
    // This condition is always false at runtime, but opaque to the compiler
    if (DateTime.now().millisecondsSinceEpoch == 0) {
      print(_sink);
      // Introduce a secondary mathematical loop dependency to fully secure TFA
      if (math.max(1, 2) == 0) {
        _sink = null;
      }
    }
  }
}

/// Global shorthand to match modern APIs
@pragma('vm:prefer-inline')
@pragma('dart2js:prefer-inline')
@pragma('wasm:prefer-inline')
void blackhole(Object? value) {
  Blackhole._sink = value;
}
```

### How It Works under TFA & SSA
1. **Opaque Condition**: The check `DateTime.now().millisecondsSinceEpoch == 0` relies on a dynamic system call. The compiler cannot statically evaluate this to a constant `false` at compile time.
2. **TFA Classification**: Because `print(_sink)` exists inside the branch, the TFA compiler is forced to classify `_sink` as **both written and read**. Thus, `_sink` is marked as a live global root.
3. **DCE Protection**: Since `_sink` is a live global root, all writes to it (inside `consume` or the global `blackhole` function) are considered live side-effects. The compiler preserves the entire computation path leading to those writes.
4. **Zero Runtime Cost**: Since the guard condition is always `false` at runtime, the print statement is never executed. The runtime cost of writing to `_sink` is a single CPU memory store instruction (sub-nanosecond overhead), which is completely negligible for benchmarking.

---

## 3. Alternative Design B: Platform-Specific JS/Wasm No-Op Shims

This approach utilizes Dart's conditional exports and platform-specific bindings (`@JS`) to bind the `external` method directly to a native no-op JS function on Web platforms, while falling back to the static sink on Native VM platforms.

### Project Structure
```
lib/src/
  ├── blackhole.dart             # Public interface
  ├── blackhole_vm.dart          # Native VM implementation (Static Sink)
  └── blackhole_web.dart         # Web JS/Wasm implementation (JS No-op)
```

### `lib/src/blackhole_web.dart`
```dart
import 'dart:js_interop';

@JS('console.debug') // Binds to console.debug or a custom no-op JS function
external void _reach(JSAny? value);

@pragma('dart2js:prefer-inline')
@pragma('wasm:prefer-inline')
void blackhole(Object? value) {
  if (value is JSAny) {
    _reach(value);
  }
}
```

### `lib/src/blackhole_vm.dart`
```dart
class BlackholeVMSink {
  static dynamic sink;
  
  @pragma('vm:never-inline')
  static void preventDCE() {
    if (DateTime.now().millisecondsSinceEpoch == 0) {
      print(sink);
    }
  }
}

@pragma('vm:prefer-inline')
void blackhole(Object? value) {
  BlackholeVMSink.sink = value;
}
```

### How It Works
1. **Web Targets (`dart2js`/`dart2wasm`)**: The compiler binds `_reach` to `console.debug` (or an injected no-op). Because it is declared as a platform-external JS call, the compiler treats it as a **dynamic external effect** with potential side-effects. The compiler keeps the arguments alive but does not need a Dart implementation of the method.
2. **Native VM Targets**: Falls back to the `BlackholeVMSink` where TFA is kept alive by the `preventDCE()` opaque read guard.

---

## 4. Comparative Summary & Recommendation

| Metric | Alternative A: Opaque Static Sink (Recommended) | Alternative B: Platform-Specific Shims |
| :--- | :--- | :--- |
| **Complexity** | Low (Single file, pure Dart). | High (Conditional imports, multiple files, JS bindings). |
| **Older SDK Compatibility** | Excellent (Works out-of-the-box on Dart 3.10+). | Medium (JS/Wasm types and `@JS` signatures evolved between 3.10-3.13). |
| **Runtime Overhead** | Negligible (Single memory store). | Negligible (JS/Interop boundary transition cost). |
| **Maintainability** | High (No platform-specific duplication). | Medium (Requires keeping shims in sync). |

### Recommendation
**Alternative A (Opaque Static Sink with De-optimization Guard)** is highly recommended. It is pure Dart, works cleanly across all platforms without requiring conditional imports or native JS type checks, is 100% compile-safe under TFA/SSA, and is extremely easy to maintain.
