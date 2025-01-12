import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

Future<void> main(List<String> args) async {
  // assume we're being run from the root of the `tools` directory
  final descriptions = SplayTreeMap<String, String>();

  // * Enumerate all packages in `pkgs/`
  for (var directory in Directory(p.join(Directory.current.path, 'pkgs'))
      .listSync()
      .whereType<Directory>()) {
    final pubspecFile = File(p.join(directory.path, 'pubspec.yaml'));
    final pubspec = Pubspec.parse(pubspecFile.readAsStringSync(),
        sourceUrl: pubspecFile.uri);

    assert(p.basename(directory.path) == pubspec.name);

    // * Grab the `description` field from their pubspec files
    descriptions[pubspec.name] = pubspec.description!;
  }

  // * Ensure all packages have a file in `.github/workflows`
  for (var entry in descriptions.entries) {
    final workflowFile = File(p.join('.github/workflows', '${entry.key}.yaml'));

    final workflowYaml =
        loadYaml(workflowFile.readAsStringSync(), sourceUrl: workflowFile.uri)
            as YamlMap;

    final workflowName = workflowYaml['name'] as String;
    // * Ensure each has a name `package:[pkg name]`
    assert(workflowName == 'package:${entry.key}');
  }

  // * Print out the readme table!

  print('''
| Package | Description | Issues | Version |
| --- | --- | --- | --- |''');

  for (var entry in descriptions.entries) {
    final pkgName = entry.key;
    final name = '[$pkgName](pkgs/$pkgName/)';

    /*
     [![package issues](https://img.shields.io/badge/package:bazel_worker-4774bc)](https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Abazel_worker)
     [![pub package](https://img.shields.io/pub/v/bazel_worker.svg)](https://pub.dev/packages/bazel_worker) |

     */

    final issues =
        '[![package issues](https://img.shields.io/badge/package:$pkgName-4774bc)](https://github.com/dart-lang/tools/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3A$pkgName)';
    final version =
        '[![pub package](https://img.shields.io/pub/v/$pkgName.svg)](https://pub.dev/packages/$pkgName)';

    print(['', name, entry.value, issues, version, ''].join(' | ').trim());
  }
}
