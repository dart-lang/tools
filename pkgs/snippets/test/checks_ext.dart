// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:snippets/src/diagnostic.dart';
import 'package:snippets/src/markdown/fenced_code_block.dart';
import 'package:snippets/src/markdown/references.dart';
import 'package:snippets/src/update.dart';
import 'package:source_span/source_span.dart';

extension ExampleFormatExceptionChecks on Subject<ExampleFormatException> {
  Subject<String> get message => has((e) => e.message, 'message');
  Subject<SourceSpan?> get span => has((e) => e.span, 'span');
  Subject<int?> get line => has((e) => e.span?.start.line, 'line');
}

extension ExampleWarningChecks on Subject<ExampleWarning> {
  Subject<String> get message => has((w) => w.message, 'message');
  Subject<SourceSpan?> get span => has((w) => w.span, 'span');
}

extension SourceSpanChecks on Subject<SourceSpan> {
  Subject<String> get text => has((s) => s.text, 'text');
  Subject<Uri?> get sourceUrl => has((s) => s.sourceUrl, 'sourceUrl');
  Subject<int> get length => has((s) => s.length, 'length');
  Subject<int> get startOffset => has((s) => s.start.offset, 'start.offset');
  Subject<int> get endOffset => has((s) => s.end.offset, 'end.offset');
}

extension FencedCodeBlockChecks on Subject<FencedCodeBlock> {
  Subject<FileSpan> get openFence => has((b) => b.openFence, 'openFence');
  Subject<FileSpan?> get closeFence => has((b) => b.closeFence, 'closeFence');
  Subject<FileSpan> get contentSpan => has((b) => b.contentSpan, 'contentSpan');
  Subject<String> get infoString => has((b) => b.infoString, 'infoString');
  Subject<String> get fenceChar => has((b) => b.fenceChar, 'fenceChar');
  Subject<int> get fenceLength => has((b) => b.fenceLength, 'fenceLength');
  Subject<String> get linePrefix => has((b) => b.linePrefix, 'linePrefix');
  Subject<String> get newline => has((b) => b.newline, 'newline');
  Subject<String> get content => has((b) => b.content, 'content');
}

extension ExampleReferenceChecks on Subject<ExampleReference> {
  Subject<String> get path => has((r) => r.path, 'path');
  Subject<String?> get region => has((r) => r.region, 'region');
  Subject<String> get reference => has((r) => r.reference, 'reference');
  Subject<Map<String, String>> get options => has((r) => r.options, 'options');
}

extension UpdateResultChecks on Subject<UpdateResult> {
  Subject<String?> get updated => has((r) => r.updated, 'updated');
  Subject<List<ExampleReference>> get stale => has((r) => r.stale, 'stale');
  Subject<List<ExampleFormatException>> get diagnostics =>
      has((r) => r.diagnostics, 'diagnostics');
  Subject<List<ExampleWarning>> get warnings =>
      has((r) => r.warnings, 'warnings');
}
