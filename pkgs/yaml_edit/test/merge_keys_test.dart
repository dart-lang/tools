// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

void main() {
  group('parseAt with merge keys', () {
    test('resolves keys through single <<: *anchor', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
  retries: 3
service:
  <<: *defaults
''');

      expect(doc.parseAt(['service', 'timeout']).value, equals(30));
      expect(doc.parseAt(['service', 'retries']).value, equals(3));
    });

    test('explicit key overrides merged key', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
  retries: 3
service:
  <<: *defaults
  timeout: 10
''');

      expect(doc.parseAt(['service', 'timeout']).value, equals(10));
      expect(doc.parseAt(['service', 'retries']).value, equals(3));
    });

    test('resolves keys through multi-merges <<: [*m1, *m2] with precedence',
        () {
      final doc = YamlEditor('''
d1: &d1
  a: 1
  b: 2
d2: &d2
  b: 20
  c: 30
service:
  <<: [*d1, *d2]
''');

      expect(doc.parseAt(['service', 'a']).value, equals(1));
      expect(doc.parseAt(['service', 'b']).value, equals(2));
      expect(doc.parseAt(['service', 'c']).value, equals(30));
    });

    test('resolves keys through chained merges', () {
      final doc = YamlEditor('''
base: &base
  port: 8080
mid: &mid
  <<: *base
  timeout: 30
service:
  <<: *mid
''');

      expect(doc.parseAt(['service', 'port']).value, equals(8080));
      expect(doc.parseAt(['service', 'timeout']).value, equals(30));
    });

    test('throws PathError or invokes orElse on missing key', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
service:
  <<: *defaults
''');

      expect(() => doc.parseAt(['service', 'non_existent']), throwsPathError);
      final fallback = doc.parseAt(
        ['service', 'non_existent'],
        orElse: () => wrapAsYamlNode('default_val'),
      );
      expect(fallback.value, equals('default_val'));
    });

    test('resolves keys in flow style map and flow list', () {
      final doc = YamlEditor('''
d1: &d1 {a: 1, b: 2}
d2: &d2 {b: 20, c: 30}
service: {<<: [*d1, *d2]}
''');

      expect(doc.parseAt(['service', 'a']).value, equals(1));
      expect(doc.parseAt(['service', 'b']).value, equals(2));
      expect(doc.parseAt(['service', 'c']).value, equals(30));
    });
  });

  group('AliasBehavior.disallow', () {
    test('throws AliasException on merged key update', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
service:
  <<: *defaults
''');

      expect(
          () => doc.update(['service', 'timeout'], 45), throwsAliasException);
    });

    test('throws AliasException on merged key remove', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
service:
  <<: *defaults
''');

      expect(() => doc.remove(['service', 'timeout']), throwsAliasException);
    });

    test('throws AliasException on nested merged path update and remove', () {
      final doc = YamlEditor('''
defaults: &defaults
  db:
    port: 5432
service:
  <<: *defaults
''');

      expect(() => doc.update(['service', 'db', 'port'], 5433),
          throwsAliasException);
      expect(() => doc.remove(['service', 'db', 'port']), throwsAliasException);
    });

    test('allows mutating explicit non-merged key in map', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
service:
  <<: *defaults
  timeout: 10
''');

      doc.update(['service', 'timeout'], 20);
      expect(doc.parseAt(['service', 'timeout']).value, equals(20));
      expect(doc.parseAt(['defaults', 'timeout']).value, equals(30));
    });

    test('allows removing explicit non-merged key in map', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
service:
  <<: *defaults
  local_key: 100
''');

      doc.remove(['service', 'local_key']);
      expect((doc.parseAt(['service']) as YamlMap).containsKey('local_key'),
          isFalse);
    });

    test('allows adding completely new key to map with merge key', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
service:
  <<: *defaults
''');

      doc.update(['service', 'new_key'], 'custom');
      expect(doc.parseAt(['service', 'new_key']).value, equals('custom'));
      expect(doc.parseAt(['defaults', 'timeout']).value, equals(30));
    });

    test('flow style map behavior under disallow', () {
      final doc = YamlEditor('''
defaults: &defaults {timeout: 30}
service: {<<: *defaults, local_key: 1}
''');

      expect(
          () => doc.update(['service', 'timeout'], 45), throwsAliasException);
      expect(() => doc.remove(['service', 'timeout']), throwsAliasException);

      doc.update(['service', 'local_key'], 2);
      expect(doc.parseAt(['service', 'local_key']).value, equals(2));

      doc.update(['service', 'new_key'], 3);
      expect(doc.parseAt(['service', 'new_key']).value, equals(3));
    });
  });

  group('AliasBehavior.reference', () {
    test('redirects merged key update to anchor template', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
service1:
  <<: *defaults
service2:
  <<: *defaults
''', aliasBehavior: AliasBehavior.reference);

      doc.update(['service1', 'timeout'], 45);
      expect(doc.parseAt(['defaults', 'timeout']).value, equals(45));
      expect(doc.parseAt(['service1', 'timeout']).value, equals(45));
      expect(doc.parseAt(['service2', 'timeout']).value, equals(45));
      expect(doc.toString(), equals('''
defaults: &defaults
  timeout: 45
service1:
  <<: *defaults
service2:
  <<: *defaults
'''));
    });

    test('redirects merged key remove to anchor template', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
  retries: 3
service1:
  <<: *defaults
service2:
  <<: *defaults
''', aliasBehavior: AliasBehavior.reference);

      doc.remove(['service1', 'retries']);
      expect((doc.parseAt(['defaults']) as YamlMap).containsKey('retries'),
          isFalse);
      expect((doc.parseAt(['service1']) as YamlMap).containsKey('retries'),
          isFalse);
      expect((doc.parseAt(['service2']) as YamlMap).containsKey('retries'),
          isFalse);
      expect(doc.toString(), equals('''
defaults: &defaults
  timeout: 30
service1:
  <<: *defaults
service2:
  <<: *defaults
'''));
    });

    test('preserves explicit overrides without touching anchor', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
service:
  <<: *defaults
  timeout: 10
''', aliasBehavior: AliasBehavior.reference);

      doc.update(['service', 'timeout'], 20);
      expect(doc.parseAt(['defaults', 'timeout']).value, equals(30));
      expect(doc.parseAt(['service', 'timeout']).value, equals(20));

      doc.remove(['service', 'timeout']);
      expect(doc.parseAt(['service', 'timeout']).value, equals(30));
      expect(doc.parseAt(['defaults', 'timeout']).value, equals(30));
    });

    test('redirects nested merged property mutation to anchor template', () {
      final doc = YamlEditor('''
defaults: &defaults
  db:
    port: 5432
    host: localhost
service:
  <<: *defaults
''', aliasBehavior: AliasBehavior.reference);

      doc.update(['service', 'db', 'port'], 5433);
      expect(doc.parseAt(['defaults', 'db', 'port']).value, equals(5433));
      expect(doc.parseAt(['service', 'db', 'port']).value, equals(5433));
    });

    test('multi-merge precedence with <<: [*a, *b]', () {
      final doc = YamlEditor('''
d1: &d1
  timeout: 30
  port: 8080
d2: &d2
  port: 9090
  host: localhost
service:
  <<: [*d1, *d2]
''', aliasBehavior: AliasBehavior.reference);

      // Mutating 'port' redirects to d1 because d1 comes first in the sequence
      doc.update(['service', 'port'], 8081);
      expect(doc.parseAt(['d1', 'port']).value, equals(8081));
      expect(doc.parseAt(['d2', 'port']).value, equals(9090));
      expect(doc.parseAt(['service', 'port']).value, equals(8081));

      // Mutating 'host' redirects to d2 since it only exists in d2
      doc.update(['service', 'host'], 'remotehost');
      expect(doc.parseAt(['d2', 'host']).value, equals('remotehost'));
      expect(doc.parseAt(['service', 'host']).value, equals('remotehost'));

      // Removing 'timeout' redirects to d1
      doc.remove(['service', 'timeout']);
      expect((doc.parseAt(['d1']) as YamlMap).containsKey('timeout'), isFalse);
      expect((doc.parseAt(['service']) as YamlMap).containsKey('timeout'),
          isFalse);
    });

    test('chained merge redirection', () {
      final doc = YamlEditor('''
base: &base
  port: 8080
mid: &mid
  <<: *base
  timeout: 30
service:
  <<: *mid
''', aliasBehavior: AliasBehavior.reference);

      doc.update(['service', 'port'], 9090);
      expect(doc.parseAt(['base', 'port']).value, equals(9090));
      expect(doc.parseAt(['mid', 'port']).value, equals(9090));
      expect(doc.parseAt(['service', 'port']).value, equals(9090));
    });

    test('flow style map redirection under reference', () {
      final doc = YamlEditor('''
defaults: &defaults {timeout: 30, retries: 3}
service: {<<: *defaults}
''', aliasBehavior: AliasBehavior.reference);

      doc.update(['service', 'timeout'], 45);
      expect(doc.parseAt(['defaults', 'timeout']).value, equals(45));
      expect(doc.parseAt(['service', 'timeout']).value, equals(45));

      doc.remove(['service', 'retries']);
      expect((doc.parseAt(['defaults']) as YamlMap).containsKey('retries'),
          isFalse);
      expect((doc.parseAt(['service']) as YamlMap).containsKey('retries'),
          isFalse);
    });
  });

  group('AliasBehavior.copyOnWrite', () {
    test('adds explicit override to target map without mutating template', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
service1:
  <<: *defaults
service2:
  <<: *defaults
''', aliasBehavior: AliasBehavior.copyOnWrite);

      doc.update(['service1', 'timeout'], 45);
      expect(doc.parseAt(['defaults', 'timeout']).value, equals(30));
      expect(doc.parseAt(['service1', 'timeout']).value, equals(45));
      expect(doc.parseAt(['service2', 'timeout']).value, equals(30));
      expect(doc.toString(), equals('''
defaults: &defaults
  timeout: 30
service1:
  <<: *defaults
  timeout: 45
service2:
  <<: *defaults
'''));
    });

    test('nested merged map materialization', () {
      final doc = YamlEditor('''
defaults: &defaults
  db:
    port: 5432
    host: localhost
service1:
  <<: *defaults
service2:
  <<: *defaults
''', aliasBehavior: AliasBehavior.copyOnWrite);

      doc.update(['service1', 'db', 'port'], 5433);
      expect(doc.parseAt(['defaults', 'db', 'port']).value, equals(5432));
      expect(doc.parseAt(['service1', 'db', 'port']).value, equals(5433));
      expect(
          doc.parseAt(['service1', 'db', 'host']).value, equals('localhost'));
      expect(doc.parseAt(['service2', 'db', 'port']).value, equals(5432));
      expect(
          doc.parseAt(['service2', 'db', 'host']).value, equals('localhost'));

      expect(doc.toString(), equals('''
defaults: &defaults
  db:
    port: 5432
    host: localhost
service1:
  <<: *defaults
  db:
    port: 5433
    host: localhost
service2:
  <<: *defaults
'''));
    });

    test('deeply nested merged map materialization', () {
      final doc = YamlEditor('''
defaults: &defaults
  level1:
    level2:
      value: 10
service:
  <<: *defaults
''', aliasBehavior: AliasBehavior.copyOnWrite);

      doc.update(['service', 'level1', 'level2', 'value'], 20);
      expect(doc.parseAt(['defaults', 'level1', 'level2', 'value']).value,
          equals(10));
      expect(doc.parseAt(['service', 'level1', 'level2', 'value']).value,
          equals(20));
    });

    test('removing explicit override restores inherited anchor value', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
service:
  <<: *defaults
  timeout: 45
''', aliasBehavior: AliasBehavior.copyOnWrite);

      expect(doc.parseAt(['service', 'timeout']).value, equals(45));
      doc.remove(['service', 'timeout']);
      expect(doc.parseAt(['service', 'timeout']).value, equals(30));
      expect(doc.parseAt(['defaults', 'timeout']).value, equals(30));
      expect(doc.toString(), equals('''
defaults: &defaults
  timeout: 30
service:
  <<: *defaults
'''));
    });

    test('removing non-overridden inherited key throws PathError', () {
      final doc = YamlEditor('''
defaults: &defaults
  timeout: 30
service:
  <<: *defaults
''', aliasBehavior: AliasBehavior.copyOnWrite);

      expect(() => doc.remove(['service', 'timeout']), throwsPathError);
      expect(doc.parseAt(['service', 'timeout']).value, equals(30));
    });

    test('flow style map behavior under copyOnWrite', () {
      final doc = YamlEditor('''
defaults: &defaults {timeout: 30, port: 8080}
service: {<<: *defaults}
''', aliasBehavior: AliasBehavior.copyOnWrite);

      doc.update(['service', 'timeout'], 45);
      expect(doc.parseAt(['defaults', 'timeout']).value, equals(30));
      expect(doc.parseAt(['service', 'timeout']).value, equals(45));
      expect(doc.parseAt(['service', 'port']).value, equals(8080));

      doc.remove(['service', 'timeout']);
      expect(doc.parseAt(['service', 'timeout']).value, equals(30));
    });
  });

  group('Advanced and Edge Case Merge Keys', () {
    test('deeply nested merge keys under copyOnWrite (3 levels)', () {
      final doc = YamlEditor(
        '''
defaults: &defaults
  server:
    security:
      tls:
        enabled: true
        cert: /etc/ssl/cert.pem
service:
  <<: *defaults
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(
        ['service', 'server', 'security', 'tls', 'cert'],
        '/new/cert.pem',
      );
      expect(
        doc.parseAt(['service', 'server', 'security', 'tls', 'cert']).value,
        equals('/new/cert.pem'),
      );
      expect(
        doc.parseAt(['defaults', 'server', 'security', 'tls', 'cert']).value,
        equals('/etc/ssl/cert.pem'),
      );
    });

    test('combining direct alias and merge key under copyOnWrite', () {
      final doc = YamlEditor(
        '''
.default_env: &default_env
  NODE_ENV: production
  LOG_LEVEL: info

.job_template: &job_template
  <<: *default_env
  timeout: 30

deploy_job: *job_template
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['deploy_job', 'timeout'], 45);
      expect(doc.parseAt(['deploy_job', 'timeout']).value, equals(45));
      expect(doc.parseAt(['.job_template', 'timeout']).value, equals(30));

      doc.update(['deploy_job', 'LOG_LEVEL'], 'debug');
      expect(doc.parseAt(['deploy_job', 'LOG_LEVEL']).value, equals('debug'));
      expect(doc.parseAt(['.default_env', 'LOG_LEVEL']).value, equals('info'));
    });

    test('multi-merge precedence with shadowing under reference', () {
      final doc = YamlEditor(
        '''
first: &first
  timeout: 30
  retry: 2
second: &second
  timeout: 60
  rate_limit: 100
service:
  <<: [*first, *second]
''',
        aliasBehavior: AliasBehavior.reference,
      );

      expect(doc.parseAt(['service', 'timeout']).value, equals(30));
      doc.update(['service', 'timeout'], 45);
      expect(doc.parseAt(['first', 'timeout']).value, equals(45));
      expect(doc.parseAt(['second', 'timeout']).value, equals(60));

      doc.update(['service', 'rate_limit'], 200);
      expect(doc.parseAt(['second', 'rate_limit']).value, equals(200));
    });

    test('resiliency to null or non-map merge keys', () {
      final doc = YamlEditor(
        '''
service1:
  <<: null
  name: s1
service2:
  <<: "not a map"
  name: s2
''',
        aliasBehavior: AliasBehavior.reference,
      );

      expect(doc.parseAt(['service1', 'name']).value, equals('s1'));
      expect(() => doc.parseAt(['service1', 'nonexistent']), throwsPathError);
      doc.update(['service1', 'name'], 'updated1');
      expect(doc.parseAt(['service1', 'name']).value, equals('updated1'));

      expect(doc.parseAt(['service2', 'name']).value, equals('s2'));
      doc.update(['service2', 'name'], 'updated2');
      expect(doc.parseAt(['service2', 'name']).value, equals('updated2'));
    });
  });
}
