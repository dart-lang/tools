
## download_mime_info.dart

Run `dart tool/download_mime_info.dart` to download the latest mime information
to `third_party/httpd/mime.types`.

## regenerate_tables.dart

Run `dart tool/regenerate_tables.dart` to rebuild the
`lib/src/media_types.g.dart` tables with the latest information from
the `mime.types` table and the additional customizations in
`regenerate_tables.dart`.
