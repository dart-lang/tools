## 2.0.0
- Use `extension/<package>/config.yaml` instead of
  `extension/<package>/config.json` for better consistency with other tooling.
- Require that the top-level value in `extension/<package>/config.yaml` is
  always a `Map`, and that the structure can be converted to a JSON equivalent
  structure.

## 1.0.1

- Support optional `packageUri`.
- Improve error messaging for `package_config.json` parsing.
- Update the package description.

## 1.0.0

- Initial version.
