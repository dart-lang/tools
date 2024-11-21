[![Build Status](https://github.com/dart-lang/tools/actions/workflows/mime.yml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/mime.yml)
[![Pub Package](https://img.shields.io/pub/v/mime.svg)](https://pub.dev/packages/mime)
[![package publisher](https://img.shields.io/pub/publisher/mime.svg)](https://pub.dev/packages/mime/publisher)

Package for working with MIME type definitions and for processing
streams of MIME multipart media types.

## Determining the MIME type for a file

The `MimeTypeResolver` class can be used to determine the MIME type of
a file. It supports both using the extension of the file name and
looking at magic bytes from the beginning of the file.

There is a builtin instance of `MimeTypeResolver` accessible through
the top level function `lookupMimeType`. This builtin instance has
the most common file name extensions and magic bytes registered.

```dart
import 'package:mime/mime.dart';

void main() {
  print(lookupMimeType('test.html'));
  // text/html

  print(lookupMimeType('test', headerBytes: [0xFF, 0xD8]));
  // image/jpeg

  print(lookupMimeType('test.html', headerBytes: [0xFF, 0xD8]));
  // image/jpeg
}
```

You can build you own resolver by creating an instance of
`MimeTypeResolver` and adding file name extensions and magic bytes
using `addExtension` and `addMagicNumber`.

## Processing MIME multipart media types

The class `MimeMultipartTransformer` is used to process a `Stream` of
bytes encoded using a MIME multipart media types encoding. The
transformer provides a new `Stream` of `MimeMultipart` objects each of
which have the headers and the content of each part. The content of a
part is provided as a stream of bytes.

Below is an example showing how to process an HTTP request and print
the length of the content of each part.

```dart
// HTTP request with content type multipart/form-data.
HttpRequest request = ...;
// Determine the boundary form the content type header
String boundary = request.headers.contentType.parameters['boundary'];

// Process the body just calculating the length of each part.
request
    .transform(new MimeMultipartTransformer(boundary))
    .map((part) => part.fold(0, (p, d) => p + d))
    .listen((length) => print('Part with length $length'));
```

## Determining file extension by MIME type

The top level function `extensionFromMime` can be used to determine the
file extension of a given MIME type.

```dart
print(extensionFromMime('text/html'));  // Prints "html".
print(extensionFromMime('image/jpeg'));  // Prints "jpg".
print(extensionFromMime('application/pdf'));  // Prints "pdf".
```
