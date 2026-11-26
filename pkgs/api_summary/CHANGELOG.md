## 1.3.1

- Allow non-public types named only by `@internal` or `@visibleForTesting`
  declarations and members in `expectApiSummaryClean` and
  `api_summary --check`.
- Allow `@experimental` declarations and members of the primary barrel to name
  package-owned types that another public library exports.
- Omit parameter default values and constant values that reference
  declarations in another package's `lib/src/` which none of that package's
  reachable public libraries export.

## 1.3.0

- Include `ApiDeclarationStatus.nonPublic` skeleton declarations in
  `ApiSummary.libraries` unconditionally so `api.json` and `api.yaml` match
  `api.txt`.
- Fail `expectApiSummaryClean` and `api_summary --check` by default when
  non-public types leak into public API signatures (including `lib/src/` types
  or package-owned types referenced by the primary barrel without being
  exported by it).
- Add `allowNonPublicTypes` optional named constructor parameter to
  `ApiSummaryCustomizer` and `--allow-non-public-types` flag to `api_summary
  --check`.
- Add `includeImplicitNonPublicMembers` and `includeReferencedTypes` optional
  named constructor parameters to `ApiSummaryCustomizer`.
- Canonicalize the sort order of libraries, declarations, constructors,
  members, named parameters, and named record fields in the `ApiSummary` model
  (`api.json` and `api.yaml`) to match `api.txt`, and sort getter/setter pairs
  ahead of suffixed names (such as `a`, `a=`, `a9`, `a9=`).
- Track parameter `defaultValue` on `ApiParameter` (including inherited `super.`
  defaults) and render non-null public default values in text, JSON, and YAML
  summaries ([#2461](https://github.com/dart-lang/tools/issues/2461)).
- Track `constantValue` on `isConst` `ApiExecutable` getters and render public
  constant values in text, JSON, and YAML summaries
  ([#2462](https://github.com/dart-lang/tools/issues/2462)).
- Resolve `sealed` class `ApiClass.immediateSubtypes` to the public subtype
  frontier (expanding non-public `sealed` intermediates, excluding extension
  types, disambiguating colliding subtype names, and checking primary-barrel
  exports), make `immediateSubtypes` optional in `ApiClass.new`, and add
  `ApiClass.hasNonPublicSubtypes` (rendered as `<non-public>` in `api.txt`)
  when uncovered non-public subtypes exist.
- Track `pubspec.yaml` runtime `dependencies` constraints for external packages
  referenced or re-exported in the public API (including transitive re-exports
  and external typedefs) on `ApiSummary.dependencies`, and render them inline
  on referenced `package:...` library headers in `api.txt` (or under
  `dependencies:` when no inline header exists)
  ([#2463](https://github.com/dart-lang/tools/issues/2463)).
- Normalize caret-equivalent version constraints (such as `>=3.9.0 <4.0.0` to
  `^3.9.0`) in `environment` and `dependencies`.

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
