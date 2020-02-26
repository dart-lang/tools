// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: prefer_expression_function_bodies

part of 'dependency.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SdkDependency _$SdkDependencyFromJson(Map json) {
  return $checkedNew('SdkDependency', json, () {
    $checkKeys(json,
        requiredKeys: const ['sdk'], disallowNullValues: const ['sdk']);
    final val = SdkDependency(
      $checkedConvert(json, 'sdk', (v) => v as String),
      version: $checkedConvert(
          json, 'version', (v) => _constraintFromString(v as String)),
    );
    return val;
  });
}

GitDependency _$GitDependencyFromJson(Map json) {
  return $checkedNew('GitDependency', json, () {
    $checkKeys(json,
        requiredKeys: const ['url'], disallowNullValues: const ['url']);
    final val = GitDependency(
      $checkedConvert(json, 'url', (v) => parseGitUri(v as String)),
      $checkedConvert(json, 'ref', (v) => v as String),
      $checkedConvert(json, 'path', (v) => v as String),
    );
    return val;
  });
}

HostedDependency _$HostedDependencyFromJson(Map json) {
  return $checkedNew('HostedDependency', json, () {
    $checkKeys(json,
        allowedKeys: const ['version', 'hosted'],
        disallowNullValues: const ['hosted']);
    final val = HostedDependency(
      version: $checkedConvert(
          json, 'version', (v) => _constraintFromString(v as String)),
      hosted: $checkedConvert(
          json, 'hosted', (v) => v == null ? null : HostedDetails.fromJson(v)),
    );
    return val;
  });
}

HostedDetails _$HostedDetailsFromJson(Map json) {
  return $checkedNew('HostedDetails', json, () {
    $checkKeys(json,
        allowedKeys: const ['name', 'url'],
        requiredKeys: const ['name'],
        disallowNullValues: const ['name', 'url']);
    final val = HostedDetails(
      $checkedConvert(json, 'name', (v) => v as String),
      $checkedConvert(json, 'url', (v) => parseGitUri(v as String)),
    );
    return val;
  });
}
