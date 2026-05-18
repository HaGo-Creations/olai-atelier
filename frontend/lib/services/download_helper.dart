// lib/services/download_helper.dart

import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

void launchDownload(String url, {String? suggestedFilename}) {
  triggerDownload(url, suggestedFilename: suggestedFilename);
}
