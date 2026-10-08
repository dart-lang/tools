## 1.3.0-wip

- Track `pubspec.yaml` normal `dependencies` constraints in `ApiSummary` and
  render them in text, JSON, and YAML summaries
  ([#2463](https://github.com/dart-lang/tools/issues/2463)).
- Add `includeImplicitNonPublicMembers` and `includeReferencedTypes` optional
  named constructor parameters to `ApiSummaryCustomizer`.

## 1.2.0

- Sort the primary package entry point (`package:<pkg>/<pkg>.dart`) first and
  `@experimental` public entry points after stable public entry points so shared
  declarations expand in the primary library first and emit `(see above)` in
  secondary or experimental libraries.
- Support relative `packagePath` arguments (such as `'.'`) in `apiSummary`.

## 1.1.0

- Added `expectApiSummaryClean`, `ApiSummaryFormat`, and
  `ApiSummaryVerificationException` to support one-liner golden file verification
  in `dart test` (e.g. `test('api_summary', expectApiSummaryClean);`).
- Added `--write` (`-w`), `--check` (`-c`), and `--output` (`-o`) flags to the
  `api_summary` CLI executable.

## 1.0.0

- Initial stable release.
