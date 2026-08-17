// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml_edit/yaml_edit.dart';

void main() {
  // Using AliasBehavior.reference: modifying a property through an alias
  // reference redirects to the anchor definition and updates all references.
  final referenceEditor = YamlEditor(
    '''
default_job: &job
  timeout: 30
  retries: 2
deploy_job: *job
''',
    aliasBehavior: AliasBehavior.reference,
  );

  referenceEditor.update(['deploy_job', 'retries'], 5);
  print(referenceEditor);
  // Expected Output:
  // default_job: &job
  //   timeout: 30
  //   retries: 5
  // deploy_job: *job

  // Using AliasBehavior.copyOnWrite (Asymmetric COW): modifying a property
  // through an alias reference materializes an independent inline copy without
  // affecting the base template anchor.
  final cowEditor = YamlEditor(
    '''
default_job: &job
  timeout: 30
  retries: 2
deploy_job: *job
''',
    aliasBehavior: AliasBehavior.copyOnWrite,
  );

  cowEditor.update(['deploy_job', 'retries'], 5);
  print(cowEditor);
  // Expected Output:
  // default_job: &job
  //   timeout: 30
  //   retries: 2
  // deploy_job:
  //   timeout: 30
  //   retries: 5
}
