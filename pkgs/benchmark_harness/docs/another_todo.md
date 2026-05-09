# Unified Modernization & Review Backlog (another_todo.md)

This backlog unifies the findings from the architectural audit ([agent_analysis2.md](file:///Users/kevmoo/github/tools/pkgs/benchmark_harness/docs/agent_analysis2.md)) and the active GitHub PR review comments.

---

### [x] 2. `UNIFIED-02`: Robust JSON Output Parsing
* **Sources**: `BUG-02` (Audit), PR Comment 5 (`compile_and_run.dart`)
* **Problem**: The orchestrator assumes `jsonDecode(output)` will always return a `Map<String, dynamic>`. If the benchmark prints a JSON List `[]` or outputs diagnostic text before the JSON payload, the runner crashes with a `TypeError` or `FormatException`.
* **Proposed Action**:
  1. Update `_parseResult` in `compile_and_run.dart` to check if `jsonDecode(output) is Map<String, dynamic>`.
  2. If the decoded object is a generic `Map`, perform a type-safe cast (`Map<String, dynamic>.from(decoded)`).
  3. If the decode fails or returns a non-Map (like `List`), catch the error gracefully and fallback to legacy plain-text RegExp parsing before raising a `FormatException`.
* **Our Opinion / Next Steps**: **Partially Agree (P1).**
  - We **strongly agree** with making `_parseResult` robust against non-Map decodes to prevent hard crashes.
  - However, we **disagree** with the reviewer's suggestion in PR Comment 5 to introduce a custom output prefix like `__BENCHMARK_RESULT__`. Pumping proprietary text prefixes to stdout breaks standard CLI piping conventions (e.g., running `bench --json > results.json` and reading with `jq`). The orchestrator should remain clean and rely on robust parsing rather than non-standard wrappers.
* **Status**: **Completed!** Completely resolved redundant control flow. Fallbacks to legacy RegExp line parsing are consolidated into a single, elegant execution point at the bottom of the function, catching both non-Map and format exception decodes. Fully verified via `dart test`.

---

### [ ] 4. `UNIFIED-02`: Codebase Decoupling & Clean-up
* **Sources**: `ARCH-01` (Audit), `DX-01` (Audit)
* **Problem**: `compile_and_run.dart` is bloated (536 LOC), mixing CLI run loops, temp-file wrapper script generation, legacy RegExp text-parsing, and flavor-specific subprocess spawners. Additionally, `runner.dart` hardcodes console prints (`logWarning`).
* **Proposed Action**:
  1. Extract wrapper script template generation and legacy regex line-parsing into a separate helper utility file (`lib/src/bench_command/wrapper_helper.dart`).
  2. Inject a custom warning callback/logger to the `BenchmarkRunner` instead of using hardcoded standard prints.
* **Our Opinion / Next Steps**: **Partially Agree (P2).** Decoupling code generation and legacy text parsing into their own files is an excellent architectural clean-up that will reduce the primary spawner's size by 50%. However, keeping standard printing inside the runner as a default behavior is practical for developer out-of-the-box experience; we can support an optional logger parameter in `RunnerConfig`.
