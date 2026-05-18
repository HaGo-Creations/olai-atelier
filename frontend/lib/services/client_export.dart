// lib/services/client_export.dart
//
// Conditional-import facade. On web builds dart.library.html is available so
// client_export_web.dart is used; every other platform gets the stub.

export 'client_export_stub.dart'
    if (dart.library.html) 'client_export_web.dart';
