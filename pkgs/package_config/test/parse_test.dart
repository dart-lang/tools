// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:package_config/package_config_types.dart';
import 'package:package_config/src/errors.dart';
import 'package:package_config/src/package_config_json.dart';
import 'package:test/scaffolding.dart';

import 'src/util.dart';

void main() {
  group('package_config.json', () {
    test('valid', () {
      var packageConfigFile = '''
        {
          "configVersion": 2,
          "packages": [
            {
              "name": "foo",
              "rootUri": "file:///foo/",
              "packageUri": "lib/",
              "languageVersion": "2.5",
              "nonstandard": true
            },
            {
              "name": "bar",
              "rootUri": "/bar/",
              "packageUri": "lib/",
              "languageVersion": "9999.9999"
            },
            {
              "name": "baz",
              "rootUri": "../",
              "packageUri": "lib/"
            },
            {
              "name": "noslash",
              "rootUri": "../noslash",
              "packageUri": "lib"
            }
          ],
          "generator": "pub",
          "other": [42]
        }
        ''';
      var config = parsePackageConfigBytes(
        utf8.encode(packageConfigFile),
        Uri.parse('file:///tmp/.dart_tool/file.dart'),
        throwError,
      );
      check(config.version).equals(2);
      check({
        for (var p in config.packages) p.name,
      }).deepEquals({'foo', 'bar', 'baz', 'noslash'});

      check(
        config.resolve(pkg('foo', 'foo.dart')),
      ).equals(Uri.parse('file:///foo/lib/foo.dart'));
      check(
        config.resolve(pkg('bar', 'bar.dart')),
      ).equals(Uri.parse('file:///bar/lib/bar.dart'));
      check(
        config.resolve(pkg('baz', 'baz.dart')),
      ).equals(Uri.parse('file:///tmp/lib/baz.dart'));

      var foo = config['foo'];
      check(foo).isNotNull()
        ..has((p) => p.root, 'root').equals(Uri.parse('file:///foo/'))
        ..has(
          (p) => p.packageUriRoot,
          'packageUriRoot',
        ).equals(Uri.parse('file:///foo/lib/'))
        ..has(
          (p) => p.languageVersion,
          'languageVersion',
        ).equals(LanguageVersion(2, 5))
        ..has((p) => p.extraData, 'extraData')
            .isNotNull()
            .isA<Map<Object?, Object?>>()
            .deepEquals({'nonstandard': true})
        ..has((p) => p.relativeRoot, 'relativeRoot').isFalse();

      var bar = config['bar'];
      check(bar).isNotNull()
        ..has((p) => p.root, 'root').equals(Uri.parse('file:///bar/'))
        ..has(
          (p) => p.packageUriRoot,
          'packageUriRoot',
        ).equals(Uri.parse('file:///bar/lib/'))
        ..has(
          (p) => p.languageVersion,
          'languageVersion',
        ).equals(LanguageVersion(9999, 9999))
        ..has((p) => p.extraData, 'extraData').isNull()
        ..has((p) => p.relativeRoot, 'relativeRoot').isFalse();

      var baz = config['baz'];
      check(baz).isNotNull()
        ..has((p) => p.root, 'root').equals(Uri.parse('file:///tmp/'))
        ..has(
          (p) => p.packageUriRoot,
          'packageUriRoot',
        ).equals(Uri.parse('file:///tmp/lib/'))
        ..has((p) => p.languageVersion, 'languageVersion').isNull()
        ..has((p) => p.relativeRoot, 'relativeRoot').isTrue();

      // No slash after root or package root. One is inserted.
      var noslash = config['noslash'];
      check(noslash).isNotNull()
        ..has((p) => p.root, 'root').equals(Uri.parse('file:///tmp/noslash/'))
        ..has(
          (p) => p.packageUriRoot,
          'packageUriRoot',
        ).equals(Uri.parse('file:///tmp/noslash/lib/'))
        ..has((p) => p.languageVersion, 'languageVersion').isNull()
        ..has((p) => p.relativeRoot, 'relativeRoot').isTrue();

      check(
        config.extraData,
      ).isNotNull().isA<Map<Object?, Object?>>().deepEquals({
        'generator': 'pub',
        'other': [42],
      });
    });

    test('valid other order', () {
      // The ordering in the file is not important.
      var packageConfigFile = '''
        {
          "generator": "pub",
          "other": [42],
          "packages": [
            {
              "languageVersion": "2.5",
              "packageUri": "lib/",
              "rootUri": "file:///foo/",
              "name": "foo"
            },
            {
              "packageUri": "lib/",
              "languageVersion": "9999.9999",
              "rootUri": "/bar/",
              "name": "bar"
            },
            {
              "packageUri": "lib/",
              "name": "baz",
              "rootUri": "../"
            }
          ],
          "configVersion": 2
        }
        ''';
      var config = parsePackageConfigBytes(
        utf8.encode(packageConfigFile),
        Uri.parse('file:///tmp/.dart_tool/file.dart'),
        throwError,
      );
      check(config.version).equals(2);
      check({
        for (var p in config.packages) p.name,
      }).deepEquals({'foo', 'bar', 'baz'});

      check(
        config.resolve(pkg('foo', 'foo.dart')),
      ).equals(Uri.parse('file:///foo/lib/foo.dart'));
      check(
        config.resolve(pkg('bar', 'bar.dart')),
      ).equals(Uri.parse('file:///bar/lib/bar.dart'));
      check(
        config.resolve(pkg('baz', 'baz.dart')),
      ).equals(Uri.parse('file:///tmp/lib/baz.dart'));
      check(
        config.extraData,
      ).isNotNull().isA<Map<Object?, Object?>>().deepEquals({
        'generator': 'pub',
        'other': [42],
      });
    });

    // Check that a few minimal configurations are valid.
    // These form the basis of invalid tests below.
    var cfg = '"configVersion":2';
    var pkgs = '"packages":[]';
    var name = '"name":"foo"';
    var root = '"rootUri":"/foo/"';
    test('minimal', () {
      var config = parsePackageConfigBytes(
        utf8.encode('{$cfg,$pkgs}'),
        Uri.parse('file:///tmp/.dart_tool/file.dart'),
        throwError,
      );
      check(config.version).equals(2);
      check(config.packages).isEmpty();
    });
    test('minimal package', () {
      // A package must have a name and a rootUri, the remaining properties
      // are optional.
      var config = parsePackageConfigBytes(
        utf8.encode('{$cfg,"packages":[{$name,$root}]}'),
        Uri.parse('file:///tmp/.dart_tool/file.dart'),
        throwError,
      );
      check(config.version).equals(2);
      check(config.packages.first.name).equals('foo');
    });

    test('nested packages', () {
      var configBytes = utf8.encode(
        json.encode({
          'configVersion': 2,
          'packages': [
            {'name': 'foo', 'rootUri': '/foo/', 'packageUri': 'lib/'},
            {'name': 'bar', 'rootUri': '/foo/bar/', 'packageUri': 'lib/'},
            {'name': 'baz', 'rootUri': '/foo/bar/baz/', 'packageUri': 'lib/'},
            {'name': 'qux', 'rootUri': '/foo/qux/', 'packageUri': 'lib/'},
          ],
        }),
      );
      var config = parsePackageConfigBytes(
        configBytes,
        Uri.parse('file:///tmp/.dart_tool/file.dart'),
        throwError,
      );
      check(config.version).equals(2);
      check(
        config.packageOf(Uri.parse('file:///foo/lala/lala.dart')),
      ).isNotNull().has((p) => p.name, 'name').equals('foo');
      check(
        config.packageOf(Uri.parse('file:///foo/bar/lala.dart')),
      ).isNotNull().has((p) => p.name, 'name').equals('bar');
      check(
        config.packageOf(Uri.parse('file:///foo/bar/baz/lala.dart')),
      ).isNotNull().has((p) => p.name, 'name').equals('baz');
      check(
        config.packageOf(Uri.parse('file:///foo/qux/lala.dart')),
      ).isNotNull().has((p) => p.name, 'name').equals('qux');
      check(
        config.toPackageUri(Uri.parse('file:///foo/lib/diz')),
      ).equals(Uri.parse('package:foo/diz'));
      check(
        config.toPackageUri(Uri.parse('file:///foo/bar/lib/diz')),
      ).equals(Uri.parse('package:bar/diz'));
      check(
        config.toPackageUri(Uri.parse('file:///foo/bar/baz/lib/diz')),
      ).equals(Uri.parse('package:baz/diz'));
      check(
        config.toPackageUri(Uri.parse('file:///foo/qux/lib/diz')),
      ).equals(Uri.parse('package:qux/diz'));
    });

    test('nested packages 2', () {
      var configBytes = utf8.encode(
        json.encode({
          'configVersion': 2,
          'packages': [
            {'name': 'foo', 'rootUri': '/', 'packageUri': 'lib/'},
            {'name': 'bar', 'rootUri': '/bar/', 'packageUri': 'lib/'},
            {'name': 'baz', 'rootUri': '/bar/baz/', 'packageUri': 'lib/'},
            {'name': 'qux', 'rootUri': '/qux/', 'packageUri': 'lib/'},
          ],
        }),
      );
      var config = parsePackageConfigBytes(
        configBytes,
        Uri.parse('file:///tmp/.dart_tool/file.dart'),
        throwError,
      );
      check(config.version).equals(2);
      check(
        config.packageOf(Uri.parse('file:///lala/lala.dart')),
      ).isNotNull().has((p) => p.name, 'name').equals('foo');
      check(
        config.packageOf(Uri.parse('file:///bar/lala.dart')),
      ).isNotNull().has((p) => p.name, 'name').equals('bar');
      check(
        config.packageOf(Uri.parse('file:///bar/baz/lala.dart')),
      ).isNotNull().has((p) => p.name, 'name').equals('baz');
      check(
        config.packageOf(Uri.parse('file:///qux/lala.dart')),
      ).isNotNull().has((p) => p.name, 'name').equals('qux');
      check(
        config.toPackageUri(Uri.parse('file:///lib/diz')),
      ).equals(Uri.parse('package:foo/diz'));
      check(
        config.toPackageUri(Uri.parse('file:///bar/lib/diz')),
      ).equals(Uri.parse('package:bar/diz'));
      check(
        config.toPackageUri(Uri.parse('file:///bar/baz/lib/diz')),
      ).equals(Uri.parse('package:baz/diz'));
      check(
        config.toPackageUri(Uri.parse('file:///qux/lib/diz')),
      ).equals(Uri.parse('package:qux/diz'));
    });

    test('packageOf is case sensitive on windows', () {
      var configBytes = utf8.encode(
        json.encode({
          'configVersion': 2,
          'packages': [
            {'name': 'foo', 'rootUri': 'file:///C:/Foo/', 'packageUri': 'lib/'},
          ],
        }),
      );
      var config = parsePackageConfigBytes(
        configBytes,
        Uri.parse('file:///C:/tmp/.dart_tool/file.dart'),
        throwError,
      );
      check(config.version).equals(2);
      check(
        config.packageOf(Uri.parse('file:///C:/foo/lala/lala.dart')),
      ).isNull();
      check(
        config.packageOf(Uri.parse('file:///C:/Foo/lala/lala.dart')),
      ).isNotNull().has((p) => p.name, 'name').equals('foo');
    });

    group('invalid', () {
      void testThrows(String name, String source) {
        test(name, () {
          check(
            () => parsePackageConfigBytes(
              utf8.encode(source),
              Uri.parse('file:///tmp/.dart_tool/file.dart'),
              throwError,
            ),
          ).throws<FormatException>();
        });
      }

      void testThrowsContains(
        String name,
        String source,
        String containsString,
      ) {
        test(name, () {
          check(
                () => parsePackageConfigBytes(
                  utf8.encode(source),
                  Uri.parse('file:///tmp/.dart_tool/file.dart'),
                  throwError,
                ),
              )
              .throws<Object>()
              .has((e) => e.toString(), 'toString')
              .contains(containsString);
        });
      }

      testThrows('comment', '# comment\n {$cfg,$pkgs}');
      testThrows('.packages file', 'foo:/foo\n');
      testThrows('no configVersion', '{$pkgs}');
      testThrows('no packages', '{$cfg}');
      group('config version:', () {
        testThrows('null', '{"configVersion":null,$pkgs}');
        testThrows('string', '{"configVersion":"2",$pkgs}');
        testThrows('array', '{"configVersion":[2],$pkgs}');
      });
      group('packages:', () {
        testThrows('null', '{$cfg,"packages":null}');
        testThrows('string', '{$cfg,"packages":"foo"}');
        testThrows('object', '{$cfg,"packages":{}}');
      });
      group('packages entry:', () {
        testThrows('null', '{$cfg,"packages":[null]}');
        testThrows('string', '{$cfg,"packages":["foo"]}');
        testThrows('array', '{$cfg,"packages":[[]]}');
      });
      group('package', () {
        testThrows('no name', '{$cfg,"packages":[{$root}]}');
        group('name:', () {
          testThrows('null', '{$cfg,"packages":[{"name":null,$root}]}');
          testThrows('num', '{$cfg,"packages":[{"name":1,$root}]}');
          testThrows('object', '{$cfg,"packages":[{"name":{},$root}]}');
          testThrows('empty', '{$cfg,"packages":[{"name":"",$root}]}');
          testThrows('one-dot', '{$cfg,"packages":[{"name":".",$root}]}');
          testThrows('two-dot', '{$cfg,"packages":[{"name":"..",$root}]}');
          testThrows(
            "invalid char '\\'",
            '{$cfg,"packages":[{"name":"\\",$root}]}',
          );
          testThrows(
            "invalid char ':'",
            '{$cfg,"packages":[{"name":":",$root}]}',
          );
          testThrows(
            "invalid char ' '",
            '{$cfg,"packages":[{"name":" ",$root}]}',
          );
        });

        testThrows('no root', '{$cfg,"packages":[{$name}]}');
        group('root:', () {
          testThrows('null', '{$cfg,"packages":[{$name,"rootUri":null}]}');
          testThrows('num', '{$cfg,"packages":[{$name,"rootUri":1}]}');
          testThrows('object', '{$cfg,"packages":[{$name,"rootUri":{}}]}');
          testThrows('fragment', '{$cfg,"packages":[{$name,"rootUri":"x/#"}]}');
          testThrows('query', '{$cfg,"packages":[{$name,"rootUri":"x/?"}]}');
          testThrows(
            'package-URI',
            '{$cfg,"packages":[{$name,"rootUri":"package:x/x/"}]}',
          );
        });
        group('package-URI root:', () {
          testThrows(
            'null',
            '{$cfg,"packages":[{$name,$root,"packageUri":null}]}',
          );
          testThrows('num', '{$cfg,"packages":[{$name,$root,"packageUri":1}]}');
          testThrows(
            'object',
            '{$cfg,"packages":[{$name,$root,"packageUri":{}}]}',
          );
          testThrows(
            'fragment',
            '{$cfg,"packages":[{$name,$root,"packageUri":"x/#"}]}',
          );
          testThrows(
            'query',
            '{$cfg,"packages":[{$name,$root,"packageUri":"x/?"}]}',
          );
          testThrows(
            'package: URI',
            '{$cfg,"packages":[{$name,$root,"packageUri":"package:x/x/"}]}',
          );
          testThrows(
            'not inside root',
            '{$cfg,"packages":[{$name,$root,"packageUri":"../other/"}]}',
          );
        });
        group('language version', () {
          testThrows(
            'null',
            '{$cfg,"packages":[{$name,$root,"languageVersion":null}]}',
          );
          testThrows(
            'num',
            '{$cfg,"packages":[{$name,$root,"languageVersion":1}]}',
          );
          testThrows(
            'object',
            '{$cfg,"packages":[{$name,$root,"languageVersion":{}}]}',
          );
          testThrows(
            'empty',
            '{$cfg,"packages":[{$name,$root,"languageVersion":""}]}',
          );
          testThrows(
            'non number.number',
            '{$cfg,"packages":[{$name,$root,"languageVersion":"x.1"}]}',
          );
          testThrows(
            'number.non number',
            '{$cfg,"packages":[{$name,$root,"languageVersion":"1.x"}]}',
          );
          testThrows(
            'non number',
            '{$cfg,"packages":[{$name,$root,"languageVersion":"x"}]}',
          );
          testThrows(
            'one number',
            '{$cfg,"packages":[{$name,$root,"languageVersion":"1"}]}',
          );
          testThrows(
            'three numbers',
            '{$cfg,"packages":[{$name,$root,"languageVersion":"1.2.3"}]}',
          );
          testThrows(
            'leading zero first',
            '{$cfg,"packages":[{$name,$root,"languageVersion":"01.1"}]}',
          );
          testThrows(
            'leading zero second',
            '{$cfg,"packages":[{$name,$root,"languageVersion":"1.01"}]}',
          );
          testThrows(
            'trailing-',
            '{$cfg,"packages":[{$name,$root,"languageVersion":"1.1-1"}]}',
          );
          testThrows(
            'trailing+',
            '{$cfg,"packages":[{$name,$root,"languageVersion":"1.1+1"}]}',
          );
        });
      });
      testThrows(
        'duplicate package name',
        '{$cfg,"packages":[{$name,$root},{$name,"rootUri":"/other/"}]}',
      );
      testThrowsContains(
        // The roots of foo and bar are the same.
        'same roots',
        '{$cfg,"packages":[{$name,$root},{"name":"bar",$root}]}',
        'the same root directory',
      );
      testThrowsContains(
        // The roots of foo and bar are the same.
        'same roots 2',
        '{$cfg,"packages":[{$name,"rootUri":"/"},{"name":"bar","rootUri":"/"}]}',
        'the same root directory',
      );
      testThrowsContains(
        // The root of bar is inside the root of foo,
        // but the package root of foo is inside the root of bar.
        'between root and lib',
        '{$cfg,"packages":['
            '{"name":"foo","rootUri":"/foo/","packageUri":"bar/lib/"},'
            '{"name":"bar","rootUri":"/foo/bar/","packageUri":"baz/lib"}]}',
        'package root of foo is inside the root of bar',
      );

      // This shouldn't be allowed, but for internal reasons it is.
      test('package inside package root', () {
        var config = parsePackageConfigBytes(
          utf8.encode(
            '{$cfg,"packages":['
            '{"name":"foo","rootUri":"/foo/","packageUri":"lib/"},'
            '{"name":"bar","rootUri":"/foo/lib/bar/","packageUri":"lib"}]}',
          ),
          Uri.parse('file:///tmp/.dart_tool/file.dart'),
          throwError,
        );
        check(
          config.packageOf(Uri.parse('file:///foo/lib/bar/lib/lala.dart')),
        ).isNotNull().has((p) => p.name, 'name').equals('foo'); // why not bar?
        check(
          config.toPackageUri(Uri.parse('file:///foo/lib/bar/lib/diz')),
        ).equals(
          Uri.parse('package:foo/bar/lib/diz'),
        ); // why not package:bar/diz?
      });
    });
  });

  group('factories', () {
    void testConfig(String name, PackageConfig config, PackageConfig expected) {
      group(name, () {
        test('structure', () {
          check(config.version).equals(expected.version);
          var expectedPackages = {for (var p in expected.packages) p.name};
          var actualPackages = {for (var p in config.packages) p.name};
          check(actualPackages).deepEquals(expectedPackages);
        });
        for (var package in config.packages) {
          var name = package.name;
          test('package $name', () {
            var expectedPackage = expected[name];
            check(expectedPackage).isNotNull();
            check(because: 'root', package.root).equals(expectedPackage!.root);
            check(
              because: 'package root',
              package.packageUriRoot,
            ).equals(expectedPackage.packageUriRoot);
            check(
              because: 'languageVersion',
              package.languageVersion,
            ).equals(expectedPackage.languageVersion);
          });
        }
      });
    }

    var configText = '''
     {"configVersion": 2, "packages": [
       {
         "name": "foo",
         "rootUri": "foo/",
         "packageUri": "bar/",
         "languageVersion": "1.2"
       }
     ]}
    ''';
    var baseUri = Uri.parse('file:///start/');
    var config = PackageConfig([
      Package(
        'foo',
        Uri.parse('file:///start/foo/'),
        packageUriRoot: Uri.parse('file:///start/foo/bar/'),
        languageVersion: LanguageVersion(1, 2),
      ),
    ]);
    testConfig(
      'string',
      PackageConfig.parseString(configText, baseUri),
      config,
    );
    testConfig(
      'bytes',
      PackageConfig.parseBytes(
        Uint8List.fromList(configText.codeUnits),
        baseUri,
      ),
      config,
    );
    testConfig(
      'json',
      PackageConfig.parseJson(jsonDecode(configText), baseUri),
      config,
    );

    baseUri = Uri.parse('file:///start2/');
    config = PackageConfig([
      Package(
        'foo',
        Uri.parse('file:///start2/foo/'),
        packageUriRoot: Uri.parse('file:///start2/foo/bar/'),
        languageVersion: LanguageVersion(1, 2),
      ),
    ]);
    testConfig(
      'string2',
      PackageConfig.parseString(configText, baseUri),
      config,
    );
    testConfig(
      'bytes2',
      PackageConfig.parseBytes(
        Uint8List.fromList(configText.codeUnits),
        baseUri,
      ),
      config,
    );
    testConfig(
      'json2',
      PackageConfig.parseJson(jsonDecode(configText), baseUri),
      config,
    );
  });
}
