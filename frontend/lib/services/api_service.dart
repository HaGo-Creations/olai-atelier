// lib/services/api_service.dart
//
// Two implementations:
//   - MockApiService: in-memory, no backend. Used when API_BASE_URL is empty.
//   - HttpApiService: real backend (FastAPI). Used when API_BASE_URL is set.
//
// Toggle via .env -> API_BASE_URL. If unset or unreachable, falls back to mock
// so the live demo URL always shows something.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'client_export.dart';

abstract class ApiService {
  Future<List<Resource>> listResources();
  Future<List<Resource>> semanticSearch(String query);
  Future<String> generateResource(GenerationRequest req);
  Future<Resource> saveResource(Resource r);
  Future<Resource> updateResource(Resource r);
  Future<Resource> duplicateResource(Resource original, String newTitle);
  Future<void> deleteResource(String id);
  Future<String> exportResource({
    required Resource resource,
    required String format,
    Branding? branding,
  });
  Future<ParseResult> parseFile({
    required List<int> bytes,
    required String filename,
    String sourceLang = 'Tamil',
    String targetLang = 'English',
  });
}

class ParseResult {
  ParseResult({required this.text, this.suggestedTopic, required this.mode});
  final String text;
  final String? suggestedTopic;
  final String mode;
}

/// Service factory — returns Http if API_BASE_URL is set, else Mock.
ApiService createApiService() {
  final baseUrl = dotenv.maybeGet('API_BASE_URL')?.trim() ?? '';
  if (baseUrl.isEmpty) return MockApiService();
  return HttpApiService(baseUrl);
}

// ════════════════════════════════════════════════════════════════════════════
// HttpApiService — talks to FastAPI backend
// ════════════════════════════════════════════════════════════════════════════

class HttpApiService implements ApiService {
  HttpApiService(this.baseUrl);
  final String baseUrl;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  @override
  Future<List<Resource>> listResources() async {
    final r =
        await http.get(_u('/resources')).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return [];
    final list = jsonDecode(r.body) as List;
    return list.map(_resourceFromJson).toList();
  }

  @override
  Future<List<Resource>> semanticSearch(String query) async {
    // Simple client-side filter — backend semantic search is post-hackathon
    final all = await listResources();
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return all;
    return all
        .where((r) =>
            r.title.toLowerCase().contains(q) ||
            r.subject.toLowerCase().contains(q) ||
            r.content.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<String> generateResource(GenerationRequest req) async {
    final body = jsonEncode(_generationRequestToJson(req));
    final r = await http
        .post(
          _u('/generate'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 180));
    if (r.statusCode != 200) {
      throw Exception('Generate failed: ${r.statusCode} ${r.body}');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return data['content_markdown'] ?? '';
  }

  @override
  Future<Resource> saveResource(Resource r) async =>
      r; // Saved server-side on generate

  @override
  Future<Resource> updateResource(Resource r) async {
    final res = await http.put(
      _u('/resources/${r.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': r.title, 'content': r.content}),
    );
    if (res.statusCode != 200)
      throw Exception('Update failed: ${res.statusCode}');
    return _resourceFromJson(jsonDecode(res.body));
  }

  @override
  Future<Resource> duplicateResource(Resource original, String newTitle) async {
    final res = await http.post(
      _u('/resources/${original.id}/duplicate'),
      body: {'new_title': newTitle},
    );
    if (res.statusCode != 200) throw Exception('Duplicate failed');
    return _resourceFromJson(jsonDecode(res.body));
  }

  @override
  Future<void> deleteResource(String id) async {
    await http.delete(_u('/resources/$id'));
  }

  @override
  Future<String> exportResource({
    required Resource resource,
    required String format,
    Branding? branding,
  }) async {
    final body = {
      'resource_id': resource.id,
      'title': resource.title,
      'content_markdown': resource.content,
      'format': format,
      'branding': branding == null ? null : _brandingToJson(branding),
    };
    final r = await http
        .post(
          _u('/export'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) throw Exception('Export failed: ${r.body}');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final downloadUrl = '$baseUrl${data['download_url']}';

    // Fetch the file bytes from the backend and trigger a browser download so
    // it works correctly when hosted cross-origin (GitHub Pages → Hugging Face).
    final fileRes = await http
        .get(Uri.parse(downloadUrl))
        .timeout(const Duration(seconds: 30));
    if (fileRes.statusCode != 200) {
      throw Exception('Download failed: ${fileRes.statusCode}');
    }
    final filename = '${safeFilename(resource.title)}.$format';
    clientExportBytes(
      bytes: Uint8List.fromList(fileRes.bodyBytes),
      filename: filename,
      mimeType: mimeForFormat(format),
    );
    return filename;
  }

  @override
  Future<ParseResult> parseFile({
    required List<int> bytes,
    required String filename,
    String sourceLang = 'Tamil',
    String targetLang = 'English',
  }) async {
    final request = http.MultipartRequest('POST', _u('/parse'));
    request.files
        .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    request.fields['use_gemma_vision'] = 'true';
    request.fields['source_lang'] = sourceLang;
    request.fields['target_lang'] = targetLang;
    final stream = await request.send().timeout(const Duration(seconds: 90));
    final r = await http.Response.fromStream(stream);
    if (r.statusCode != 200) throw Exception('Parse failed: ${r.body}');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return ParseResult(
      text: data['text'] ?? '',
      suggestedTopic: data['suggested_topic'],
      mode: data['mode'] ?? 'text',
    );
  }

  // ── JSON helpers ─────────────────────────────────────────────────────────

  Resource _resourceFromJson(dynamic j) {
    final m = j as Map<String, dynamic>;
    return Resource(
      id: m['id'],
      title: m['title'],
      type: ResourceType.values.firstWhere(
        (t) => t.apiKey == m['type'],
        orElse: () => ResourceType.notes,
      ),
      subject: m['subject'] ?? '',
      grade: m['grade'] ?? '',
      lesson: m['lesson'] ?? '',
      content: m['content'] ?? '',
      createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      modelUsed: m['model_used'] ?? 'unknown',
      sourceUploadIds: List<String>.from(m['source_upload_ids'] ?? []),
    );
  }

  Map<String, dynamic> _generationRequestToJson(GenerationRequest r) {
    return {
      'resource_type': r.resourceType.apiKey,
      'subject': r.subject,
      'grade': r.grade,
      'lesson': r.lesson,
      'topic': r.topic,
      'objectives': r.objective
          .split('•')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'objective_codes': [],
      'language_mode': r.languageMode.name,
      'languages': r.languages,
      'extra_instructions': r.extraInstructions,
      'source_text': r.sourceText,
      'web_search_query': r.webSearchQuery,
      'composition': {
        'mode': 'both',
        'include_questions': true,
        'include_answers': true,
        'include_mark_scheme': true,
      },
      'question_types': [],
      'model_mode': 'auto',
      'enable_thinking': false,
    };
  }

  Map<String, dynamic> _brandingToJson(Branding b) {
    return {
      'logo_path': b.logoPath,
      'school_name': b.schoolName,
      'address': b.address,
      'phone': b.phone,
      'email': b.email,
      'footer_text': b.footerText,
      'apply_on_export': b.applyOnExport,
      'layouts': {
        for (final entry in b.layouts.entries)
          entry.key.name: {
            'page_size': entry.value.pageSize.name,
            'margin_top': entry.value.marginTop,
            'margin_bottom': entry.value.marginBottom,
            'margin_left': entry.value.marginLeft,
            'margin_right': entry.value.marginRight,
            'heading_size': entry.value.typography.headingSize,
            'heading_weight': entry.value.typography.headingWeight,
            'body_size': entry.value.typography.bodySize,
            'body_weight': entry.value.typography.bodyWeight,
            'line_spacing': entry.value.typography.lineSpacing,
            'logo_position': entry.value.logoPosition.name,
            'footer_alignment': entry.value.footerAlignment.name,
            'slide_aspect': entry.value.slideAspect.name,
            'pdf_mode': entry.value.pdfMode.name,
          },
      },
    };
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MockApiService — in-memory, used when no backend configured
// ════════════════════════════════════════════════════════════════════════════

class MockApiService implements ApiService {
  MockApiService() {
    _seed();
  }
  final _uuid = const Uuid();
  final List<Resource> _store = [];

  void _seed() {
    final now = DateTime.now();
    _store.addAll([
      Resource(
        id: _uuid.v4(),
        title: 'Fractions Worksheet — Halves and Quarters',
        type: ResourceType.worksheet,
        subject: 'Mathematics',
        grade: 'Grade 5',
        lesson: 'Introduction to Fractions',
        content:
            '# Fractions Worksheet\n\n1. What is half of 8?\n2. Shade \$\\frac{1}{4}\$ of a circle.',
        createdAt: now.subtract(const Duration(days: 1)),
        modelUsed: 'local',
      ),
    ]);
  }

  @override
  Future<List<Resource>> listResources() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final list = [..._store];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<Resource>> semanticSearch(String query) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return listResources();
    return _store
        .where((r) =>
            r.title.toLowerCase().contains(q) ||
            r.content.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<String> generateResource(GenerationRequest req) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return '# ${req.topic}\n\nSubject: ${req.subject} | Grade: ${req.grade}\n\n'
        '## Objectives\n${req.objective}\n\n'
        '## Sample Questions\n1. Define ${req.topic}.\n2. Give two examples.\n\n'
        '_Generated by mock service. Set API_BASE_URL in .env to use real Gemma 4._';
  }

  @override
  Future<Resource> saveResource(Resource r) async {
    _store.add(r);
    return r;
  }

  @override
  Future<Resource> updateResource(Resource r) async {
    final idx = _store.indexWhere((x) => x.id == r.id);
    if (idx >= 0) _store[idx] = r;
    return r;
  }

  @override
  Future<Resource> duplicateResource(Resource original, String newTitle) async {
    final copy = Resource(
      id: _uuid.v4(),
      title: newTitle,
      type: original.type,
      subject: original.subject,
      grade: original.grade,
      lesson: original.lesson,
      content: original.content,
      createdAt: DateTime.now(),
      modelUsed: original.modelUsed,
      sourceUploadIds: original.sourceUploadIds,
    );
    _store.add(copy);
    return copy;
  }

  @override
  Future<void> deleteResource(String id) async {
    _store.removeWhere((r) => r.id == id);
  }

  @override
  Future<String> exportResource({
    required Resource resource,
    required String format,
    Branding? branding,
  }) async {
    // Generate the file entirely in the browser — no backend needed.
    // pptx falls back to PDF since PPTX generation requires the real backend.
    return clientExportMarkdown(
      markdown: resource.content,
      title: resource.title,
      format: format,
    );
  }

  @override
  Future<ParseResult> parseFile({
    required List<int> bytes,
    required String filename,
    String sourceLang = 'Tamil',
    String targetLang = 'English',
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final base = filename
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[_-]'), ' ');
    final ext = filename.toLowerCase().split('.').last;
    final isAudio = {'mp3', 'wav', 'm4a', 'ogg', 'webm'}.contains(ext);
    final mode = isAudio ? 'audio' : (ext == 'pdf' ? 'pdf' : 'image');
    final text = isAudio
        ? 'Mock audio transcription from $filename ($sourceLang → $targetLang). '
            'Real backend uses Gemma 4 E2B/E4B for audio transcription.'
        : 'Mock parsed text from $filename. Real backend uses Gemma 4 vision for actual OCR.';
    return ParseResult(
      text: text,
      suggestedTopic: base.trim(),
      mode: mode,
    );
  }
}
