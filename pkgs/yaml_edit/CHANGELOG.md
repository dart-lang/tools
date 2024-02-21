## 2.2.0

- Fix inconsistent line endings when inserting maps into a document using `\r\n`.
  ([#65](https://github.com/dart-lang/yaml_edit/issues/65))

- `AliasError` is changed to `AliasException` and exposed in the public API.

  All node-mutating methods on `YamlEditor`, i.e. `update()`, `appendToList()`,
  `prependToList()`, `insertIntoList()`, `spliceList()`, `remove()` will now
  throw an exception instead of an error when encountering an alias on the path
  to modify.

  This allows catching and handling when this is happening.

## 2.1.1

- Require Dart 2.19

## 2.1.0

- **Breaking** `wrapAsYamlNode(value, collectionStyle, scalarStyle)` will apply
  `collectionStyle` and `scalarStyle` recursively when wrapping a children of
  `Map` and `List`.
  While this may change the style of the YAML documents written by applications
  that rely on the old behavior, such YAML documents should still be valid.
  Hence, we hope it is reasonable to make this change in a minor release.
- Fix for cases that can't be encoded correctly with
  `scalarStyle: ScalarStyle.SINGLE_QUOTED`.
- Fix YamlEditor `appendToList` and `insertIntoList` functions inserts new item into next yaml item
  rather than at end of list.
  ([#23](https://github.com/dart-lang/yaml_edit/issues/23))

## 2.0.3

- Updated the value of the pubspec `repository` field.

## 2.0.2

- Fix trailing whitespace after adding new key with block-value to map
  ([#15](https://github.com/dart-lang/yaml_edit/issues/15)).
- Updated `repository` and other meta-data in `pubspec.yaml`.

## 2.0.1

- License changed to BSD, as this package is now maintained by the Dart team.
- Fixed minor lints.

## 2.0.0

- Migrated to null-safety.
- API will no-longer return `null` in-place of a `YamlNode`, instead a
  `YamlNode` with `YamlNode.value == null` should be used. These are easily
  created with `wrapAsYamlNode(null)`.

## 1.0.3

- Fixed bug in adding an empty map as a map value.

## 1.0.2

- Throws an error if the final YAML after edit is not parsable.
- Fixed bug in adding to empty map values, when it is followed by other content.

## 1.0.1

- Updated behavior surrounding list and map removal.
- Fixed bug in dealing with empty values.

## 1.0.0

- Initial release.
