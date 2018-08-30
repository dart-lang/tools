// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pubspec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Pubspec _$PubspecFromJson(Map json) {
  return $checkedNew('Pubspec', json, () {
    var val = Pubspec($checkedConvert(json, 'name', (v) => v as String),
        version: $checkedConvert(json, 'version',
            (v) => v == null ? null : _versionFromString(v as String)),
        author: $checkedConvert(json, 'author', (v) => v as String),
        authors: $checkedConvert(json, 'authors',
            (v) => (v as List)?.map((e) => e as String)?.toList()),
        environment: $checkedConvert(json, 'environment',
            (v) => v == null ? null : _environmentMap(v as Map)),
        homepage: $checkedConvert(json, 'homepage', (v) => v as String),
        documentation:
            $checkedConvert(json, 'documentation', (v) => v as String),
        description: $checkedConvert(json, 'description', (v) => v as String),
        dependencies:
            $checkedConvert(json, 'dependencies', (v) => parseDeps(v as Map)),
        devDependencies: $checkedConvert(
            json, 'dev_dependencies', (v) => parseDeps(v as Map)),
        dependencyOverrides: $checkedConvert(
            json, 'dependency_overrides', (v) => parseDeps(v as Map)));
    return val;
  }, fieldKeyMap: const {
    'devDependencies': 'dev_dependencies',
    'dependencyOverrides': 'dependency_overrides'
  });
}
