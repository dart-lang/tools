// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dependency.dart';

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

SdkDependency _$SdkDependencyFromJson(Map json) {
  return $checkedNew('SdkDependency', json, () {
    var val = new SdkDependency(
        $checkedConvert(json, 'sdk', (v) => v as String),
        version: $checkedConvert(json, 'version',
            (v) => v == null ? null : _constraintFromString(v as String)));
    return val;
  });
}

GitDependency _$GitDependencyFromJson(Map json) {
  return $checkedNew('GitDependency', json, () {
    $checkKeys(json,
        requiredKeys: const ['url'], disallowNullValues: const ['url']);
    var val = new GitDependency(
        $checkedConvert(
            json, 'url', (v) => v == null ? null : _parseUri(v as String)),
        $checkedConvert(json, 'ref', (v) => v as String),
        $checkedConvert(json, 'path', (v) => v as String));
    return val;
  });
}

HostedDependency _$HostedDependencyFromJson(Map json) {
  return $checkedNew('HostedDependency', json, () {
    var val = new HostedDependency(
        version: $checkedConvert(json, 'version',
            (v) => v == null ? null : _constraintFromString(v as String)),
        hosted: $checkedConvert(json, 'hosted',
            (v) => v == null ? null : new HostedDetails.fromJson(v as Map)));
    return val;
  });
}

HostedDetails _$HostedDetailsFromJson(Map json) {
  return $checkedNew('HostedDetails', json, () {
    var val = new HostedDetails(
        $checkedConvert(json, 'name', (v) => v as String),
        $checkedConvert(json, 'url', (v) => _parseUri(v as String)));
    return val;
  });
}
