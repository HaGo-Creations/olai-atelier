// lib/services/download_helper_web.dart
//
// Web-only: triggers a download by creating an anchor and clicking it.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void triggerDownload(String url, {String? suggestedFilename}) {
  final anchor = html.AnchorElement(href: url)
    ..target = '_blank'
    ..rel = 'noopener'
    ..style.display = 'none';
  if (suggestedFilename != null && suggestedFilename.isNotEmpty) {
    anchor.download = suggestedFilename;
  }
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}
