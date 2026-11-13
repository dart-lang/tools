## 1.3.0-wip

- Include `ApiDeclarationStatus.nonPublic` skeleton declarations in `ApiSummary.libraries`
  unconditionally so `api.json` and `api.yaml` match `api.txt`.
- Fail `expectApiSummaryClean` and `api_summary --check` by default when non-public
  types leak into the public API signatures (including types originating from
  `lib/src/` or package-owned types reachable from the primary barrel that are
  not exported by it).
- Add `allowNonPublicTypes` optional named constructor parameter to
  `ApiSummaryCustomizer`.
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
