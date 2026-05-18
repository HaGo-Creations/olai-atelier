// lib/models/models.dart
import 'package:flutter/foundation.dart';

enum ResourceType {
  worksheet,
  lessonPlan,
  questionPaper,
  presentation,
  activity,
  notes;

  String get apiKey => switch (this) {
        ResourceType.worksheet => 'worksheet',
        ResourceType.lessonPlan => 'lesson_plan',
        ResourceType.questionPaper => 'question_paper',
        ResourceType.presentation => 'presentation',
        ResourceType.activity => 'activity',
        ResourceType.notes => 'notes',
      };
  String get label => switch (this) {
        ResourceType.worksheet => 'Worksheet',
        ResourceType.lessonPlan => 'Lesson Plan',
        ResourceType.questionPaper => 'Question Paper',
        ResourceType.presentation => 'Presentation',
        ResourceType.activity => 'Activity',
        ResourceType.notes => 'Class Notes',
      };

  Set<DocFormat> get validExportFormats => switch (this) {
        ResourceType.presentation => {DocFormat.pptx, DocFormat.pdf},
        _ => {DocFormat.docx, DocFormat.pdf},
      };
}

@immutable
class Resource {
  const Resource({
    required this.id,
    required this.title,
    required this.type,
    required this.subject,
    required this.grade,
    required this.lesson,
    required this.content,
    required this.createdAt,
    this.modelUsed = 'local',
    this.sourceUploadIds = const [],
  });
  final String id, title, subject, grade, lesson, content, modelUsed;
  final ResourceType type;
  final DateTime createdAt;

  /// Upload IDs that contributed to this resource.
  final List<String> sourceUploadIds;

  Resource copyWith(
          {String? title, String? content, List<String>? sourceUploadIds}) =>
      Resource(
        id: id,
        title: title ?? this.title,
        type: type,
        subject: subject,
        grade: grade,
        lesson: lesson,
        content: content ?? this.content,
        createdAt: createdAt,
        modelUsed: modelUsed,
        sourceUploadIds: sourceUploadIds ?? this.sourceUploadIds,
      );
}

// ── Fields ─────────────────────────────────────────────────────────────────

enum FieldType { text, dropdown, number, date, multiSelect }

@immutable
class CustomField {
  const CustomField({
    required this.id,
    required this.name,
    required this.type,
    this.options = const [],
    this.optionCodes = const {},
    this.locked = false,
  });
  final String id, name;
  final FieldType type;
  final List<String> options;
  final Map<String, String> optionCodes;
  final bool locked;

  CustomField copyWith({
    String? name,
    FieldType? type,
    List<String>? options,
    Map<String, String>? optionCodes,
    bool? locked,
  }) =>
      CustomField(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        options: options ?? this.options,
        optionCodes: optionCodes ?? this.optionCodes,
        locked: locked ?? this.locked,
      );
}

// ── Curriculum ─────────────────────────────────────────────────────────────

@immutable
class CurriculumItem {
  const CurriculumItem(
      {required this.id, required this.code, required this.text});
  final String id, code, text;
  CurriculumItem copyWith({String? code, String? text}) =>
      CurriculumItem(id: id, code: code ?? this.code, text: text ?? this.text);
}

@immutable
class FreeTextSection {
  const FreeTextSection({
    this.text = '',
    this.documentName,
    this.documentParsedText,
    this.locked = false,
    this.uploadId,
  });
  final String text;
  final String? documentName, documentParsedText, uploadId;
  final bool locked;

  bool get hasContent =>
      text.trim().isNotEmpty ||
      (documentParsedText?.trim().isNotEmpty ?? false);

  FreeTextSection copyWith({
    String? text,
    String? documentName,
    String? documentParsedText,
    String? uploadId,
    bool? locked,
    bool clearDocument = false,
  }) =>
      FreeTextSection(
        text: text ?? this.text,
        documentName:
            clearDocument ? null : (documentName ?? this.documentName),
        documentParsedText: clearDocument
            ? null
            : (documentParsedText ?? this.documentParsedText),
        uploadId: clearDocument ? null : (uploadId ?? this.uploadId),
        locked: locked ?? this.locked,
      );
}

@immutable
class ListSection {
  const ListSection({
    this.items = const [],
    this.documentName,
    this.documentParsedText,
    this.uploadId,
    this.locked = false,
  });
  final List<CurriculumItem> items;
  final String? documentName, documentParsedText, uploadId;
  final bool locked;

  bool get hasContent =>
      items.isNotEmpty || (documentParsedText?.trim().isNotEmpty ?? false);

  ListSection copyWith({
    List<CurriculumItem>? items,
    String? documentName,
    String? documentParsedText,
    String? uploadId,
    bool? locked,
    bool clearDocument = false,
  }) =>
      ListSection(
        items: items ?? this.items,
        documentName:
            clearDocument ? null : (documentName ?? this.documentName),
        documentParsedText: clearDocument
            ? null
            : (documentParsedText ?? this.documentParsedText),
        uploadId: clearDocument ? null : (uploadId ?? this.uploadId),
        locked: locked ?? this.locked,
      );
}

enum PolicyScope { national, state }

enum CurriculumSectionKey {
  policyDocument,
  domain,
  curricularGoals,
  competencies,
  learningOutcomes,
  lessons,
  additionalContext;

  String get label => switch (this) {
        CurriculumSectionKey.policyDocument => 'Education Policy Document',
        CurriculumSectionKey.domain => 'Domain',
        CurriculumSectionKey.curricularGoals => 'Curricular Goals',
        CurriculumSectionKey.competencies => 'Competencies',
        CurriculumSectionKey.learningOutcomes => 'Learning Outcomes',
        CurriculumSectionKey.lessons => 'Names of Lessons',
        CurriculumSectionKey.additionalContext => 'Additional Context',
      };

  String? get typeCode => switch (this) {
        CurriculumSectionKey.curricularGoals => 'CG',
        CurriculumSectionKey.competencies => 'COM',
        CurriculumSectionKey.learningOutcomes => 'LO',
        CurriculumSectionKey.lessons => 'LSN',
        _ => null,
      };

  bool get isListBased => typeCode != null;
}

@immutable
class CurriculumEntry {
  const CurriculumEntry({
    required this.id,
    required this.grade,
    required this.subject,
    this.policyScope,
    this.policyDocument = const FreeTextSection(),
    this.domain = const FreeTextSection(),
    this.additionalContext = const FreeTextSection(),
    this.curricularGoals = const ListSection(),
    this.competencies = const ListSection(),
    this.learningOutcomes = const ListSection(),
    this.lessons = const ListSection(),
    this.locked = false,
  });
  final String id, grade, subject;
  final PolicyScope? policyScope;
  final FreeTextSection policyDocument, domain, additionalContext;
  final ListSection curricularGoals, competencies, learningOutcomes, lessons;
  final bool locked;

  ListSection listSection(CurriculumSectionKey k) => switch (k) {
        CurriculumSectionKey.curricularGoals => curricularGoals,
        CurriculumSectionKey.competencies => competencies,
        CurriculumSectionKey.learningOutcomes => learningOutcomes,
        CurriculumSectionKey.lessons => lessons,
        _ => const ListSection(),
      };

  FreeTextSection freeTextSection(CurriculumSectionKey k) => switch (k) {
        CurriculumSectionKey.policyDocument => policyDocument,
        CurriculumSectionKey.domain => domain,
        CurriculumSectionKey.additionalContext => additionalContext,
        _ => const FreeTextSection(),
      };

  CurriculumEntry copyWith({
    PolicyScope? policyScope,
    FreeTextSection? policyDocument,
    FreeTextSection? domain,
    FreeTextSection? additionalContext,
    ListSection? curricularGoals,
    ListSection? competencies,
    ListSection? learningOutcomes,
    ListSection? lessons,
    bool? locked,
  }) =>
      CurriculumEntry(
        id: id,
        grade: grade,
        subject: subject,
        policyScope: policyScope ?? this.policyScope,
        policyDocument: policyDocument ?? this.policyDocument,
        domain: domain ?? this.domain,
        additionalContext: additionalContext ?? this.additionalContext,
        curricularGoals: curricularGoals ?? this.curricularGoals,
        competencies: competencies ?? this.competencies,
        learningOutcomes: learningOutcomes ?? this.learningOutcomes,
        lessons: lessons ?? this.lessons,
        locked: locked ?? this.locked,
      );

  CurriculumEntry withListSection(CurriculumSectionKey k, ListSection s) =>
      switch (k) {
        CurriculumSectionKey.curricularGoals => copyWith(curricularGoals: s),
        CurriculumSectionKey.competencies => copyWith(competencies: s),
        CurriculumSectionKey.learningOutcomes => copyWith(learningOutcomes: s),
        CurriculumSectionKey.lessons => copyWith(lessons: s),
        _ => this,
      };

  CurriculumEntry withFreeTextSection(
          CurriculumSectionKey k, FreeTextSection s) =>
      switch (k) {
        CurriculumSectionKey.policyDocument => copyWith(policyDocument: s),
        CurriculumSectionKey.domain => copyWith(domain: s),
        CurriculumSectionKey.additionalContext =>
          copyWith(additionalContext: s),
        _ => this,
      };

  /// (code, text) pairs so Studio chips can show both.
  List<({String code, String text})> get lessonSuggestions => [
        for (final i in lessons.items)
          if (i.text.trim().isNotEmpty) (code: i.code, text: i.text)
      ];

  List<({String code, String text})> get outcomeSuggestions => [
        for (final i in learningOutcomes.items)
          if (i.text.trim().isNotEmpty) (code: i.code, text: i.text)
      ];
}

// ── Resource Templates (Layout Templates renamed) ──────────────────────────

@immutable
class ResourcePreset {
  const ResourcePreset({
    required this.id,
    required this.name,
    required this.resourceType,
    required this.toggles,
    this.blocks = const [],
    this.locked = false,
  });
  final String id, name;
  final ResourceType resourceType;
  final Map<String, bool> toggles;
  final List<WorksheetBlock> blocks;
  final bool locked;

  ResourcePreset copyWith({
    String? name,
    Map<String, bool>? toggles,
    List<WorksheetBlock>? blocks,
    bool? locked,
  }) =>
      ResourcePreset(
        id: id,
        name: name ?? this.name,
        resourceType: resourceType,
        toggles: toggles ?? this.toggles,
        blocks: blocks ?? this.blocks,
        locked: locked ?? this.locked,
      );
}

@immutable
class WorksheetBlock {
  const WorksheetBlock({
    required this.id,
    required this.type,
    required this.label,
    this.placeholder = '',
    this.columns = 1,
    this.questionTypes = const [],
  });
  final String id;
  final WorksheetBlockType type;
  final String label, placeholder;

  /// For Questions blocks: number of columns to render in (1, 2, 3).
  final int columns;

  /// For Questions blocks: which question-type names are used (from Field Editor).
  final List<String> questionTypes;

  WorksheetBlock copyWith({
    String? label,
    String? placeholder,
    int? columns,
    List<String>? questionTypes,
  }) =>
      WorksheetBlock(
        id: id,
        type: type,
        label: label ?? this.label,
        placeholder: placeholder ?? this.placeholder,
        columns: columns ?? this.columns,
        questionTypes: questionTypes ?? this.questionTypes,
      );
}

enum WorksheetBlockType {
  title,
  lesson,
  objectives,
  instructions,
  questions,
  image,
  table,
  answerKey,
  notes,
  custom;

  String get label => switch (this) {
        WorksheetBlockType.title => 'Title',
        WorksheetBlockType.lesson => 'Lesson',
        WorksheetBlockType.objectives => 'Objectives',
        WorksheetBlockType.instructions => 'Instructions',
        WorksheetBlockType.questions => 'Questions',
        WorksheetBlockType.image => 'Image',
        WorksheetBlockType.table => 'Table',
        WorksheetBlockType.answerKey => 'Answer Key',
        WorksheetBlockType.notes => 'Notes',
        WorksheetBlockType.custom => 'Custom',
      };
}

// ── Prompts ────────────────────────────────────────────────────────────────

@immutable
class PromptTemplate {
  const PromptTemplate({
    required this.id,
    required this.name,
    required this.role,
    required this.instructions,
    required this.constraints,
    required this.style,
    this.locked = true,
  });
  final String id, name, role, instructions, constraints, style;
  final bool locked;

  PromptTemplate copyWith({
    String? name,
    String? role,
    String? instructions,
    String? constraints,
    String? style,
    bool? locked,
  }) =>
      PromptTemplate(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        instructions: instructions ?? this.instructions,
        constraints: constraints ?? this.constraints,
        style: style ?? this.style,
        locked: locked ?? this.locked,
      );
}

// ── Profile ────────────────────────────────────────────────────────────────

@immutable
class TeacherProfile {
  const TeacherProfile({
    this.name = '',
    this.designation = '',
    this.school = '',
    this.subjects = const [],
    this.grades = const [],
    this.locked = false,
  });
  final String name, designation, school;
  final List<String> subjects, grades;
  final bool locked;

  TeacherProfile copyWith({
    String? name,
    String? designation,
    String? school,
    List<String>? subjects,
    List<String>? grades,
    bool? locked,
  }) =>
      TeacherProfile(
        name: name ?? this.name,
        designation: designation ?? this.designation,
        school: school ?? this.school,
        subjects: subjects ?? this.subjects,
        grades: grades ?? this.grades,
        locked: locked ?? this.locked,
      );
}

// ── Brand & Layout ─────────────────────────────────────────────────────────

enum DocFormat {
  docx,
  pdf,
  pptx;

  String get label => switch (this) {
        DocFormat.docx => 'Word',
        DocFormat.pdf => 'PDF',
        DocFormat.pptx => 'PPT',
      };
}

enum PageSize {
  a4,
  letter;

  String get label => switch (this) {
        PageSize.a4 => 'A4',
        PageSize.letter => 'US Letter',
      };
}

enum SlideAspect {
  ar16_9,
  ar4_3,
  custom;

  String get label => switch (this) {
        SlideAspect.ar16_9 => '16:9',
        SlideAspect.ar4_3 => '4:3',
        SlideAspect.custom => 'Custom',
      };
  double get ratio => switch (this) {
        SlideAspect.ar16_9 => 16 / 9,
        SlideAspect.ar4_3 => 4 / 3,
        SlideAspect.custom => 16 / 10,
      };
}

enum PdfMode { document, slides }

enum LogoPosition { left, center, right }

enum FooterAlignment { left, center, right }

/// Separate font settings for heading vs body.
@immutable
class TypographyPair {
  const TypographyPair({
    this.headingSize = 18,
    this.headingWeight = 700,
    this.bodySize = 11,
    this.bodyWeight = 400,
    this.lineSpacing = 1.15,
  });
  final double headingSize, bodySize, lineSpacing;
  final int headingWeight, bodyWeight;

  TypographyPair copyWith({
    double? headingSize,
    int? headingWeight,
    double? bodySize,
    int? bodyWeight,
    double? lineSpacing,
  }) =>
      TypographyPair(
        headingSize: headingSize ?? this.headingSize,
        headingWeight: headingWeight ?? this.headingWeight,
        bodySize: bodySize ?? this.bodySize,
        bodyWeight: bodyWeight ?? this.bodyWeight,
        lineSpacing: lineSpacing ?? this.lineSpacing,
      );
}

@immutable
class PageLayout {
  const PageLayout({
    this.pageSize = PageSize.a4,
    this.marginTop = 20,
    this.marginBottom = 20,
    this.marginLeft = 20,
    this.marginRight = 20,
    this.typography = const TypographyPair(),
    this.logoPosition = LogoPosition.left,
    this.footerAlignment = FooterAlignment.center,
    // PPT-specific:
    this.slideAspect = SlideAspect.ar16_9,
    // PDF-specific:
    this.pdfMode = PdfMode.document,
  });
  final PageSize pageSize;
  final double marginTop, marginBottom, marginLeft, marginRight;
  final TypographyPair typography;
  final LogoPosition logoPosition;
  final FooterAlignment footerAlignment;
  final SlideAspect slideAspect;
  final PdfMode pdfMode;

  PageLayout copyWith({
    PageSize? pageSize,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
    TypographyPair? typography,
    LogoPosition? logoPosition,
    FooterAlignment? footerAlignment,
    SlideAspect? slideAspect,
    PdfMode? pdfMode,
  }) =>
      PageLayout(
        pageSize: pageSize ?? this.pageSize,
        marginTop: marginTop ?? this.marginTop,
        marginBottom: marginBottom ?? this.marginBottom,
        marginLeft: marginLeft ?? this.marginLeft,
        marginRight: marginRight ?? this.marginRight,
        typography: typography ?? this.typography,
        logoPosition: logoPosition ?? this.logoPosition,
        footerAlignment: footerAlignment ?? this.footerAlignment,
        slideAspect: slideAspect ?? this.slideAspect,
        pdfMode: pdfMode ?? this.pdfMode,
      );
}

@immutable
class Branding {
  const Branding({
    this.logoPath,
    this.schoolName = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.footerText = '',
    this.applyOnExport = true,
    this.locked = false,
    this.layouts = const {
      DocFormat.docx: PageLayout(),
      DocFormat.pdf: PageLayout(),
      DocFormat.pptx: PageLayout(),
    },
  });
  final String? logoPath;
  final String schoolName, address, phone, email, footerText;
  final bool applyOnExport, locked;
  final Map<DocFormat, PageLayout> layouts;

  PageLayout layoutFor(DocFormat f) => layouts[f] ?? const PageLayout();

  Branding copyWith({
    String? logoPath,
    String? schoolName,
    String? address,
    String? phone,
    String? email,
    String? footerText,
    bool? applyOnExport,
    bool? locked,
    Map<DocFormat, PageLayout>? layouts,
  }) =>
      Branding(
        logoPath: logoPath ?? this.logoPath,
        schoolName: schoolName ?? this.schoolName,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        footerText: footerText ?? this.footerText,
        applyOnExport: applyOnExport ?? this.applyOnExport,
        locked: locked ?? this.locked,
        layouts: layouts ?? this.layouts,
      );

  Branding withLayout(DocFormat f, PageLayout l) {
    final next = Map<DocFormat, PageLayout>.from(layouts);
    next[f] = l;
    return copyWith(layouts: next);
  }
}

// ── Studio request ─────────────────────────────────────────────────────────

enum OutputLanguageMode {
  monolingual,
  bilingual,
  multilingual;

  String get label => switch (this) {
        OutputLanguageMode.monolingual => 'Mono',
        OutputLanguageMode.bilingual => 'Bilingual',
        OutputLanguageMode.multilingual => 'Multi',
      };
  int? get maxLanguages => switch (this) {
        OutputLanguageMode.monolingual => 1,
        OutputLanguageMode.bilingual => 2,
        OutputLanguageMode.multilingual => null,
      };
}

@immutable
class GenerationRequest {
  const GenerationRequest({
    required this.resourceType,
    required this.subject,
    required this.grade,
    required this.lesson,
    required this.topic,
    required this.objective,
    required this.languageMode,
    required this.languages,
    required this.extraInstructions,
    required this.formatToggles,
    required this.useExactTextbook,
    required this.useAdditionalContent,
    required this.sourceText,
    this.uploadIds = const [],
    this.webSearchQuery = '',
    this.webSearchResultCount = 0,
    // NEW — Craft step data
    this.activeFields = const [], // FieldToggle list of enabled fields
    this.composition = const OutputComposition(),
    this.format = const FormatSettings(),
    this.preparedByLine = '', // "Prepared by Anitha Ramanathan"
  });

  final ResourceType resourceType;
  final String subject,
      grade,
      lesson,
      topic,
      objective,
      extraInstructions,
      sourceText;
  final OutputLanguageMode languageMode;
  final List<String> languages, uploadIds;
  final Map<String, bool> formatToggles;
  final bool useExactTextbook, useAdditionalContent;
  final String webSearchQuery;
  final int webSearchResultCount;

  // NEW
  final List<FieldToggle> activeFields;
  final OutputComposition composition;
  final FormatSettings format;
  final String preparedByLine;

  Map<String, dynamic> toJson() => {
        'resource_type': resourceType.apiKey,
        'subject': subject,
        'grade': grade,
        'lesson': lesson,
        'topic': topic,
        'objective': objective,
        'language_mode': languageMode.name,
        'languages': languages,
        'extra_instructions': extraInstructions,
        'format_toggles': formatToggles,
        'use_exact_textbook': useExactTextbook,
        'use_additional_content': useAdditionalContent,
        'source_text': sourceText,
        'upload_ids': uploadIds,
        'web_search_query': webSearchQuery,
        'web_search_result_count': webSearchResultCount,
        // NEW — Craft step data flows into prompt
        'enabled_fields': [
          for (final f in activeFields)
            if (f.enabled) {'id': f.id, 'label': f.label}
        ],
        'composition': {
          'mode': composition.mode.name,
          'include_questions': composition.includeQuestions,
          'include_answers': composition.includeAnswers,
          'include_mark_scheme': composition.includeMarkScheme,
          'include_rubric': composition.includeRubric,
          'include_workings': composition.includeWorkings,
          'include_hints': composition.includeHints,
          'separate_answer_key': composition.separateAnswerKey,
        },
        'format': format.toJson(),
        'prepared_by_line': preparedByLine,
      };
}

/// Per-document header/footer override at Studio Output step.
@immutable
class HeaderFooterOverride {
  const HeaderFooterOverride(
      {this.includeHeader = true, this.includeFooter = true});
  final bool includeHeader, includeFooter;
  HeaderFooterOverride copyWith({bool? includeHeader, bool? includeFooter}) =>
      HeaderFooterOverride(
        includeHeader: includeHeader ?? this.includeHeader,
        includeFooter: includeFooter ?? this.includeFooter,
      );
}

// ── Uploads (Source Library) ───────────────────────────────────────────────

enum UploadSource { studio, curriculum, drive }

@immutable
class UploadRecord {
  const UploadRecord({
    required this.id,
    required this.fileName,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.source,
    this.tags = const [],
    this.parsedTextPreview,
    this.usedInResourceIds = const [],
  });
  final String id, fileName;
  final int sizeBytes;
  final DateTime uploadedAt;
  final UploadSource source;
  final List<String> tags;
  final String? parsedTextPreview;
  final List<String> usedInResourceIds;

  String get extension {
    final i = fileName.lastIndexOf('.');
    return i >= 0 ? fileName.substring(i + 1).toLowerCase() : '';
  }

  UploadRecord copyWith({
    String? fileName,
    List<String>? tags,
    List<String>? usedInResourceIds,
  }) =>
      UploadRecord(
        id: id,
        fileName: fileName ?? this.fileName,
        sizeBytes: sizeBytes,
        uploadedAt: uploadedAt,
        source: source,
        tags: tags ?? this.tags,
        parsedTextPreview: parsedTextPreview,
        usedInResourceIds: usedInResourceIds ?? this.usedInResourceIds,
      );
}

// ── Model mode + Gemma version ─────────────────────────────────────────────

enum ModelMode {
  local('local'),
  cloud('cloud'),
  auto('auto');

  const ModelMode(this.apiKey);
  final String apiKey;
}

enum ModelBadge { local, cloud, offline }

enum GemmaVersion {
  e2b('E2B', 'Gemma 4 E2B (lightweight, ~3GB RAM)', '1.5 GB'),
  e4b('E4B', 'Gemma 4 E4B (balanced, ~6GB RAM)', '3.2 GB'),
  moe26ba4b('26B-A4B', 'Gemma 4 26B-A4B MoE (cloud only)', '14 GB');

  const GemmaVersion(this.code, this.description, this.size);
  final String code, description, size;
}

// ════════════════════════════════════════════════════════════════════════════
// APPEND THIS TO THE END OF lib/models/models.dart
// ════════════════════════════════════════════════════════════════════════════

// ── Output mode for question-bearing resources (worksheet/QP) ──────────────

enum OutputMode {
  questionsOnly,
  answersOnly,
  both;

  String get label => switch (this) {
        OutputMode.questionsOnly => 'Questions only',
        OutputMode.answersOnly => 'Answers + mark scheme',
        OutputMode.both => 'Both together',
      };
}

@immutable
class OutputComposition {
  const OutputComposition({
    this.mode = OutputMode.both,
    this.includeQuestions = true,
    this.includeAnswers = true,
    this.includeMarkScheme = true,
    this.includeRubric = false,
    this.includeWorkings = false,
    this.includeHints = false,
    this.separateAnswerKey = false,
  });
  final OutputMode mode;
  final bool includeQuestions, includeAnswers, includeMarkScheme;
  final bool includeRubric, includeWorkings, includeHints;

  /// When true, answer key exports as a SEPARATE document.
  final bool separateAnswerKey;

  OutputComposition copyWith({
    OutputMode? mode,
    bool? includeQuestions,
    bool? includeAnswers,
    bool? includeMarkScheme,
    bool? includeRubric,
    bool? includeWorkings,
    bool? includeHints,
    bool? separateAnswerKey,
  }) =>
      OutputComposition(
        mode: mode ?? this.mode,
        includeQuestions: includeQuestions ?? this.includeQuestions,
        includeAnswers: includeAnswers ?? this.includeAnswers,
        includeMarkScheme: includeMarkScheme ?? this.includeMarkScheme,
        includeRubric: includeRubric ?? this.includeRubric,
        includeWorkings: includeWorkings ?? this.includeWorkings,
        includeHints: includeHints ?? this.includeHints,
        separateAnswerKey: separateAnswerKey ?? this.separateAnswerKey,
      );

  /// Apply mode preset to the booleans.
  OutputComposition applyMode(OutputMode m) {
    switch (m) {
      case OutputMode.questionsOnly:
        return copyWith(
          mode: m,
          includeQuestions: true,
          includeAnswers: false,
          includeMarkScheme: false,
          includeWorkings: false,
        );
      case OutputMode.answersOnly:
        return copyWith(
          mode: m,
          includeQuestions: false,
          includeAnswers: true,
          includeMarkScheme: true,
        );
      case OutputMode.both:
        return copyWith(
          mode: m,
          includeQuestions: true,
          includeAnswers: true,
          includeMarkScheme: true,
        );
    }
  }
}

// ── Accessibility settings ─────────────────────────────────────────────────

@immutable
class AccessibilitySettings {
  const AccessibilitySettings({
    this.fontScale = 1.0,
    this.highContrast = false,
    this.reduceMotion = false,
    this.dyslexiaFont = false,
    this.largerTouchTargets = false,
    this.screenReaderHints = false,
    this.colorblindSafePalette = false,
  });
  final double fontScale; // 0.85 .. 1.5
  final bool highContrast, reduceMotion, dyslexiaFont;
  final bool largerTouchTargets, screenReaderHints, colorblindSafePalette;

  AccessibilitySettings copyWith({
    double? fontScale,
    bool? highContrast,
    bool? reduceMotion,
    bool? dyslexiaFont,
    bool? largerTouchTargets,
    bool? screenReaderHints,
    bool? colorblindSafePalette,
  }) =>
      AccessibilitySettings(
        fontScale: fontScale ?? this.fontScale,
        highContrast: highContrast ?? this.highContrast,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        dyslexiaFont: dyslexiaFont ?? this.dyslexiaFont,
        largerTouchTargets: largerTouchTargets ?? this.largerTouchTargets,
        screenReaderHints: screenReaderHints ?? this.screenReaderHints,
        colorblindSafePalette:
            colorblindSafePalette ?? this.colorblindSafePalette,
      );
}

// ── Resource version history ───────────────────────────────────────────────

@immutable
class ResourceVersion {
  const ResourceVersion({
    required this.id,
    required this.resourceId,
    required this.versionNumber,
    required this.savedAt,
    required this.content,
    this.title,
    this.note = '',
  });
  final String id, resourceId, content, note;
  final String? title;
  final int versionNumber;
  final DateTime savedAt;
}

// ── Resource Field Set ─────────────────────────────────────────────────────
// Per-resource-type field definitions. Drives the dynamic Craft "Fields"
// section AND syncs with Resource Templates.

enum FieldDataKind {
  text, // single-line text
  longText, // multi-line
  number, // numeric
  list, // comma-separated list
  questions, // structured questions block (with sub-questions, marks)
  toggle, // boolean
  reference, // points to a curriculum item (lesson, LO, etc.)
}

@immutable
class ResourceField {
  const ResourceField({
    required this.id,
    required this.label,
    required this.kind,
    this.required = true,
    this.placeholder = '',
    this.syncedFrom = '', // 'curriculum.lessons', 'profile.name', etc.
  });
  final String id, label, placeholder, syncedFrom;
  final FieldDataKind kind;
  final bool required;

  ResourceField copyWith(
          {String? label,
          FieldDataKind? kind,
          bool? required,
          String? placeholder,
          String? syncedFrom}) =>
      ResourceField(
        id: id,
        label: label ?? this.label,
        kind: kind ?? this.kind,
        required: required ?? this.required,
        placeholder: placeholder ?? this.placeholder,
        syncedFrom: syncedFrom ?? this.syncedFrom,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'kind': kind.name,
        'required': required,
        'placeholder': placeholder,
        'synced_from': syncedFrom,
      };
}

@immutable
class ResourceFieldSet {
  const ResourceFieldSet({required this.resourceType, required this.fields});
  final String resourceType; // matches ResourceType.apiKey
  final List<ResourceField> fields;

  ResourceFieldSet copyWith({List<ResourceField>? fields}) => ResourceFieldSet(
      resourceType: resourceType, fields: fields ?? this.fields);

  /// Default field sets per resource type. Users can customize in Templates.
  static List<ResourceFieldSet> defaults() => const [
        ResourceFieldSet(resourceType: 'worksheet', fields: [
          ResourceField(
              id: 'lesson_name',
              label: 'Lesson name',
              kind: FieldDataKind.text,
              syncedFrom: 'curriculum.lessons'),
          ResourceField(id: 'topic', label: 'Topic', kind: FieldDataKind.text),
          ResourceField(
              id: 'learning_outcomes',
              label: 'Learning Outcomes',
              kind: FieldDataKind.list,
              syncedFrom: 'curriculum.outcomes'),
          ResourceField(
              id: 'questions',
              label: 'Questions',
              kind: FieldDataKind.questions),
          ResourceField(
              id: 'answers',
              label: 'Answers',
              kind: FieldDataKind.questions,
              required: false),
        ]),
        ResourceFieldSet(resourceType: 'notes', fields: [
          ResourceField(
              id: 'lesson_name',
              label: 'Lesson name',
              kind: FieldDataKind.text,
              syncedFrom: 'curriculum.lessons'),
          ResourceField(id: 'topic', label: 'Topic', kind: FieldDataKind.text),
          ResourceField(
              id: 'concepts',
              label: 'Concepts (one per line)',
              kind: FieldDataKind.longText),
          ResourceField(
              id: 'notes_per_concept',
              label: 'Notes per concept',
              kind: FieldDataKind.longText),
          ResourceField(
              id: 'questions',
              label: 'Review Questions',
              kind: FieldDataKind.questions,
              required: false),
          ResourceField(
              id: 'answers',
              label: 'Answers',
              kind: FieldDataKind.questions,
              required: false),
        ]),
        ResourceFieldSet(resourceType: 'question_paper', fields: [
          ResourceField(
              id: 'test_name', label: 'Test name', kind: FieldDataKind.text),
          ResourceField(
              id: 'total_marks',
              label: 'Total marks',
              kind: FieldDataKind.number),
          ResourceField(
              id: 'duration',
              label: 'Time / duration',
              kind: FieldDataKind.text,
              placeholder: 'e.g. 1 hour 30 min'),
          ResourceField(
              id: 'instructions',
              label: 'General instructions',
              kind: FieldDataKind.longText),
          ResourceField(
              id: 'questions',
              label: 'Questions (with sections & marks)',
              kind: FieldDataKind.questions),
          ResourceField(
              id: 'answer_key',
              label: 'Answer key',
              kind: FieldDataKind.questions,
              required: false),
          ResourceField(
              id: 'marking_scheme',
              label: 'Marking scheme',
              kind: FieldDataKind.longText,
              required: false),
        ]),
        ResourceFieldSet(resourceType: 'lesson_plan', fields: [
          ResourceField(
              id: 'lesson_name',
              label: 'Lesson name',
              kind: FieldDataKind.text,
              syncedFrom: 'curriculum.lessons'),
          ResourceField(id: 'topic', label: 'Topic', kind: FieldDataKind.text),
          ResourceField(
              id: 'duration',
              label: 'Duration',
              kind: FieldDataKind.text,
              placeholder: 'e.g. 45 minutes'),
          ResourceField(
              id: 'learning_outcomes',
              label: 'Learning Outcomes',
              kind: FieldDataKind.list,
              syncedFrom: 'curriculum.outcomes'),
          ResourceField(
              id: 'materials',
              label: 'Materials needed',
              kind: FieldDataKind.list),
          ResourceField(
              id: 'procedure',
              label: 'Procedure / Activities',
              kind: FieldDataKind.longText),
          ResourceField(
              id: 'assessment',
              label: 'Assessment',
              kind: FieldDataKind.longText),
        ]),
        ResourceFieldSet(resourceType: 'activity', fields: [
          ResourceField(
              id: 'lesson_name',
              label: 'Lesson name',
              kind: FieldDataKind.text,
              syncedFrom: 'curriculum.lessons'),
          ResourceField(
              id: 'objective',
              label: 'Activity objective',
              kind: FieldDataKind.text),
          ResourceField(
              id: 'duration', label: 'Duration', kind: FieldDataKind.text),
          ResourceField(
              id: 'materials', label: 'Materials', kind: FieldDataKind.list),
          ResourceField(
              id: 'steps',
              label: 'Step-by-step instructions',
              kind: FieldDataKind.longText),
        ]),
        ResourceFieldSet(resourceType: 'presentation', fields: [
          ResourceField(
              id: 'title',
              label: 'Presentation title',
              kind: FieldDataKind.text),
          ResourceField(
              id: 'lesson_name',
              label: 'Lesson',
              kind: FieldDataKind.text,
              syncedFrom: 'curriculum.lessons'),
          ResourceField(
              id: 'topics', label: 'Topics to cover', kind: FieldDataKind.list),
          ResourceField(
              id: 'slide_count',
              label: 'Approximate slide count',
              kind: FieldDataKind.number),
        ]),
      ];
}

// ── Format Preferences ─────────────────────────────────────────────────────
// Third section of Craft step.

@immutable
class FormatPreferences {
  const FormatPreferences({
    this.includeHeader = true,
    this.includeFooter = true,
    this.colorMode = 'color', // 'color' | 'bw'
    this.showTableBorders = true,
    this.includePreparedBy = true,
    this.preparedByText = '', // auto-filled from profile.name
  });
  final bool includeHeader, includeFooter, showTableBorders, includePreparedBy;
  final String colorMode, preparedByText;

  FormatPreferences copyWith({
    bool? includeHeader,
    bool? includeFooter,
    String? colorMode,
    bool? showTableBorders,
    bool? includePreparedBy,
    String? preparedByText,
  }) =>
      FormatPreferences(
        includeHeader: includeHeader ?? this.includeHeader,
        includeFooter: includeFooter ?? this.includeFooter,
        colorMode: colorMode ?? this.colorMode,
        showTableBorders: showTableBorders ?? this.showTableBorders,
        includePreparedBy: includePreparedBy ?? this.includePreparedBy,
        preparedByText: preparedByText ?? this.preparedByText,
      );
}

// ── Hierarchical Question Groups (v1: one level deep) ──────────────────────

@immutable
class QuestionItem {
  const QuestionItem({
    required this.id,
    this.stem = '',
    this.marks = 1,
    this.subQuestions = const [],
  });
  final String id;
  final String stem;
  final int marks;

  /// One level of nesting: A.I.q1, A.II.q1 etc. Sub-questions cannot nest deeper.
  final List<QuestionItem> subQuestions;

  QuestionItem copyWith(
          {String? stem, int? marks, List<QuestionItem>? subQuestions}) =>
      QuestionItem(
        id: id,
        stem: stem ?? this.stem,
        marks: marks ?? this.marks,
        subQuestions: subQuestions ?? this.subQuestions,
      );
}

@immutable
class QuestionSection {
  const QuestionSection({
    required this.id,
    required this.label,
    this.instruction = '',
    this.numberingStyle = 'numeric', // 'numeric' | 'alpha' | 'roman'
    this.resetNumbering = true,
    this.items = const [],
  });

  /// e.g. "A. Do as directed"
  final String id, label, instruction, numberingStyle;
  final bool resetNumbering;
  final List<QuestionItem> items;

  QuestionSection copyWith(
          {String? label,
          String? instruction,
          String? numberingStyle,
          bool? resetNumbering,
          List<QuestionItem>? items}) =>
      QuestionSection(
        id: id,
        label: label ?? this.label,
        instruction: instruction ?? this.instruction,
        numberingStyle: numberingStyle ?? this.numberingStyle,
        resetNumbering: resetNumbering ?? this.resetNumbering,
        items: items ?? this.items,
      );
}

// ── Field toggles (Craft step "Fields" section) ────────────────────────────
//
// Each field defined by the active Resource Template can be toggled on/off
// per generation. Worksheet's template might define [lesson, topic, los,
// questions, answers]; teacher can untick "answers" for a specific generation
// without changing the template.

@immutable
class FieldToggle {
  const FieldToggle({
    required this.id,
    required this.label,
    this.enabled = true,
    this.locked = false,
  });
  final String id;
  final String label;
  final bool enabled;
  final bool locked;

  FieldToggle copyWith({String? label, bool? enabled, bool? locked}) =>
      FieldToggle(
        id: id,
        label: label ?? this.label,
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
      );
}

/// Default field set for each resource type. The Resource Template can
/// customize these, but these are the starting point.
class DefaultFieldSets {
  static List<FieldToggle> forType(ResourceType type) {
    switch (type) {
      case ResourceType.worksheet:
        return const [
          FieldToggle(id: 'lesson', label: 'Lesson name'),
          FieldToggle(id: 'topic', label: 'Topic'),
          FieldToggle(id: 'objectives', label: 'Learning objectives'),
          FieldToggle(id: 'instructions', label: 'Instructions to student'),
          FieldToggle(id: 'questions', label: 'Questions'),
          FieldToggle(id: 'answers', label: 'Answer key'),
          FieldToggle(id: 'marks', label: 'Marks per question'),
        ];
      case ResourceType.lessonPlan:
        return const [
          FieldToggle(id: 'lesson', label: 'Lesson name'),
          FieldToggle(id: 'topic', label: 'Topic'),
          FieldToggle(id: 'duration', label: 'Duration'),
          FieldToggle(id: 'objectives', label: 'Learning objectives'),
          FieldToggle(id: 'materials', label: 'Materials needed'),
          FieldToggle(id: 'procedure', label: 'Teaching procedure'),
          FieldToggle(id: 'assessment', label: 'Assessment'),
          FieldToggle(id: 'homework', label: 'Homework / extension'),
        ];
      case ResourceType.questionPaper:
        return const [
          FieldToggle(id: 'testName', label: 'Test name'),
          FieldToggle(id: 'totalMarks', label: 'Total marks'),
          FieldToggle(id: 'duration', label: 'Time allowed'),
          FieldToggle(id: 'instructions', label: 'General instructions'),
          FieldToggle(id: 'sections', label: 'Sections (A, B, C…)'),
          FieldToggle(id: 'marksPerQ', label: 'Marks per question'),
          FieldToggle(id: 'questions', label: 'Questions'),
          FieldToggle(id: 'answerKey', label: 'Answer key'),
          FieldToggle(id: 'markScheme', label: 'Mark scheme'),
        ];
      case ResourceType.notes:
        return const [
          FieldToggle(id: 'lesson', label: 'Lesson name'),
          FieldToggle(id: 'topic', label: 'Topic'),
          FieldToggle(id: 'concepts', label: 'Concepts with explanations'),
          FieldToggle(id: 'examples', label: 'Worked examples'),
          FieldToggle(id: 'keyPoints', label: 'Key points summary'),
          FieldToggle(id: 'practiceQs', label: 'Practice questions'),
          FieldToggle(id: 'answers', label: 'Practice answers'),
        ];
      case ResourceType.activity:
        return const [
          FieldToggle(id: 'title', label: 'Activity title'),
          FieldToggle(id: 'objective', label: 'Activity objective'),
          FieldToggle(id: 'materials', label: 'Materials'),
          FieldToggle(id: 'steps', label: 'Steps'),
          FieldToggle(id: 'rubric', label: 'Assessment rubric'),
        ];
      case ResourceType.presentation:
        return const [
          FieldToggle(id: 'title', label: 'Title slide'),
          FieldToggle(id: 'objectives', label: 'Objectives slide'),
          FieldToggle(id: 'content', label: 'Content slides'),
          FieldToggle(id: 'examples', label: 'Examples'),
          FieldToggle(id: 'summary', label: 'Summary slide'),
        ];
    }
  }
}

// ── Format settings (Craft step "Format" section) ──────────────────────────

enum AlignmentChoice { left, center, right, justify }

@immutable
class FormatSettings {
  const FormatSettings({
    this.includeHeader = true,
    this.includeFooter = true,
    this.includePageNumber = true,
    this.includePreparedBy = true,
    this.preparedByPrefix = 'Prepared by',
    this.colorMode = 'color', // 'color' | 'bw'
    this.tableBorders = true,
    this.bodyAlignment = AlignmentChoice.left,
    this.headingAlignment = AlignmentChoice.left,
    this.boldHeaders = true,
    this.numberedItems = true,
  });

  final bool includeHeader;
  final bool includeFooter;
  final bool includePageNumber;
  final bool includePreparedBy;
  final String preparedByPrefix;
  final String colorMode;
  final bool tableBorders;
  final AlignmentChoice bodyAlignment;
  final AlignmentChoice headingAlignment;
  final bool boldHeaders;
  final bool numberedItems;

  FormatSettings copyWith({
    bool? includeHeader,
    bool? includeFooter,
    bool? includePageNumber,
    bool? includePreparedBy,
    String? preparedByPrefix,
    String? colorMode,
    bool? tableBorders,
    AlignmentChoice? bodyAlignment,
    AlignmentChoice? headingAlignment,
    bool? boldHeaders,
    bool? numberedItems,
  }) =>
      FormatSettings(
        includeHeader: includeHeader ?? this.includeHeader,
        includeFooter: includeFooter ?? this.includeFooter,
        includePageNumber: includePageNumber ?? this.includePageNumber,
        includePreparedBy: includePreparedBy ?? this.includePreparedBy,
        preparedByPrefix: preparedByPrefix ?? this.preparedByPrefix,
        colorMode: colorMode ?? this.colorMode,
        tableBorders: tableBorders ?? this.tableBorders,
        bodyAlignment: bodyAlignment ?? this.bodyAlignment,
        headingAlignment: headingAlignment ?? this.headingAlignment,
        boldHeaders: boldHeaders ?? this.boldHeaders,
        numberedItems: numberedItems ?? this.numberedItems,
      );

  Map<String, dynamic> toJson() => {
        'include_header': includeHeader,
        'include_footer': includeFooter,
        'include_page_number': includePageNumber,
        'include_prepared_by': includePreparedBy,
        'prepared_by_prefix': preparedByPrefix,
        'color_mode': colorMode,
        'table_borders': tableBorders,
        'body_alignment': bodyAlignment.name,
        'heading_alignment': headingAlignment.name,
        'bold_headers': boldHeaders,
        'numbered_items': numberedItems,
      };
}
