// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:cli_config/cli_config.dart';
import 'package:test/test.dart';

void main() {
  test('getOptionalStringList', () {
    const path1 = 'path/in/cli_arguments/';
    const path2 = 'path/in/cli_arguments_2/';
    const path3 = 'path/in/environment/';
    const path4 = 'path/in/environment_2/';
    const path5 = 'path/in/config_file/';
    const path6 = 'path/in/config_file_2/';
    final config = Config(
      cliDefines: [
        'build.out_dir=$path1',
        'build.out_dir=$path2',
      ],
      environment: {
        'BUILD__OUT_DIR': '$path3:$path4',
      },
      fileContents: jsonEncode(
        {
          'build': {
            'out_dir': [
              path5,
              path6,
            ],
          }
        },
      ),
    );

    {
      final result = config.getOptionalStringList(
        'build.out_dir',
        combineAllConfigs: true,
        splitEnvironmentPattern: ':',
      );
      expect(result, [path1, path2, path3, path4, path5, path6]);
    }

    {
      final result = config.getOptionalStringList(
        'build.out_dir',
        combineAllConfigs: false,
        splitEnvironmentPattern: ':',
      );
      expect(result, [path1, path2]);
    }
  });

  test('getOptionalString cli precedence', () {
    const path1 = 'path/in/cli_arguments/';
    const path2 = 'path/in/environment/';
    const path3 = 'path/in/config_file/';
    final config = Config(
      cliDefines: [
        'build.out_dir=$path1',
      ],
      environment: {
        'BUILD__OUT_DIR': path2,
      },
      fileContents: jsonEncode(
        {
          'build': {
            'out_dir': path3,
          }
        },
      ),
    );

    final result = config.getOptionalString(
      'build.out_dir',
    );
    expect(result, path1);
  });

  test('getOptionalString environment precedence', () {
    const path2 = 'path/in/environment/';
    const path3 = 'path/in/config_file/';
    final config = Config(
      cliDefines: [],
      environment: {
        'BUILD__OUT_DIR': path2,
      },
      fileContents: jsonEncode(
        {
          'build': {
            'out_dir': path3,
          }
        },
      ),
    );

    final result = config.getOptionalString(
      'build.out_dir',
    );
    expect(result, path2);
  });

  test('getOptionalString config file', () {
    const path3 = 'path/in/config_file/';
    final config = Config(
      cliDefines: [],
      environment: {},
      fileContents: jsonEncode(
        {
          'build': {
            'out_dir': path3,
          }
        },
      ),
    );

    final result = config.getOptionalString(
      'build.out_dir',
    );
    expect(result, path3);
  });

  test('getOptionalBool define', () {
    final config = Config(
      cliDefines: ['my_bool=true'],
    );

    expect(config.getOptionalBool('my_bool'), true);
  });

  test('getOptionalBool environment', () {
    final config = Config(
      environment: {
        'MY_BOOL': 'true',
      },
    );

    expect(config.getOptionalBool('my_bool'), true);
  });

  test('getOptionalBool  file', () {
    final config = Config(
      fileContents: jsonEncode(
        {'my_bool': true},
      ),
    );

    expect(config.getOptionalBool('my_bool'), true);
  });

  test('Read file and parse CLI args', () async {
    final temp = await Directory.systemTemp.createTemp();
    final configFile = File.fromUri(temp.uri.resolve('config.yaml'));
    await configFile.writeAsString(jsonEncode(
      {
        'build': {
          'out_dir': 'path/in/config_file/',
        }
      },
    ));
    final config = await Config.fromArgs(
      args: [
        '--config',
        configFile.path,
        '-Dbuild.out_dir=path/in/cli_arguments/',
      ],
      environment: {
        'BUILD__OUT_DIR': 'path/in/environment',
      },
    );

    final result = config.getOptionalString('build.out_dir');
    expect(result, 'path/in/cli_arguments/');
  });

  test('Resolve config file path relative to config file', () async {
    final temp = await Directory.systemTemp.createTemp();
    final tempUri = temp.uri;
    final configUri = tempUri.resolve('config.yaml');
    final configFile = File.fromUri(configUri);
    const relativePath = 'path/in/config_file/';
    final resolvedPath = configUri.resolve(relativePath);

    await configFile.writeAsString(jsonEncode(
      {
        'build': {
          'out_dir': relativePath,
        }
      },
    ));
    final config = await Config.fromArgs(
      args: [
        '--config',
        configFile.path,
      ],
    );

    final result = config.getOptionalPath('build.out_dir');
    expect(result!.path, resolvedPath.path);
  });

  test('provide pre-parsed config', () {
    const path3 = 'path/in/config_file/';
    final config = Config(
      cliDefines: [],
      environment: {},
      fileParsed: {
        'build': {
          'out_dir': path3,
        }
      },
    );

    final result = config.getOptionalString('build.out_dir');
    expect(result, path3);
  });

  test('path exists', () async {
    await _inTempDir((tempUri) async {
      final tempFileUri = tempUri.resolve('file.ext');
      await File.fromUri(tempFileUri).create();
      final nonExistUri = tempUri.resolve('foo.ext');
      final config = Config(
        cliDefines: [],
        environment: {},
        fileParsed: {
          'build': {
            'out_dir': tempUri.path,
            'file': tempFileUri.path,
            'non_exist': nonExistUri.path
          }
        },
      );

      final result = config.getOptionalPath('build.out_dir', mustExist: true);
      expect(result, tempUri);
      final result2 = config.getOptionalPath('build.file', mustExist: true);
      expect(result2, tempFileUri);
      expect(
        () => config.getOptionalPath('build.non_exist', mustExist: true),
        throwsFormatException,
      );
    });
  });

  test('wrong CLI key format', () {
    expect(
      () => Config(cliDefines: ['CAPITALIZED=value']),
      throwsFormatException,
    );
  });

  test('CLI two values when expecting one', () {
    final config = Config(cliDefines: ['key=value', 'key=value2']);
    expect(
      () => config.getString('key'),
      throwsFormatException,
    );
  });

  test('CLI split stringlist', () {
    final config = Config(cliDefines: ['key=value;value2']);
    final value = config.getOptionalStringList('key', splitCliPattern: ';');
    expect(value, ['value', 'value2']);
  });

  test('CLI path', () {
    final uri = Uri.file('some/path.ext');
    final config = Config(cliDefines: ['key=${uri.path}']);
    final value = config.getOptionalPath('key');
    expect(value, uri);
  });

  test('CLI path list', () {
    final uri = Uri.file('some/path.ext');
    final uri2 = Uri.file('some/directory/');
    final config = Config(cliDefines: ['key=${uri.path}:${uri2.path}']);
    final value = config.getOptionalPathList('key', splitCliPattern: ':');
    expect(value, [uri, uri2]);
  });

  test('toString', () {
    final config = Config(
      cliDefines: ['key=foo'],
      environment: {'key': 'bar'},
      fileParsed: {'key': 'baz'},
    );
    config.toString();
  });

  test('Config ArgumentError', () {
    expect(
      () => Config(
        fileParsed: {'key': 'baz'},
        fileContents: "{'key': 'baz'}",
      ),
      throwsArgumentError,
    );
  });
  test('Missing nonullable throws FormatException', () {
    final config = Config();
    expect(() => config.getBool('key'), throwsFormatException);
    expect(() => config.getString('key'), throwsFormatException);
    expect(() => config.getPath('key'), throwsFormatException);
  });

  test('getString not validValue throws FormatException', () {
    final config = Config(environment: {'foo': 'bar'});
    expect(
      () => config.getString('foo', validValues: ['not_bar']),
      throwsFormatException,
    );
  });

  test('getFileValue structured data', () {
    final config = Config(fileParsed: {
      'key': {'some': 'map'}
    });
    final value = config.getFileValue<Map<dynamic, dynamic>>('key');
    expect(value, {'some': 'map'});
  });

  test('environment split stringlist', () {
    final config = Config(environment: {'key': 'value;value2'});
    final value =
        config.getOptionalStringList('key', splitEnvironmentPattern: ';');
    expect(value, ['value', 'value2']);
  });

  test('environment non split stringlist', () {
    final config = Config(environment: {'key': 'value'});
    final value = config.getOptionalStringList('key');
    expect(value, ['value']);
  });

  test('environment path', () {
    final uri = Uri.file('some/path.ext');
    final config = Config(environment: {'key': uri.path});
    final value = config.getOptionalPath('key');
    expect(value, uri);
  });

  test('environment path list', () {
    final uri = Uri.file('some/path.ext');
    final uri2 = Uri.file('some/directory/');
    final config = Config(environment: {'key': '${uri.path}:${uri2.path}'});
    final value =
        config.getOptionalPathList('key', splitEnvironmentPattern: ':');
    expect(value, [uri, uri2]);
  });

  test('Unexpected config file contents', () {
    expect(() => Config(fileContents: 'asdf'), throwsFormatException);
    expect(() => Config(fileContents: "['asdf']"), throwsFormatException);
    expect(
      () => Config(fileContents: '''foo:
  bar:
    WRONGKEY:
      1
'''),
      throwsFormatException,
    );
  });

  test('file config try to access object as wrong type', () {
    final config = Config(fileContents: '''foo:
  bar:
    true
''');
    expect(config.getBool('foo.bar'), true);
    expect(() => config.getBool('foo.bar.baz'), throwsFormatException);
    expect(() => config.getString('foo.bar'), throwsFormatException);
  });

  test('file config path list unresolved', () {
    final uri = Uri.file('some/path.ext');
    final uri2 = Uri.file('some/directory/');
    final config = Config(fileParsed: {
      'key': [uri.path, uri2.path]
    });
    final value = config.getOptionalPathList('key', resolveFileUri: false);
    expect(value, [uri, uri2]);
  });

  test('file config path list resolved', () {
    final configUri = Uri.file('path/to/config.json');
    final uri = Uri.file('some/path.ext');
    final uri2 = Uri.file('some/directory/');
    final config = Config(
      fileSourceUri: configUri,
      fileParsed: {
        'key': [uri.path, uri2.path]
      },
    );
    final value = config.getOptionalPathList('key', resolveFileUri: true);
    expect(value, [configUri.resolveUri(uri), configUri.resolveUri(uri2)]);
  });
}

const keepTempKey = 'KEEP_TEMPORARY_DIRECTORIES';

Future<void> _inTempDir(
  Future<void> Function(Uri tempUri) fun, {
  String? prefix,
}) async {
  final tempDir = await Directory.systemTemp.createTemp(prefix);
  try {
    await fun(tempDir.uri);
  } finally {
    if (!Platform.environment.containsKey(keepTempKey) ||
        Platform.environment[keepTempKey]!.isEmpty) {
      await tempDir.delete(recursive: true);
    }
  }
}
