// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';

import 'package:io/io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test('should copy a directory (async)', () async {
    await _create();
    await copyPath(p.join(d.sandbox, _parentDir), p.join(d.sandbox, _copyDir));
    await _validate();
  });

  test('should copy a directory (sync)', () async {
    await _create();
    copyPathSync(p.join(d.sandbox, _parentDir), p.join(d.sandbox, _copyDir));
    await _validate();
  });

  test('should catch an infinite operation', () async {
    await _create();
    expect(
      copyPath(
        p.join(d.sandbox, _parentDir),
        p.join(d.sandbox, _parentDir, 'child'),
      ),
      throwsArgumentError,
    );
  });

  group('links', () {
    const linkTarget = 'link_target';
    const linkSource = 'link_source';
    const linkContent = 'link_content.txt';
    late String targetPath;
    setUp(() async {
      await _create();
      await d
          .dir(linkTarget, [d.file(linkContent, 'original content')]).create();
      targetPath = p.join(d.sandbox, linkTarget);
      await Link(p.join(d.sandbox, _parentDir, linkSource)).create(targetPath);
    });

    test('are shallow copied with deepCopyLinks: false in copyPath', () async {
      await copyPath(
          deepCopyLinks: false,
          p.join(d.sandbox, _parentDir),
          p.join(d.sandbox, _copyDir));

      final expectedLink = Link(p.join(d.sandbox, _copyDir, linkSource));
      expect(await expectedLink.exists(), isTrue);
      expect(await expectedLink.target(), targetPath);
    });

    test('are shallow copied with deepCopyLinks: false in copyPathSync',
        () async {
      copyPathSync(
          deepCopyLinks: false,
          p.join(d.sandbox, _parentDir),
          p.join(d.sandbox, _copyDir));

      final expectedLink = Link(p.join(d.sandbox, _copyDir, linkSource));
      expect(await expectedLink.exists(), isTrue);
      expect(await expectedLink.target(), targetPath);
    });

    test('are deep copied by default in copyPath', () async {
      await copyPath(
          p.join(d.sandbox, _parentDir), p.join(d.sandbox, _copyDir));

      final expectedDir = Directory(p.join(d.sandbox, _copyDir, linkSource));
      final expectedFile =
          File(p.join(d.sandbox, _copyDir, linkSource, linkContent));
      expect(await expectedDir.exists(), isTrue);
      expect(await expectedFile.exists(), isTrue);

      expect(await expectedFile.readAsString(), 'original content',
          reason: 'The file behind the link was copied with invalid content');
      
      await expectedFile.writeAsString('new content');
      final originalFile =
          File(p.join(d.sandbox, _parentDir, linkSource, linkContent));
      expect(await originalFile.readAsString(), 'original content',
          reason: 'The file behind the link should not change');
    });

    test('are deep copied by default in copyPathSync', () async {
      copyPathSync(p.join(d.sandbox, _parentDir), p.join(d.sandbox, _copyDir));

      final expectedDir = Directory(p.join(d.sandbox, _copyDir, linkSource));
      final expectedFile =
          File(p.join(d.sandbox, _copyDir, linkSource, linkContent));
      expect(await expectedDir.exists(), isTrue);
      expect(await expectedFile.exists(), isTrue);

      expect(await expectedFile.readAsString(), 'original content',
          reason: 'The file behind the link was copied with invalid content');
      
      await expectedFile.writeAsString('new content');
      final originalFile =
          File(p.join(d.sandbox, _parentDir, linkSource, linkContent));
      expect(await originalFile.readAsString(), 'original content',
          reason: 'The file behind the link should not change');
    });
  });
}

const _parentDir = 'parent';
const _copyDir = 'copy';

d.DirectoryDescriptor _struct(String dirName) => d.dir(dirName, [
      d.dir('child', [
        d.file('foo.txt'),
      ]),
    ]);

Future<void> _create() => _struct(_parentDir).create();
Future<void> _validate() => _struct(_copyDir).validate();
