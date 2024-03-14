[![package:cli_config](https://github.com/dart-lang/tools/actions/workflows/cli_config.yml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/cli_config.yml)
[![Coverage Status](https://coveralls.io/repos/github/dart-lang/tools/badge.svg?branch=main)](https://coveralls.io/github/dart-lang/tools?branch=main)
[![pub package](https://img.shields.io/pub/v/cli_config.svg)](https://pub.dev/packages/cli_config)
[![package publisher](https://img.shields.io/pub/publisher/cli_config.svg)](https://pub.dev/packages/cli_config/publisher)

A library to take config values from configuration files, CLI arguments, and
environment variables.

## Usage

Configuration can be provided from commandline arguments, environment variables,
and configuration files. This library makes these accessible via a uniform API.

Configuration can be provided via the three sources as follows:
1. commandline argument defines as `-Dsome_key=some_value`,
2. environment variables as `SOME_KEY=some_value`, and
3. config files as JSON or YAML as `{'some_key': 'some_value'}`.

The default lookup behavior is that commandline argument defines take precedence
over environment variables, which take precedence over the configuration file.

If a single value is requested from this configuration, the first source that
can provide the value will provide it. For example
`config.string('some_key')` with `{'some_key': 'file_value'}` in the config file
and `-Dsome_key=cli_value` as commandline argument returns
`'cli_value'`. The implication is that you can not remove keys from the
configuration file, only overwrite or append them.

If a list value is requested from this configuration, the values provided by the
various sources can be combined or not. For example
`config.optionalStringList('some_key', combineAllConfigs: true)` returns
`['cli_value', 'file_value']`.

The config is hierarchical in nature, using `.` as the hierarchy separator for
lookup and commandline defines. The hierarchy should be materialized in the JSON
or YAML configuration file. For environment variables `__` is used as hierarchy
separator.

Hierarchical configuration can be provided via the three sources as follows:
1. commandline argument defines as `-Dsome_key.some_nested_key=some_value`,
2. environment variables as `SOME_KEY__SOME_NESTED_KEY=some_value`, and
3. config files as JSON or YAML as
   ```yaml
   some_key:
     some_nested_key:
       some_value
   ```

The config is opinionated on the format of the keys in the sources.
* Command-line argument keys should be lower-cased alphanumeric
  characters or underscores, with `.` for hierarchy.
* Environment variables keys should be upper-cased alphanumeric
   characters or underscores, with `__` for hierarchy.
* Config files keys should be lower-cased alphanumeric
  characters or underscores.

In the API they are made available lower-cased and with underscores, and
`.` as hierarchy separator.

## Example usage

This example creates a configuration which first looks for command-line defines
in the `arguments` list then looks in `Platform.environment`, then looks in any
local configuration file.

```dart
final config = await Config.fromArguments(arguments: arguments);
final pathValue =
    config.optionalPath('my_path', resolveUri: true, mustExist: false);
print(pathValue?.toFilePath());
```
