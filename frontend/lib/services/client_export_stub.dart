// lib/services/client_export_stub.dart
//
// Non-web stub. The app is deployed as a web build (GitHub Pages) so these
// paths should never be reached in production. They throw clearly so that any
// accidental non-web usage is caught early during development.

import 'dart:typed_data';

Future<String> clientExportMarkdown({
  required String markdown,
  required String title,
  required String format,
}) =>
    throw UnsupportedError(
        'clientExportMarkdown is only available on web builds.');

void clientExportBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) =>
    throw UnsupportedError(
        'clientExportBytes is only available on web builds.');

String mimeForFormat(String format) => 'application/octet-stream';

String safeFilename(String title) => title
    .replaceAll(RegExp(r'[^\w\s-]'), '')
    .replaceAll(RegExp(r'\s+'), '_')
    .toLowerCase();
