// lib/services/client_export_web.dart
//
// Web-only implementation. Generates real PDF / DOCX bytes entirely in the
// browser (no backend required) and triggers a native file download.
// Imported via client_export.dart's conditional export.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ── Public API ────────────────────────────────────────────────────────────────

/// Generate PDF or DOCX from [markdown] and trigger a browser download.
/// [format] must be 'pdf' or 'docx'. For 'pptx' in mock mode a PDF is
/// generated as a fallback (PPTX requires the real backend).
Future<String> clientExportMarkdown({
  required String markdown,
  required String title,
  required String format,
}) async {
  final Uint8List bytes;
  final String mime;
  final String ext;

  switch (format) {
    case 'pdf':
    case 'pptx': // pptx falls back to PDF when client-side
      bytes = await _buildPdf(markdown, title);
      mime = 'application/pdf';
      ext = 'pdf';
    case 'docx':
      bytes = _buildDocx(markdown, title);
      mime = 'application/vnd.openxmlformats-officedocument'
          '.wordprocessingml.document';
      ext = 'docx';
    default:
      throw UnsupportedError('clientExportMarkdown: unknown format "$format"');
  }

  final filename = '${_safe(title)}.$ext';
  _download(bytes, filename, mime);
  return filename;
}

/// Trigger a browser download from raw bytes (used by HttpApiService after
/// it fetches the file from the Hugging Face backend).
void clientExportBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) =>
    _download(bytes, filename, mimeType);

/// MIME type helper used by HttpApiService.
String mimeForFormat(String format) => switch (format) {
      'pdf' => 'application/pdf',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      _ => 'application/octet-stream',
    };

/// Safe filename stem (no extension).
String safeFilename(String title) => _safe(title);

// ── Internal download helper ──────────────────────────────────────────────────

void _download(Uint8List bytes, String filename, String mime) {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

String _safe(String title) => title
    .replaceAll(RegExp(r'[^\w\s-]'), '')
    .replaceAll(RegExp(r'\s+'), '_')
    .toLowerCase();

// ════════════════════════════════════════════════════════════════════════════
// PDF generation (pure Dart, works in browser)
// ════════════════════════════════════════════════════════════════════════════

Future<Uint8List> _buildPdf(String markdown, String title) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 52),
      build: (ctx) => _markdownToPdfWidgets(markdown),
    ),
  );

  return doc.save();
}

List<pw.Widget> _markdownToPdfWidgets(String markdown) {
  final widgets = <pw.Widget>[];
  final lines = markdown.split('\n');
  int i = 0;

  while (i < lines.length) {
    final line = lines[i];

    if (line.startsWith('# ')) {
      widgets.add(_pdfHeading(line.substring(2).trim(), 22));
    } else if (line.startsWith('## ')) {
      widgets.add(_pdfHeading(line.substring(3).trim(), 17));
    } else if (line.startsWith('### ')) {
      widgets.add(_pdfHeading(line.substring(4).trim(), 14));
    } else if (line.startsWith('- ') || line.startsWith('* ')) {
      widgets.add(_pdfBullet(line.substring(2).trim()));
    } else if (RegExp(r'^\d+\. ').hasMatch(line)) {
      final num = RegExp(r'^\d+').firstMatch(line)!.group(0)!;
      final text = line.replaceFirst(RegExp(r'^\d+\. '), '').trim();
      widgets.add(_pdfNumbered('$num.', text));
    } else if (line.startsWith('> ')) {
      widgets.add(_pdfBlockquote(line.substring(2).trim()));
    } else if (line.startsWith('---') || line.startsWith('***')) {
      widgets.add(pw.Divider(color: PdfColors.grey400));
    } else if (line.trim().isEmpty) {
      widgets.add(pw.SizedBox(height: 4));
    } else {
      widgets.add(_pdfParagraph(line));
    }

    i++;
  }

  return widgets;
}

pw.Widget _pdfHeading(String text, double size) => pw.Padding(
      padding: pw.EdgeInsets.only(top: size * 0.6, bottom: size * 0.3),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold),
      ),
    );

pw.Widget _pdfParagraph(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(text: _inlinePdfSpan(text)),
    );

pw.Widget _pdfBullet(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(left: 12, bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: const pw.TextStyle(fontSize: 11)),
          pw.Expanded(child: pw.RichText(text: _inlinePdfSpan(text))),
        ],
      ),
    );

pw.Widget _pdfNumbered(String num, String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(left: 12, bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$num ',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(child: pw.RichText(text: _inlinePdfSpan(text))),
        ],
      ),
    );

pw.Widget _pdfBlockquote(String text) => pw.Container(
      margin: const pw.EdgeInsets.only(left: 16, bottom: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            left: pw.BorderSide(color: PdfColors.grey400, width: 3)),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey700,
              fontStyle: pw.FontStyle.italic)),
    );

// Inline bold/italic/code spans for PDF
pw.TextSpan _inlinePdfSpan(String text) {
  final spans = <pw.TextSpan>[];
  var remaining = text;

  while (remaining.isNotEmpty) {
    // Strip math dollar signs — render as plain text
    final mathInline = RegExp(r'^\$([^$]+)\$').firstMatch(remaining);
    if (mathInline != null) {
      spans.add(pw.TextSpan(
          text: mathInline.group(1)!,
          style: const pw.TextStyle(fontSize: 11)));
      remaining = remaining.substring(mathInline.end);
      continue;
    }

    final bold = RegExp(r'^\*\*(.+?)\*\*').firstMatch(remaining);
    if (bold != null) {
      spans.add(pw.TextSpan(
          text: bold.group(1)!,
          style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold)));
      remaining = remaining.substring(bold.end);
      continue;
    }

    final italic = RegExp(r'^\*(.+?)\*').firstMatch(remaining);
    if (italic != null) {
      spans.add(pw.TextSpan(
          text: italic.group(1)!,
          style: pw.TextStyle(
              fontSize: 11, fontStyle: pw.FontStyle.italic)));
      remaining = remaining.substring(italic.end);
      continue;
    }

    final code = RegExp(r'^`(.+?)`').firstMatch(remaining);
    if (code != null) {
      spans.add(pw.TextSpan(
          text: code.group(1)!,
          style: const pw.TextStyle(fontSize: 10)));
      remaining = remaining.substring(code.end);
      continue;
    }

    // Plain text up to the next special marker
    final next = RegExp(r'\*\*|\*|`|\$').firstMatch(remaining);
    if (next != null && next.start > 0) {
      spans.add(pw.TextSpan(
          text: remaining.substring(0, next.start),
          style: const pw.TextStyle(fontSize: 11)));
      remaining = remaining.substring(next.start);
    } else if (next == null) {
      spans.add(pw.TextSpan(
          text: remaining, style: const pw.TextStyle(fontSize: 11)));
      remaining = '';
    } else {
      // Unmatched marker — emit one char and continue
      spans.add(pw.TextSpan(
          text: remaining[0], style: const pw.TextStyle(fontSize: 11)));
      remaining = remaining.substring(1);
    }
  }

  return pw.TextSpan(children: spans);
}

// ════════════════════════════════════════════════════════════════════════════
// DOCX generation (ZIP-based OOXML, pure Dart)
// ════════════════════════════════════════════════════════════════════════════

Uint8List _buildDocx(String markdown, String title) {
  final body = _markdownToOoxml(markdown);

  final docXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
$body
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>''';

  final archive = Archive();
  void add(String name, String content) {
    final b = utf8.encode(content);
    archive.addFile(ArchiveFile(name, b.length, b));
  }

  add('[Content_Types].xml', _contentTypesXml());
  add('_rels/.rels', _relsXml());
  add('word/document.xml', docXml);
  add('word/_rels/document.xml.rels', _wordRelsXml());
  add('word/styles.xml', _stylesXml());
  add('word/numbering.xml', _numberingXml());

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String _markdownToOoxml(String markdown) {
  final buf = StringBuffer();
  final lines = markdown.split('\n');

  for (final line in lines) {
    if (line.startsWith('# ')) {
      buf.writeln(_ooxmlHeading(line.substring(2).trim(), 'Heading1'));
    } else if (line.startsWith('## ')) {
      buf.writeln(_ooxmlHeading(line.substring(3).trim(), 'Heading2'));
    } else if (line.startsWith('### ')) {
      buf.writeln(_ooxmlHeading(line.substring(4).trim(), 'Heading3'));
    } else if (line.startsWith('- ') || line.startsWith('* ')) {
      buf.writeln(_ooxmlList(line.substring(2).trim(), numId: '1'));
    } else if (RegExp(r'^\d+\. ').hasMatch(line)) {
      final text = line.replaceFirst(RegExp(r'^\d+\. '), '').trim();
      buf.writeln(_ooxmlList(text, numId: '2'));
    } else if (line.startsWith('> ')) {
      buf.writeln(_ooxmlPara(line.substring(2).trim(),
          style: 'Quote', italic: true));
    } else if (line.trim().isEmpty) {
      buf.writeln(
          '    <w:p><w:pPr><w:pStyle w:val="Normal"/></w:pPr></w:p>');
    } else if (line.startsWith('---') || line.startsWith('***')) {
      buf.writeln(_ooxmlPara('', style: 'Normal'));
    } else {
      buf.writeln(_ooxmlPara(line, style: 'Normal'));
    }
  }

  return buf.toString();
}

String _ooxmlHeading(String text, String style) =>
    '    <w:p><w:pPr><w:pStyle w:val="$style"/></w:pPr>'
    '<w:r><w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>';

String _ooxmlList(String text, {required String numId}) =>
    '    <w:p><w:pPr><w:pStyle w:val="Normal"/>'
    '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="$numId"/></w:numPr>'
    '</w:pPr>${_inlineToOoxml(text)}</w:p>';

String _ooxmlPara(String text,
        {String style = 'Normal', bool italic = false}) =>
    '    <w:p><w:pPr><w:pStyle w:val="$style"/></w:pPr>'
    '${italic ? '<w:r><w:rPr><w:i/></w:rPr><w:t xml:space="preserve">${_esc(text)}</w:t></w:r>' : _inlineToOoxml(text)}'
    '</w:p>';

String _inlineToOoxml(String text) {
  final buf = StringBuffer();
  var remaining = text;

  while (remaining.isNotEmpty) {
    // Strip math dollar signs
    final math = RegExp(r'^\$([^$]+)\$').firstMatch(remaining);
    if (math != null) {
      buf.write(
          '<w:r><w:t xml:space="preserve">${_esc(math.group(1)!)}</w:t></w:r>');
      remaining = remaining.substring(math.end);
      continue;
    }

    final bold = RegExp(r'^\*\*(.+?)\*\*').firstMatch(remaining);
    if (bold != null) {
      buf.write(
          '<w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">${_esc(bold.group(1)!)}</w:t></w:r>');
      remaining = remaining.substring(bold.end);
      continue;
    }

    final italic = RegExp(r'^\*(.+?)\*').firstMatch(remaining);
    if (italic != null) {
      buf.write(
          '<w:r><w:rPr><w:i/></w:rPr><w:t xml:space="preserve">${_esc(italic.group(1)!)}</w:t></w:r>');
      remaining = remaining.substring(italic.end);
      continue;
    }

    final code = RegExp(r'^`(.+?)`').firstMatch(remaining);
    if (code != null) {
      buf.write(
          '<w:r><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/></w:rPr>'
          '<w:t xml:space="preserve">${_esc(code.group(1)!)}</w:t></w:r>');
      remaining = remaining.substring(code.end);
      continue;
    }

    final next = RegExp(r'\*\*|\*|`|\$').firstMatch(remaining);
    if (next != null && next.start > 0) {
      buf.write(
          '<w:r><w:t xml:space="preserve">${_esc(remaining.substring(0, next.start))}</w:t></w:r>');
      remaining = remaining.substring(next.start);
    } else if (next == null) {
      buf.write(
          '<w:r><w:t xml:space="preserve">${_esc(remaining)}</w:t></w:r>');
      remaining = '';
    } else {
      buf.write(
          '<w:r><w:t xml:space="preserve">${_esc(remaining[0])}</w:t></w:r>');
      remaining = remaining.substring(1);
    }
  }

  return buf.toString();
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

// ── OOXML boilerplate ─────────────────────────────────────────────────────────

String _contentTypesXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
</Types>''';

String _relsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

String _wordRelsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
</Relationships>''';

String _stylesXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="Normal" w:default="1">
    <w:name w:val="Normal"/>
    <w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="40"/><w:szCs w:val="40"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:before="200" w:after="100"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:before="160" w:after="80"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="26"/><w:szCs w:val="26"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Quote">
    <w:name w:val="Quote"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:ind w:left="720"/></w:pPr>
    <w:rPr><w:i/><w:color w:val="555555"/></w:rPr>
  </w:style>
</w:styles>''';

String _numberingXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="0">
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/><w:numFmt w:val="bullet"/>
      <w:lvlText w:val="&#x2022;"/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
    </w:lvl>
  </w:abstractNum>
  <w:abstractNum w:abstractNumId="1">
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/><w:numFmt w:val="decimal"/>
      <w:lvlText w:val="%1."/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
    </w:lvl>
  </w:abstractNum>
  <w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
  <w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>
</w:numbering>''';
