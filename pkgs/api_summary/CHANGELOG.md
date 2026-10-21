## 1.3.0-wip

- Add `includeImplicitNonPublicMembers` and `includeReferencedTypes` optional
  named constructor parameters to `ApiSummaryCustomizer`.
- Track `pubspec.yaml` runtime `dependencies` constraints for external packages
  referenced in the public API on `ApiSummary.dependencies`, and render them
  inline on referenced `package:...` library headers in `api.txt`
  ([#2463](https://github.com/dart-lang/tools/issues/2463)).

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
