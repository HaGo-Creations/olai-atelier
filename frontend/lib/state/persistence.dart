// lib/state/persistence.dart
//
// Save/restore the two settings collections users actually edit:
//   - Fields (Grade, Subject, Language, Question Types dropdowns)
//   - Curriculum library (per grade × subject)
//
// Everything else (prompts, presets, typography, branding) still loads
// from in-memory defaults each run. That's fine for now; we can extend
// persistence later by adding matching toJson/fromJson helpers and one
// more _listen block below.
//
// Storage: SharedPreferences. Values are compact JSON strings.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'providers.dart';

class StatePersistence {
  StatePersistence(this._ref);

  final Ref _ref;
  SharedPreferences? _prefs;
  final _debouncers = <String, Timer>{};
  bool _restoring = false;

  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
    _restoring = true;
    try {
      _restoreAll();
    } finally {
      _restoring = false;
    }
    _wireListeners();
  }

  void _restoreAll() {
    final fieldsRaw = _prefs?.getString('state:fields');
    if (fieldsRaw != null && fieldsRaw.isNotEmpty) {
      try {
        final list = jsonDecode(fieldsRaw) as List;
        _ref.read(fieldsProvider.notifier).restoreAll([
          for (final j in list) _customFieldFromJson(j as Map<String, dynamic>),
        ]);
      } catch (e) {
        debugPrint('[persistence] restore fields failed: $e');
      }
    }

    final curRaw = _prefs?.getString('state:curriculum');
    if (curRaw != null && curRaw.isNotEmpty) {
      try {
        final list = jsonDecode(curRaw) as List;
        _ref.read(curriculumProvider.notifier).restoreAll([
          for (final j in list)
            _curriculumEntryFromJson(j as Map<String, dynamic>),
        ]);
      } catch (e) {
        debugPrint('[persistence] restore curriculum failed: $e');
      }
    }
  }

  void _wireListeners() {
    _ref.listen<List<CustomField>>(fieldsProvider, (_, next) {
      if (_restoring) return;
      _debouncedSave('state:fields',
          () => jsonEncode([for (final f in next) _customFieldToJson(f)]));
    });
    _ref.listen<List<CurriculumEntry>>(curriculumProvider, (_, next) {
      if (_restoring) return;
      _debouncedSave('state:curriculum',
          () => jsonEncode([for (final e in next) _curriculumEntryToJson(e)]));
    });
  }

  void _debouncedSave(String key, String Function() build) {
    _debouncers[key]?.cancel();
    _debouncers[key] = Timer(const Duration(milliseconds: 600), () async {
      try {
        final p = _prefs ?? await SharedPreferences.getInstance();
        await p.setString(key, build());
      } catch (e) {
        debugPrint('[persistence] Save failed for $key: $e');
      }
    });
  }

  Future<void> clearAll() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.remove('state:fields');
    await p.remove('state:curriculum');
  }
}

final statePersistenceProvider =
    Provider<StatePersistence>((ref) => StatePersistence(ref));

final persistenceBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(statePersistenceProvider).bootstrap();
});

// ─── CustomField ──────────────────────────────────────────────────────────
Map<String, dynamic> _customFieldToJson(CustomField f) => {
      'id': f.id,
      'name': f.name,
      'type': f.type.name,
      'options': f.options,
      'optionCodes': f.optionCodes,
      'locked': f.locked,
    };
CustomField _customFieldFromJson(Map<String, dynamic> j) => CustomField(
      id: j['id'] as String,
      name: j['name'] as String,
      type: FieldType.values
          .firstWhere((t) => t.name == j['type'], orElse: () => FieldType.text),
      options: [
        for (final o in (j['options'] as List? ?? const [])) o as String
      ],
      optionCodes:
          Map<String, String>.from(j['optionCodes'] as Map? ?? const {}),
      locked: j['locked'] as bool? ?? false,
    );

// ─── FreeTextSection ──────────────────────────────────────────────────────
Map<String, dynamic> _freeTextToJson(FreeTextSection s) => {
      'text': s.text,
      'documentName': s.documentName,
      'documentParsedText': s.documentParsedText,
      'uploadId': s.uploadId,
      'locked': s.locked,
    };
FreeTextSection _freeTextFromJson(Map<String, dynamic>? j) {
  if (j == null) return const FreeTextSection();
  return FreeTextSection(
    text: j['text'] as String? ?? '',
    documentName: j['documentName'] as String?,
    documentParsedText: j['documentParsedText'] as String?,
    uploadId: j['uploadId'] as String?,
    locked: j['locked'] as bool? ?? false,
  );
}

// ─── CurriculumItem ───────────────────────────────────────────────────────
Map<String, dynamic> _curriculumItemToJson(CurriculumItem i) =>
    {'id': i.id, 'code': i.code, 'text': i.text};
CurriculumItem _curriculumItemFromJson(Map<String, dynamic> j) =>
    CurriculumItem(
      id: j['id'] as String,
      code: j['code'] as String? ?? '',
      text: j['text'] as String? ?? '',
    );

// ─── ListSection ──────────────────────────────────────────────────────────
Map<String, dynamic> _listSectionToJson(ListSection s) => {
      'items': [for (final i in s.items) _curriculumItemToJson(i)],
      'documentName': s.documentName,
      'documentParsedText': s.documentParsedText,
      'uploadId': s.uploadId,
      'locked': s.locked,
    };
ListSection _listSectionFromJson(Map<String, dynamic>? j) {
  if (j == null) return const ListSection();
  return ListSection(
    items: [
      for (final i in (j['items'] as List? ?? const []))
        _curriculumItemFromJson(i as Map<String, dynamic>),
    ],
    documentName: j['documentName'] as String?,
    documentParsedText: j['documentParsedText'] as String?,
    uploadId: j['uploadId'] as String?,
    locked: j['locked'] as bool? ?? false,
  );
}

// ─── CurriculumEntry ──────────────────────────────────────────────────────
Map<String, dynamic> _curriculumEntryToJson(CurriculumEntry e) => {
      'id': e.id,
      'grade': e.grade,
      'subject': e.subject,
      'policyScope': e.policyScope?.name,
      'policyDocument': _freeTextToJson(e.policyDocument),
      'domain': _freeTextToJson(e.domain),
      'additionalContext': _freeTextToJson(e.additionalContext),
      'curricularGoals': _listSectionToJson(e.curricularGoals),
      'competencies': _listSectionToJson(e.competencies),
      'learningOutcomes': _listSectionToJson(e.learningOutcomes),
      'lessons': _listSectionToJson(e.lessons),
      'locked': e.locked,
    };
CurriculumEntry _curriculumEntryFromJson(Map<String, dynamic> j) {
  PolicyScope? scope;
  final s = j['policyScope'] as String?;
  if (s != null) {
    scope = PolicyScope.values
        .firstWhere((p) => p.name == s, orElse: () => PolicyScope.national);
  }
  Map<String, dynamic>? m(String k) => j[k] as Map<String, dynamic>?;
  return CurriculumEntry(
    id: j['id'] as String,
    grade: j['grade'] as String,
    subject: j['subject'] as String,
    policyScope: scope,
    policyDocument: _freeTextFromJson(m('policyDocument')),
    domain: _freeTextFromJson(m('domain')),
    additionalContext: _freeTextFromJson(m('additionalContext')),
    curricularGoals: _listSectionFromJson(m('curricularGoals')),
    competencies: _listSectionFromJson(m('competencies')),
    learningOutcomes: _listSectionFromJson(m('learningOutcomes')),
    lessons: _listSectionFromJson(m('lessons')),
    locked: j['locked'] as bool? ?? false,
  );
}
