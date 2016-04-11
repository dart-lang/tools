// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:protobuf/protobuf.dart';

List<int> protoToDelimitedBuffer(GeneratedMessage message) {
  var buffer = message.writeToBuffer();

  var writer = new CodedBufferWriter();
  writer.writeInt32NoTag(buffer.length);
  writer.writeRawBytes(buffer);

  return writer.toBuffer();
}
