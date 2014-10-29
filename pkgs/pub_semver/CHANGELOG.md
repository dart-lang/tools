# 1.1.0

* Add support for the `^` operator for compatible versions according to pub's
  notion of compatibility. `^1.2.3` is equivalent to `>=1.2.3 <2.0.0`; `^0.1.2`
  is equivalent to `>=0.1.2 <0.2.0`.

* Add `Version.nextBreaking`, which returns the next version that introduces
  breaking changes after a given version.

* Add `new VersionConstraint.compatibleWith()`, which returns a range covering
  all versions compatible with a given version.

# 1.0.0

* Initial release.
