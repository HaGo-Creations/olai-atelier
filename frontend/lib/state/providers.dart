// lib/state/providers.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../models/question_schema.dart';

final apiServiceProvider = Provider<ApiService>((ref) => createApiService());

final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);
final modelModeProvider = StateProvider<ModelMode>((_) => ModelMode.local);
final gemmaVersionProvider =
    StateProvider<GemmaVersion>((_) => GemmaVersion.e2b);

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((_) {
  return Connectivity().onConnectivityChanged;
});

final modelBadgeProvider = Provider<ModelBadge>((ref) {
  final mode = ref.watch(modelModeProvider);
  final connectivity = ref.watch(connectivityProvider).valueOrNull;
  final online = connectivity != null &&
      connectivity.any((r) => r != ConnectivityResult.none);
  switch (mode) {
    case ModelMode.local:
      return ModelBadge.local;
    case ModelMode.cloud:
      return online ? ModelBadge.cloud : ModelBadge.offline;
    case ModelMode.auto:
      return online ? ModelBadge.cloud : ModelBadge.local;
  }
});

// ── Field Editor ───────────────────────────────────────────────────────────

class FieldsNotifier extends StateNotifier<List<CustomField>> {
  FieldsNotifier()
      : super(const [
          CustomField(
              id: 'f-grade',
              name: 'Grade',
              type: FieldType.dropdown,
              options: [
                'Grade 1',
                'Grade 2',
                'Grade 3',
                'Grade 4',
                'Grade 5',
                'Grade 6',
                'Grade 7',
                'Grade 8',
                'Grade 9',
                'Grade 10',
                'Grade 11',
                'Grade 12',
              ]),
          CustomField(
            id: 'f-subject',
            name: 'Subject',
            type: FieldType.dropdown,
            options: [
              'Mathematics',
              'Science',
              'English',
              'Social Studies',
              'Tamil',
              'Hindi'
            ],
            optionCodes: {
              'Mathematics': 'MATH',
              'Science': 'SCI',
              'English': 'ENG',
              'Social Studies': 'SST',
              'Tamil': 'TAM',
              'Hindi': 'HIN',
            },
          ),
          CustomField(
              id: 'f-language',
              name: 'Language',
              type: FieldType.dropdown,
              options: [
                'English',
                'Tamil',
                'Hindi',
              ]),
          // ── Question Types: used by the worksheet builder ───────────────
          CustomField(
            id: 'f-qtype',
            name: 'Question Types',
            type: FieldType.dropdown,
            options: [
              'Short Answer',
              'Long Answer',
              'MCQ',
              'True/False',
              'Fill in the Blanks',
              'Match the Following',
              'One-Word Answer',
              'Diagram',
              'Map Work',
              'Numerical Problem',
              'Word Problem',
              'Picture-Based',
              'Crossword',
              'Sequencing',
              'Categorize',
              'Open-Ended',
              'Drawing',
            ],
          ),
        ]);

  final _uuid = const Uuid();

  void addField(String name, FieldType type, List<String> options) {
    state = [
      ...state,
      CustomField(id: _uuid.v4(), name: name, type: type, options: options)
    ];
  }

  void removeField(String id) =>
      state = state.where((f) => f.id != id).toList();
  void toggleLock(String id) => state = [
        for (final f in state) f.id == id ? f.copyWith(locked: !f.locked) : f,
      ];
  void addOption(String id, String o) => state = [
        for (final f in state)
          f.id == id ? f.copyWith(options: [...f.options, o]) : f,
      ];
  void removeOption(String id, String o) => state = [
        for (final f in state)
          f.id == id
              ? f.copyWith(
                  options: f.options.where((x) => x != o).toList(),
                  optionCodes: {...f.optionCodes}..remove(o))
              : f,
      ];
  void setOptionCode(String fieldId, String option, String code) => state = [
        for (final f in state)
          f.id == fieldId
              ? f.copyWith(
                  optionCodes: {...f.optionCodes, option: code.toUpperCase()})
              : f,
      ];
}

final fieldsProvider = StateNotifierProvider<FieldsNotifier, List<CustomField>>(
    (_) => FieldsNotifier());

CustomField _empty() =>
    const CustomField(id: '', name: '', type: FieldType.dropdown);

final masterGradesProvider = Provider<List<String>>((ref) => ref
    .watch(fieldsProvider)
    .firstWhere((f) => f.name == 'Grade', orElse: _empty)
    .options);
final masterSubjectsProvider = Provider<List<String>>((ref) => ref
    .watch(fieldsProvider)
    .firstWhere((f) => f.name == 'Subject', orElse: _empty)
    .options);
final masterLanguagesProvider = Provider<List<String>>((ref) {
  return ref
      .watch(fieldsProvider)
      .firstWhere((f) => f.name == 'Language',
          orElse: () => const CustomField(
              id: '', name: '', type: FieldType.dropdown, options: ['English']))
      .options;
});

final questionTypesProvider = Provider<List<String>>((ref) {
  return ref
      .watch(fieldsProvider)
      .firstWhere((f) => f.name == 'Question Types', orElse: _empty)
      .options;
});

final subjectCodesProvider = Provider<Map<String, String>>((ref) {
  return ref
      .watch(fieldsProvider)
      .firstWhere((f) => f.name == 'Subject', orElse: _empty)
      .optionCodes;
});

String gradeCode(String grade) {
  final num = RegExp(r'\d+').stringMatch(grade);
  if (num != null) return 'G$num';
  return 'G${grade.replaceAll(' ', '').toUpperCase()}';
}

String subjectCodeOrFallback(String subject, Map<String, String> codes) {
  if (codes[subject] != null) return codes[subject]!;
  final clean = subject.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  return clean.substring(0, clean.length.clamp(0, 4));
}

/// Shorter format: {G}-{SUBJ}-{TYPE}-{NN}   e.g.  G5-MATH-CG-01
String formatCurriculumCode({
  required String grade,
  required String subject,
  required String typeCode,
  required int serial,
  required Map<String, String> subjectCodes,
}) {
  final g = gradeCode(grade);
  final s = subjectCodeOrFallback(subject, subjectCodes);
  final n = serial.toString().padLeft(2, '0');
  return '$g-$s-$typeCode-$n';
}

// ── Profile ────────────────────────────────────────────────────────────────

class ProfileNotifier extends StateNotifier<TeacherProfile> {
  ProfileNotifier()
      : super(const TeacherProfile(
          name: 'Anitha Ramanathan',
          designation: 'Senior Teacher',
          school: 'Government High School, Chennai',
          subjects: ['Mathematics', 'Science', 'English'],
          grades: ['Grade 5', 'Grade 6', 'Grade 7', 'Grade 8'],
        ));

  void setName(String n) => state = state.copyWith(name: n);
  void setDesignation(String d) => state = state.copyWith(designation: d);
  void setSchool(String s) => state = state.copyWith(school: s);
  void setSubjects(List<String> s) => state = state.copyWith(subjects: s);
  void setGrades(List<String> g) => state = state.copyWith(grades: g);
  void toggleLock() => state = state.copyWith(locked: !state.locked);
}

final profileProvider = StateNotifierProvider<ProfileNotifier, TeacherProfile>(
    (_) => ProfileNotifier());

final teacherGradesProvider = Provider<List<String>>((ref) {
  final master = ref.watch(masterGradesProvider);
  final p = ref.watch(profileProvider);
  return p.grades.where(master.contains).toList();
});

final teacherSubjectsProvider = Provider<List<String>>((ref) {
  final master = ref.watch(masterSubjectsProvider);
  final p = ref.watch(profileProvider);
  return p.subjects.where(master.contains).toList();
});

// ── Uploads (Source Library) ───────────────────────────────────────────────

class UploadsNotifier extends StateNotifier<List<UploadRecord>> {
  UploadsNotifier() : super(const []);
  final _uuid = const Uuid();

  String record({
    required String fileName,
    required int sizeBytes,
    required UploadSource source,
    String? parsedTextPreview,
  }) {
    final id = _uuid.v4();
    state = [
      UploadRecord(
        id: id,
        fileName: fileName,
        sizeBytes: sizeBytes,
        uploadedAt: DateTime.now(),
        source: source,
        parsedTextPreview: parsedTextPreview,
      ),
      ...state,
    ];
    return id;
  }

  void remove(String id) => state = state.where((u) => u.id != id).toList();
  void rename(String id, String n) => state = [
        for (final u in state) u.id == id ? u.copyWith(fileName: n) : u,
      ];
  void addTag(String id, String t) => state = [
        for (final u in state)
          u.id == id ? u.copyWith(tags: [...u.tags, t]) : u,
      ];
  void removeTag(String id, String t) => state = [
        for (final u in state)
          u.id == id
              ? u.copyWith(tags: u.tags.where((x) => x != t).toList())
              : u,
      ];
  void linkResource(String uploadId, String resourceId) => state = [
        for (final u in state)
          u.id == uploadId
              ? u.copyWith(
                  usedInResourceIds: [...u.usedInResourceIds, resourceId])
              : u,
      ];
}

final uploadsProvider =
    StateNotifierProvider<UploadsNotifier, List<UploadRecord>>(
        (_) => UploadsNotifier());

// ── Curriculum ─────────────────────────────────────────────────────────────

class CurriculumNotifier extends StateNotifier<List<CurriculumEntry>> {
  CurriculumNotifier(this._ref) : super(const []);
  final Ref _ref;
  final _uuid = const Uuid();

  String addEntry(
      {required String grade, required String subject, PolicyScope? scope}) {
    final id = _uuid.v4();
    state = [
      ...state,
      CurriculumEntry(
          id: id, grade: grade, subject: subject, policyScope: scope)
    ];
    return id;
  }

  void remove(String id) => state = state.where((e) => e.id != id).toList();
  void replace(CurriculumEntry e) =>
      state = [for (final x in state) x.id == e.id ? e : x];
  void toggleEntryLock(String id) => state = [
        for (final e in state) e.id == id ? e.copyWith(locked: !e.locked) : e,
      ];

  String _codeFor(
          CurriculumEntry entry, CurriculumSectionKey key, int serial) =>
      formatCurriculumCode(
        grade: entry.grade,
        subject: entry.subject,
        typeCode: key.typeCode!,
        serial: serial,
        subjectCodes: _ref.read(subjectCodesProvider),
      );

  void _renumber(CurriculumEntry entry, CurriculumSectionKey key,
      List<CurriculumItem> items) {
    final renumbered = <CurriculumItem>[];
    for (var i = 0; i < items.length; i++) {
      renumbered.add(items[i].copyWith(code: _codeFor(entry, key, i + 1)));
    }
    final section = entry.listSection(key).copyWith(items: renumbered);
    state = [
      for (final e in state)
        e.id == entry.id ? e.withListSection(key, section) : e
    ];
  }

  void addListItem(String entryId, CurriculumSectionKey key,
      {String text = ''}) {
    final entry = state.firstWhere((e) => e.id == entryId);
    final items = [
      ...entry.listSection(key).items,
      CurriculumItem(id: _uuid.v4(), code: '', text: text),
    ];
    _renumber(entry, key, items);
  }

  void updateListItemText(
      String entryId, CurriculumSectionKey key, String itemId, String text) {
    final entry = state.firstWhere((e) => e.id == entryId);
    final items = [
      for (final i in entry.listSection(key).items)
        i.id == itemId ? i.copyWith(text: text) : i
    ];
    final section = entry.listSection(key).copyWith(items: items);
    state = [
      for (final e in state)
        e.id == entry.id ? e.withListSection(key, section) : e
    ];
  }

  void removeListItem(String entryId, CurriculumSectionKey key, String itemId) {
    final entry = state.firstWhere((e) => e.id == entryId);
    final items =
        entry.listSection(key).items.where((i) => i.id != itemId).toList();
    _renumber(entry, key, items);
  }

  void reorderListItems(
      String entryId, CurriculumSectionKey key, int oldIndex, int newIndex) {
    final entry = state.firstWhere((e) => e.id == entryId);
    final items = List<CurriculumItem>.from(entry.listSection(key).items);
    var newIdx = newIndex;
    if (newIdx > oldIndex) newIdx -= 1;
    final item = items.removeAt(oldIndex);
    items.insert(newIdx, item);
    _renumber(entry, key, items);
  }

  void setListDocument(String entryId, CurriculumSectionKey key,
      {required String? name, required String? parsedText, String? uploadId}) {
    final entry = state.firstWhere((e) => e.id == entryId);
    final section = entry.listSection(key).copyWith(
          documentName: name,
          documentParsedText: parsedText,
          uploadId: uploadId,
          clearDocument: name == null,
        );
    state = [
      for (final e in state)
        e.id == entry.id ? e.withListSection(key, section) : e
    ];
  }

  void toggleListSectionLock(String entryId, CurriculumSectionKey key) {
    final entry = state.firstWhere((e) => e.id == entryId);
    final section = entry.listSection(key);
    state = [
      for (final e in state)
        e.id == entry.id
            ? e.withListSection(key, section.copyWith(locked: !section.locked))
            : e
    ];
  }

  void updateFreeText(
      String entryId, CurriculumSectionKey key, FreeTextSection s) {
    final entry = state.firstWhere((e) => e.id == entryId);
    state = [
      for (final e in state)
        e.id == entry.id ? e.withFreeTextSection(key, s) : e
    ];
  }

  void toggleFreeTextLock(String entryId, CurriculumSectionKey key) {
    final entry = state.firstWhere((e) => e.id == entryId);
    final s = entry.freeTextSection(key);
    state = [
      for (final e in state)
        e.id == entry.id
            ? e.withFreeTextSection(key, s.copyWith(locked: !s.locked))
            : e
    ];
  }
}

final curriculumProvider =
    StateNotifierProvider<CurriculumNotifier, List<CurriculumEntry>>(
        (ref) => CurriculumNotifier(ref));

final lessonSuggestionsProvider = Provider.family<
    List<({String code, String text})>,
    ({String? grade, String? subject})>((ref, args) {
  if (args.grade == null || args.subject == null) return const [];
  for (final e in ref.watch(curriculumProvider)) {
    if (e.grade == args.grade && e.subject == args.subject)
      return e.lessonSuggestions;
  }
  return const [];
});

final outcomeSuggestionsProvider = Provider.family<
    List<({String code, String text})>,
    ({String? grade, String? subject})>((ref, args) {
  if (args.grade == null || args.subject == null) return const [];
  for (final e in ref.watch(curriculumProvider)) {
    if (e.grade == args.grade && e.subject == args.subject)
      return e.outcomeSuggestions;
  }
  return const [];
});

// ── Presets (Resource Templates) ───────────────────────────────────────────

class PresetsNotifier extends StateNotifier<List<ResourcePreset>> {
  PresetsNotifier()
      : super([
          ResourcePreset(
            id: 'p-worksheet',
            name: 'Standard Worksheet',
            resourceType: ResourceType.worksheet,
            toggles: const {
              'show_objectives': true,
              'include_answer_key': true,
              'numbered_items': true,
              'bold_headers': true,
            },
            blocks: const [
              WorksheetBlock(
                  id: 'b1',
                  type: WorksheetBlockType.title,
                  label: 'Title',
                  placeholder: '{{topic}}'),
              WorksheetBlock(
                  id: 'b2',
                  type: WorksheetBlockType.objectives,
                  label: 'Objectives'),
              WorksheetBlock(
                  id: 'b3',
                  type: WorksheetBlockType.instructions,
                  label: 'Instructions',
                  placeholder: 'Read each question carefully.'),
              WorksheetBlock(
                id: 'b4',
                type: WorksheetBlockType.questions,
                label: 'Questions',
                columns: 1,
                questionTypes: ['Short Answer', 'MCQ'],
              ),
              WorksheetBlock(
                  id: 'b5',
                  type: WorksheetBlockType.answerKey,
                  label: 'Answer Key'),
            ],
          ),
          ResourcePreset(
            id: 'p-lesson',
            name: 'Detailed Lesson Plan',
            resourceType: ResourceType.lessonPlan,
            toggles: const {
              'show_objectives': true,
              'include_rubric': true,
              'bold_headers': true
            },
          ),
          ResourcePreset(
            id: 'p-qp',
            name: 'Mid-Term Question Paper',
            resourceType: ResourceType.questionPaper,
            toggles: const {'include_answer_key': true, 'numbered_items': true},
          ),
        ]);

  final _uuid = const Uuid();
  void add(String name, ResourceType type) {
    state = [
      ...state,
      ResourcePreset(
        id: _uuid.v4(),
        name: name,
        resourceType: type,
        toggles: const {'show_objectives': true, 'bold_headers': true},
        blocks: type == ResourceType.worksheet
            ? const [
                WorksheetBlock(
                    id: 'b1', type: WorksheetBlockType.title, label: 'Title'),
                WorksheetBlock(
                    id: 'b2',
                    type: WorksheetBlockType.questions,
                    label: 'Questions'),
              ]
            : const [],
      ),
    ];
  }

  void remove(String id) => state = state.where((p) => p.id != id).toList();
  void rename(String id, String n) =>
      state = [for (final p in state) p.id == id ? p.copyWith(name: n) : p];
  void toggleSwitch(String id, String k, bool v) => state = [
        for (final p in state)
          p.id == id ? p.copyWith(toggles: {...p.toggles, k: v}) : p
      ];
  void toggleLock(String id) => state = [
        for (final p in state) p.id == id ? p.copyWith(locked: !p.locked) : p
      ];
  void replaceBlocks(String id, List<WorksheetBlock> b) =>
      state = [for (final p in state) p.id == id ? p.copyWith(blocks: b) : p];
}

final presetsProvider =
    StateNotifierProvider<PresetsNotifier, List<ResourcePreset>>(
        (_) => PresetsNotifier());

// ── Prompts ────────────────────────────────────────────────────────────────

class PromptsNotifier extends StateNotifier<List<PromptTemplate>> {
  PromptsNotifier()
      : super(const [
          PromptTemplate(
            id: 'prompt-default',
            name: 'Default Curriculum-Aligned',
            role:
                'You are an experienced school teacher creating classroom resources.',
            instructions:
                'Use only the vocabulary and phrasing present in the provided curriculum context. Do not introduce concepts beyond the lesson scope.',
            constraints:
                'Stay aligned with NEP framework. Use grade-appropriate language. Cite the lesson name where relevant.',
            style:
                'Clear, structured, with section headings. Suitable for printing as a worksheet or lesson plan.',
            locked: true,
          ),
        ]);

  final _uuid = const Uuid();
  void add(PromptTemplate t) => state = [...state, t];
  void remove(String id) => state = state.where((p) => p.id != id).toList();
  void update(PromptTemplate t) =>
      state = [for (final p in state) p.id == t.id ? t : p];
  void toggleLock(String id) => state = [
        for (final p in state) p.id == id ? p.copyWith(locked: !p.locked) : p
      ];

  PromptTemplate create({
    required String name,
    required String role,
    required String instructions,
    required String constraints,
    required String style,
  }) {
    final t = PromptTemplate(
      id: _uuid.v4(),
      name: name,
      role: role,
      instructions: instructions,
      constraints: constraints,
      style: style,
    );
    add(t);
    return t;
  }
}

final promptsProvider =
    StateNotifierProvider<PromptsNotifier, List<PromptTemplate>>(
        (_) => PromptsNotifier());

// ── Branding ───────────────────────────────────────────────────────────────

class BrandingNotifier extends StateNotifier<Branding> {
  BrandingNotifier() : super(const Branding());
  void setLogo(String? p) => state = state.copyWith(logoPath: p);
  void setSchoolName(String v) => state = state.copyWith(schoolName: v);
  void setAddress(String v) => state = state.copyWith(address: v);
  void setPhone(String v) => state = state.copyWith(phone: v);
  void setEmail(String v) => state = state.copyWith(email: v);
  void setFooter(String v) => state = state.copyWith(footerText: v);
  void setApplyOnExport(bool v) => state = state.copyWith(applyOnExport: v);
  void toggleLock() => state = state.copyWith(locked: !state.locked);
  void setLayout(DocFormat f, PageLayout l) => state = state.withLayout(f, l);
}

final brandingProvider = StateNotifierProvider<BrandingNotifier, Branding>(
    (_) => BrandingNotifier());

// ── Resources ──────────────────────────────────────────────────────────────

final resourcesProvider = FutureProvider<List<Resource>>((ref) {
  return ref.watch(apiServiceProvider).listResources();
});

final searchQueryProvider = StateProvider<String>((_) => '');
final searchResultsProvider = FutureProvider<List<Resource>>((ref) {
  final api = ref.watch(apiServiceProvider);
  final q = ref.watch(searchQueryProvider);
  return q.trim().isEmpty ? api.listResources() : api.semanticSearch(q);
});

final navIndexProvider = StateProvider<int>((_) => 0);

// ════════════════════════════════════════════════════════════════════════════
// APPEND THIS TO lib/state/providers.dart
// (after the existing imports, you may need: import '../models/question_schema.dart';)
// ════════════════════════════════════════════════════════════════════════════

// ── Question Schemas (defined in Field Editor, used by builder/AI) ─────────

class QuestionSchemasNotifier extends StateNotifier<List<QuestionSchema>> {
  QuestionSchemasNotifier() : super(QuestionSchema.defaults());
  final _uuid = const Uuid();

  void add(QuestionSchema s) => state = [...state, s];
  void remove(String id) => state = state.where((s) => s.id != id).toList();
  void replace(QuestionSchema s) =>
      state = [for (final x in state) x.id == s.id ? s : x];
  void toggleLock(String id) => state = [
        for (final s in state) s.id == id ? s.copyWith(locked: !s.locked) : s,
      ];

  /// Create a brand-new user-defined schema with one stem field.
  QuestionSchema createNew(String name) {
    final s = QuestionSchema(
      id: _uuid.v4(),
      name: name,
      fields: [
        QSchemaField(id: _uuid.v4(), label: 'Question', kind: QFieldKind.stem),
      ],
    );
    add(s);
    return s;
  }

  void addField(String schemaId, QSchemaField f) {
    final s = state.firstWhere((x) => x.id == schemaId);
    replace(s.copyWith(fields: [...s.fields, f]));
  }

  void removeField(String schemaId, String fieldId) {
    final s = state.firstWhere((x) => x.id == schemaId);
    replace(
        s.copyWith(fields: s.fields.where((f) => f.id != fieldId).toList()));
  }

  void updateField(String schemaId, QSchemaField updated) {
    final s = state.firstWhere((x) => x.id == schemaId);
    replace(s.copyWith(fields: [
      for (final f in s.fields) f.id == updated.id ? updated : f,
    ]));
  }
}

final questionSchemasProvider =
    StateNotifierProvider<QuestionSchemasNotifier, List<QuestionSchema>>(
        (_) => QuestionSchemasNotifier());

/// Schema names (sourced from question schemas) — replaces the old static list.
final questionTypeNamesProvider = Provider<List<String>>((ref) {
  return ref.watch(questionSchemasProvider).map((s) => s.name).toList();
});

// ── Accessibility ──────────────────────────────────────────────────────────

class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  AccessibilityNotifier() : super(const AccessibilitySettings());
  void setFontScale(double v) => state = state.copyWith(fontScale: v);
  void setHighContrast(bool v) => state = state.copyWith(highContrast: v);
  void setReduceMotion(bool v) => state = state.copyWith(reduceMotion: v);
  void setDyslexiaFont(bool v) => state = state.copyWith(dyslexiaFont: v);
  void setLargerTouchTargets(bool v) =>
      state = state.copyWith(largerTouchTargets: v);
  void setScreenReaderHints(bool v) =>
      state = state.copyWith(screenReaderHints: v);
  void setColorblindSafe(bool v) =>
      state = state.copyWith(colorblindSafePalette: v);
}

final accessibilityProvider =
    StateNotifierProvider<AccessibilityNotifier, AccessibilitySettings>(
        (_) => AccessibilityNotifier());

// ── Resource version history ───────────────────────────────────────────────

class ResourceVersionsNotifier
    extends StateNotifier<Map<String, List<ResourceVersion>>> {
  ResourceVersionsNotifier() : super({});
  final _uuid = const Uuid();

  void recordVersion(Resource r, {String note = ''}) {
    final list = state[r.id] ?? const [];
    final v = ResourceVersion(
      id: _uuid.v4(),
      resourceId: r.id,
      versionNumber: list.length + 1,
      savedAt: DateTime.now(),
      content: r.content,
      title: r.title,
      note: note,
    );
    state = {
      ...state,
      r.id: [...list, v]
    };
  }

  List<ResourceVersion> versionsFor(String resourceId) =>
      state[resourceId] ?? const [];
}

final resourceVersionsProvider = StateNotifierProvider<ResourceVersionsNotifier,
    Map<String, List<ResourceVersion>>>((_) => ResourceVersionsNotifier());

// Pre-selects a resource type when navigating from Desk → Studio.
final studioPresetProvider = StateProvider<ResourceType?>((ref) => null);

// ── Resource Field Sets (drives Craft fields + syncs with Resource Templates) ─

class ResourceFieldSetsNotifier extends StateNotifier<List<ResourceFieldSet>> {
  ResourceFieldSetsNotifier() : super(ResourceFieldSet.defaults());

  /// Find the field set for a given resource type API key.
  ResourceFieldSet? forType(String apiKey) {
    try {
      return state.firstWhere((s) => s.resourceType == apiKey);
    } catch (_) {
      return null;
    }
  }

  void replace(ResourceFieldSet updated) {
    state = [
      for (final s in state)
        s.resourceType == updated.resourceType ? updated : s,
    ];
  }

  void addField(String typeKey, ResourceField f) {
    final s = forType(typeKey);
    if (s == null) return;
    replace(s.copyWith(fields: [...s.fields, f]));
  }

  void removeField(String typeKey, String fieldId) {
    final s = forType(typeKey);
    if (s == null) return;
    replace(
        s.copyWith(fields: s.fields.where((f) => f.id != fieldId).toList()));
  }

  void updateField(String typeKey, ResourceField updated) {
    final s = forType(typeKey);
    if (s == null) return;
    replace(s.copyWith(fields: [
      for (final f in s.fields) f.id == updated.id ? updated : f,
    ]));
  }

  void reset(String typeKey) {
    final def = ResourceFieldSet.defaults()
        .firstWhere((d) => d.resourceType == typeKey);
    replace(def);
  }
}

final fieldSetsProvider =
    StateNotifierProvider<ResourceFieldSetsNotifier, List<ResourceFieldSet>>(
        (_) => ResourceFieldSetsNotifier());

/// Convenience: get the active field set for the current resource type.
final activeFieldSetProvider =
    Provider.family<ResourceFieldSet?, String>((ref, typeKey) {
  return ref.watch(fieldSetsProvider.notifier).forType(typeKey);
});
