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

  test('links are preserved in async copy', () async {
    await _create();
    const linkTarget = 'link_target';
    final targetPath = p.join(d.sandbox, linkTarget);
    const linkSource = 'link_source';
    await d.dir(linkTarget).create();
    await Link(p.join(d.sandbox, _parentDir, linkSource)).create(targetPath);

    await copyPath(p.join(d.sandbox, _parentDir), p.join(d.sandbox, _copyDir));

    final expectedLink = Link(p.join(d.sandbox, _copyDir, linkSource));
    expect(await expectedLink.exists(), isTrue);
    expect(await expectedLink.target(), targetPath);
  });

  test('links are preserved in sync copy', () async {
    await _create();
    const linkTarget = 'link_target';
    final targetPath = p.join(d.sandbox, linkTarget);
    const linkSource = 'link_source';
    await d.dir(linkTarget).create();
    await Link(p.join(d.sandbox, _parentDir, linkSource)).create(targetPath);

    copyPathSync(p.join(d.sandbox, _parentDir), p.join(d.sandbox, _copyDir));

    final expectedLink = Link(p.join(d.sandbox, _copyDir, linkSource));
    expect(await expectedLink.exists(), isTrue);
    expect(await expectedLink.target(), targetPath);
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
