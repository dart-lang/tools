// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:cli_config/cli_config.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('optionalStringList', () {
    const path1 = 'path/in/cli_arguments/';
    const path2 = 'path/in/cli_arguments_2/';
    const path3 = 'path/in/environment/';
    const path4 = 'path/in/environment_2/';
    const path5 = 'path/in/config_file/';
    const path6 = 'path/in/config_file_2/';
    final config = Config.fromConfigFileContents(
      commandLineDefines: [
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
      final result = config.optionalStringList(
        'build.out_dir',
        combineAllConfigs: true,
        splitEnvironmentPattern: ':',
      );
      expect(result, [path1, path2, path3, path4, path5, path6]);
    }

    {
      final result = config.optionalStringList(
        'build.out_dir',
        combineAllConfigs: false,
        splitEnvironmentPattern: ':',
      );
      expect(result, [path1, path2]);
    }
  });

  test('optionalString cli precedence', () {
    const path1 = 'path/in/cli_arguments/';
    const path2 = 'path/in/environment/';
    const path3 = 'path/in/config_file/';
    final config = Config.fromConfigFileContents(
      commandLineDefines: [
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

    final result = config.optionalString(
      'build.out_dir',
    );
    expect(result, path1);
  });

  test('optionalString environment precedence', () {
    const path2 = 'path/in/environment/';
    const path3 = 'path/in/config_file/';
    final config = Config.fromConfigFileContents(
      commandLineDefines: [],
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

    final result = config.optionalString(
      'build.out_dir',
    );
    expect(result, path2);
  });

  test('optionalString config file', () {
    const path3 = 'path/in/config_file/';
    final config = Config.fromConfigFileContents(
      commandLineDefines: [],
      environment: {},
      fileContents: jsonEncode(
        {
          'build': {
            'out_dir': path3,
          }
        },
      ),
    );

    final result = config.optionalString(
      'build.out_dir',
    );
    expect(result, path3);
  });

  test('optionalBool define', () {
    final config = Config(
      commandLineDefines: ['my_bool=true'],
    );

    expect(config.optionalBool('my_bool'), true);
  });

  test('optionalBool environment', () {
    final config = Config(
      environment: {
        'MY_BOOL': 'true',
      },
    );

    expect(config.optionalBool('my_bool'), true);
  });

  test('optionalBool  file', () {
    final config = Config.fromConfigFileContents(
      fileContents: jsonEncode(
        {'my_bool': true},
      ),
    );

    expect(config.optionalBool('my_bool'), true);
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
    final config = await Config.fromArguments(
      arguments: [
        '--config',
        configFile.path,
        '-Dbuild.out_dir=path/in/cli_arguments/',
      ],
      environment: {
        'BUILD__OUT_DIR': 'path/in/environment',
      },
    );

    final result = config.optionalString('build.out_dir');
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

    final config = await Config.fromArguments(
      arguments: [
        '--config',
        configFile.path,
      ],
    );
    final result = config.optionalPath('build.out_dir');
    expect(result!.path, resolvedPath.path);

    final configSync = Config.fromArgumentsSync(
      arguments: [
        '--config',
        configFile.path,
      ],
    );
    final resultSync = configSync.optionalPath('build.out_dir');
    expect(resultSync!.path, resolvedPath.path);
  });

  test('provide pre-parsed config', () {
    const path3 = 'path/in/config_file/';
    final config = Config(
      commandLineDefines: [],
      environment: {},
      fileParsed: {
        'build': {
          'out_dir': path3,
        }
      },
    );

    final result = config.optionalString('build.out_dir');
    expect(result, path3);
  });

  test('path exists', () async {
    await inTempDir((tempUri) async {
      final tempFileUri = tempUri.resolve('file.ext');
      await File.fromUri(tempFileUri).create();
      final nonExistUri = tempUri.resolve('foo.ext');
      final config = Config(
        commandLineDefines: [],
        environment: {},
        fileParsed: {
          'build': {
            'out_dir': tempUri.toFilePath(),
            'file': tempFileUri.toFilePath(),
            'non_exist': nonExistUri.toFilePath(),
          }
        },
      );

      final result = config.optionalPath('build.out_dir', mustExist: true);
      expect(result, tempUri);
      final result2 = config.optionalPath('build.file', mustExist: true);
      expect(result2, tempFileUri);
      expect(
        () => config.optionalPath('build.non_exist', mustExist: true),
        throwsFormatException,
      );
    });
  });

  test('wrong CLI key format', () {
    expect(
      () => Config(commandLineDefines: ['CAPITALIZED=value']),
      throwsFormatException,
    );
  });

  test('CLI two values when expecting one', () {
    final config = Config(commandLineDefines: ['key=value', 'key=value2']);
    expect(
      () => config.string('key'),
      throwsFormatException,
    );
  });

  test('CLI split optionalStringList', () {
    final config = Config(commandLineDefines: ['key=value;value2']);
    final value = config.optionalStringList('key', splitCliPattern: ';');
    expect(value, ['value', 'value2']);
  });

  test('CLI path', () {
    final uri = Uri.file('some/path.ext');
    final config = Config(commandLineDefines: ['key=${uri.path}']);
    final value = config.optionalPath('key');
    expect(value, uri);
  });

  test('CLI path list', () {
    final uri = Uri.file('some/path.ext');
    final uri2 = Uri.file('some/directory/');
    final config = Config(commandLineDefines: ['key=${uri.path}:${uri2.path}']);
    final value = config.optionalPathList('key', splitCliPattern: ':');
    expect(value, [uri, uri2]);
  });

  test('toString', () {
    final config = Config(
      commandLineDefines: ['key=foo'],
      environment: {'key': 'bar'},
      fileParsed: {'key': 'baz'},
    );
    config.toString();
  });

  test('Missing nonullable throws FormatException', () {
    final config = Config.fromConfigFileContents();
    expect(() => config.bool('key'), throwsFormatException);
    expect(() => config.string('key'), throwsFormatException);
    expect(() => config.path('key'), throwsFormatException);
  });

  test('string not validValue throws FormatException', () {
    final config = Config(environment: {'foo': 'bar'});
    expect(
      () => config.string('foo', validValues: ['not_bar']),
      throwsFormatException,
    );
  });

  test('optionalString validValues', () {
    final config = Config();
    expect(config.optionalString('foo', validValues: ['bar']), isNull);
  });

  test('valueOf file source', () {
    final config = Config(fileParsed: {
      'key': {'some': 'map'}
    });
    final value = config.valueOf<Map<dynamic, dynamic>>('key');
    expect(value, {'some': 'map'});
  });

  test('valueOf command line source', () {
    final config = Config(commandLineDefines: [
      'string_key=value',
      'bool_key=true',
      'string_list_key=value1',
      'string_list_key=value2',
    ]);
    expect(config.valueOf<String>('string_key'), 'value');
    expect(config.valueOf<bool>('bool_key'), true);
    expect(
      config.valueOf<List<String>>('string_list_key'),
      ['value1', 'value2'],
    );
  });

  test('environment split optionalStringList', () {
    final config = Config(environment: {'key': 'value;value2'});
    final value =
        config.optionalStringList('key', splitEnvironmentPattern: ';');
    expect(value, ['value', 'value2']);
  });

  test('environment non split optionalStringList', () {
    final config = Config(environment: {'key': 'value'});
    final value = config.optionalStringList('key');
    expect(value, ['value']);
  });

  test('environment path', () {
    final uri = Uri.file('some/path.ext');
    final config = Config(environment: {'key': uri.path});
    final value = config.optionalPath('key');
    expect(value, uri);
  });

  test('environment path list', () {
    final uri = Uri.file('some/path.ext');
    final uri2 = Uri.file('some/directory/');
    final config = Config(environment: {'key': '${uri.path}:${uri2.path}'});
    final value = config.optionalPathList('key', splitEnvironmentPattern: ':');
    expect(value, [uri, uri2]);
  });

  test('Unexpected config file contents', () {
    expect(() => Config.fromConfigFileContents(fileContents: 'asdf'),
        throwsFormatException);
    expect(() => Config.fromConfigFileContents(fileContents: "['asdf']"),
        throwsFormatException);
    expect(
      () => Config.fromConfigFileContents(
          fileContents: '''
WRONGKEY:
  1
'''
              .trim()),
      throwsFormatException,
    );
    expect(
      () => Config.fromConfigFileContents(
          fileContents: '''
1: 'asdf'
'''
              .trim()),
      throwsFormatException,
    );
  });

  test('file config try to access object as wrong type', () {
    final config = Config.fromConfigFileContents(fileContents: '''foo:
  bar:
    true
''');
    expect(config.bool('foo.bar'), true);
    expect(() => config.bool('foo.bar.baz'), throwsFormatException);
    expect(() => config.string('foo.bar'), throwsFormatException);
  });

  test('file config path list unresolved', () {
    final uri = Uri.file('some/path.ext');
    final uri2 = Uri.file('some/directory/');
    final config = Config(fileParsed: {
      'key': [uri.path, uri2.path]
    });
    final value = config.optionalPathList('key', resolveUri: false);
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
    final value = config.optionalPathList('key', resolveUri: true);
    expect(value, [configUri.resolveUri(uri), configUri.resolveUri(uri2)]);
  });

  test('resolveUri in working directory', () {
    final systemTemp = Directory.systemTemp.uri;
    final tempUri = systemTemp.resolve('x/y/z/');

    final relativePath = Uri.file('a/b/c/d.ext');
    final absolutePath = tempUri.resolveUri(relativePath);
    final config = Config(
      commandLineDefines: ['path=${relativePath.path}'],
      workingDirectory: tempUri,
    );

    expect(config.optionalPath('path', mustExist: false, resolveUri: true),
        absolutePath);
  });

  test('ints', () {
    final config = Config(
      commandLineDefines: ['cl=1', 'not_parsable=asdf'],
      environment: {
        'env': '2',
        'not_parsable2': 'asfd',
      },
      fileParsed: {'file': 3},
    );

    expect(config.int('cl'), 1);
    expect(config.optionalInt('env'), 2);
    expect(config.optionalInt('file'), 3);
    expect(config.optionalInt('nothing'), null);
    expect(() => config.optionalInt('not_parsable'), throwsFormatException);
    expect(() => config.optionalInt('not_parsable2'), throwsFormatException);
  });

  test('doubles', () {
    final config = Config(
      commandLineDefines: ['cl=1.1', 'not_parsable=asdf'],
      environment: {
        'env': '2.2',
        'not_parsable2': 'asfd',
      },
      fileParsed: {'file': 3.3},
    );

    expect(config.double('cl'), 1.1);
    expect(config.optionalDouble('env'), 2.2);
    expect(config.optionalDouble('file'), 3.3);
    expect(config.optionalDouble('nothing'), null);
    expect(() => config.optionalDouble('not_parsable'), throwsFormatException);
    expect(() => config.optionalDouble('not_parsable2'), throwsFormatException);
  });

  test('stringList and optionalStringList', () {
    {
      final config = Config(
        fileParsed: {},
      );

      expect(config.optionalStringList('my_list'), null);
      expect(() => config.stringList('my_list'), throwsFormatException);
    }

    {
      final config = Config(
        fileParsed: {'my_list': <String>[]},
      );

      expect(config.optionalStringList('my_list'), <String>[]);
      expect(config.stringList('my_list'), <String>[]);
    }
  });

  test('pathList and optionalPathList', () {
    {
      final config = Config(
        fileParsed: {},
      );

      expect(config.optionalPathList('my_list'), null);
      expect(() => config.pathList('my_list'), throwsFormatException);
    }

    {
      final config = Config(
        fileParsed: {'my_list': <String>[]},
      );

      expect(config.optionalPathList('my_list'), <String>[]);
      expect(config.pathList('my_list'), <String>[]);
    }
  });

  test('non-string key maps', () {
    // This is valid in YAML (not in JSON).
    //
    // Such values cannot be accessed with our hierarchical keys, but they can
    // be accessed with [Config.valueOf].
    final config = Config(
      fileParsed: {
        'my_non_string_key_map': {
          1: 'asdf',
          2: 'foo',
        },
      },
    );

    expect(
      config.valueOf<Map<Object, Object?>>('my_non_string_key_map'),
      {
        1: 'asdf',
        2: 'foo',
      },
    );
  });

  test('null values in maps', () {
    final config = Config(
      fileParsed: {
        'my_non_string_key_map': {
          'x': null,
          'y': 42,
        },
      },
    );

    expect(
      config.valueOf<Map<Object, Object?>>('my_non_string_key_map'),
      {
        'x': null,
        'y': 42,
      },
    );
  });
}
