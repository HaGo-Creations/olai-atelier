// lib/models/question_schema.dart
//
// Structured schemas for question types. Each question type has fields
// (stem, options, answer, binary) that define how the AI should generate it
// and how it's rendered/exported. Users can define new types from scratch.

import 'package:flutter/foundation.dart';

/// What kind of field a question type uses.
enum QFieldKind {
  stem, // The question prompt text
  options, // A list of choices (MCQ-style)
  answer, // A text answer
  binary, // True/False or Yes/No
  blanks, // Number of blanks in fill-in-blanks
  matchPairs, // Left-right pairs for matching
  numeric, // A numeric answer
  diagram, // Reference to a diagram/image
  custom, // User-defined free-text field
}

@immutable
class QSchemaField {
  const QSchemaField({
    required this.id,
    required this.label,
    required this.kind,
    this.required = true,
    this.optionCount = 4,
    this.allowMoreOptions = false,
  });
  final String id, label;
  final QFieldKind kind;
  final bool required;

  /// For options/blanks/matchPairs: how many by default.
  final int optionCount;
  final bool allowMoreOptions;

  QSchemaField copyWith({
    String? label,
    QFieldKind? kind,
    bool? required,
    int? optionCount,
    bool? allowMoreOptions,
  }) =>
      QSchemaField(
        id: id,
        label: label ?? this.label,
        kind: kind ?? this.kind,
        required: required ?? this.required,
        optionCount: optionCount ?? this.optionCount,
        allowMoreOptions: allowMoreOptions ?? this.allowMoreOptions,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'kind': kind.name,
        'required': required,
        'option_count': optionCount,
        'allow_more': allowMoreOptions,
      };
}

@immutable
class QuestionSchema {
  const QuestionSchema({
    required this.id,
    required this.name,
    required this.fields,
    this.locked = false,
    this.builtIn = false,
  });
  final String id, name;
  final List<QSchemaField> fields;
  final bool locked, builtIn;

  QuestionSchema copyWith({
    String? name,
    List<QSchemaField>? fields,
    bool? locked,
  }) =>
      QuestionSchema(
        id: id,
        name: name ?? this.name,
        fields: fields ?? this.fields,
        locked: locked ?? this.locked,
        builtIn: builtIn,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'built_in': builtIn,
        'fields': [for (final f in fields) f.toJson()],
      };

  /// Built-in defaults seeded into the Field Editor.
  static List<QuestionSchema> defaults() => const [
        QuestionSchema(id: 'qs-mcq', name: 'MCQ', builtIn: true, fields: [
          QSchemaField(id: 'stem', label: 'Stem', kind: QFieldKind.stem),
          QSchemaField(
              id: 'opts',
              label: 'Options',
              kind: QFieldKind.options,
              optionCount: 4,
              allowMoreOptions: true),
          QSchemaField(
              id: 'ans', label: 'Correct answer', kind: QFieldKind.answer),
        ]),
        QuestionSchema(
            id: 'qs-short',
            name: 'Short Answer',
            builtIn: true,
            fields: [
              QSchemaField(
                  id: 'stem', label: 'Question', kind: QFieldKind.stem),
              QSchemaField(
                  id: 'ans',
                  label: 'Expected answer',
                  kind: QFieldKind.answer,
                  required: false),
            ]),
        QuestionSchema(
            id: 'qs-long',
            name: 'Long Answer',
            builtIn: true,
            fields: [
              QSchemaField(
                  id: 'stem', label: 'Question', kind: QFieldKind.stem),
              QSchemaField(
                  id: 'ans',
                  label: 'Model answer',
                  kind: QFieldKind.answer,
                  required: false),
            ]),
        QuestionSchema(id: 'qs-tf', name: 'True/False', builtIn: true, fields: [
          QSchemaField(id: 'stem', label: 'Statement', kind: QFieldKind.stem),
          QSchemaField(id: 'ans', label: 'Answer', kind: QFieldKind.binary),
        ]),
        QuestionSchema(
            id: 'qs-fib',
            name: 'Fill in the Blanks',
            builtIn: true,
            fields: [
              QSchemaField(
                  id: 'stem',
                  label: 'Sentence with blanks',
                  kind: QFieldKind.stem),
              QSchemaField(
                  id: 'blanks',
                  label: 'Number of blanks',
                  kind: QFieldKind.blanks,
                  optionCount: 1),
              QSchemaField(
                  id: 'ans', label: 'Answers', kind: QFieldKind.answer),
            ]),
        QuestionSchema(
            id: 'qs-match',
            name: 'Match the Following',
            builtIn: true,
            fields: [
              QSchemaField(
                  id: 'stem',
                  label: 'Instruction',
                  kind: QFieldKind.stem,
                  required: false),
              QSchemaField(
                  id: 'pairs',
                  label: 'Match pairs',
                  kind: QFieldKind.matchPairs,
                  optionCount: 4,
                  allowMoreOptions: true),
            ]),
        QuestionSchema(
            id: 'qs-oneword',
            name: 'One-Word Answer',
            builtIn: true,
            fields: [
              QSchemaField(
                  id: 'stem', label: 'Question', kind: QFieldKind.stem),
              QSchemaField(
                  id: 'ans', label: 'One-word answer', kind: QFieldKind.answer),
            ]),
        QuestionSchema(
            id: 'qs-num',
            name: 'Numerical Problem',
            builtIn: true,
            fields: [
              QSchemaField(id: 'stem', label: 'Problem', kind: QFieldKind.stem),
              QSchemaField(
                  id: 'ans', label: 'Numeric answer', kind: QFieldKind.numeric),
              QSchemaField(
                  id: 'work',
                  label: 'Working shown',
                  kind: QFieldKind.answer,
                  required: false),
            ]),
        QuestionSchema(
            id: 'qs-word',
            name: 'Word Problem',
            builtIn: true,
            fields: [
              QSchemaField(
                  id: 'stem', label: 'Scenario', kind: QFieldKind.stem),
              QSchemaField(
                  id: 'ans',
                  label: 'Answer with reasoning',
                  kind: QFieldKind.answer),
            ]),
        QuestionSchema(
            id: 'qs-diagram',
            name: 'Diagram',
            builtIn: true,
            fields: [
              QSchemaField(
                  id: 'stem', label: 'Instruction', kind: QFieldKind.stem),
              QSchemaField(
                  id: 'img',
                  label: 'Reference diagram',
                  kind: QFieldKind.diagram),
              QSchemaField(
                  id: 'ans',
                  label: 'Labels / answer',
                  kind: QFieldKind.answer,
                  required: false),
            ]),
        QuestionSchema(
            id: 'qs-picture',
            name: 'Picture-Based',
            builtIn: true,
            fields: [
              QSchemaField(
                  id: 'stem',
                  label: 'Question about picture',
                  kind: QFieldKind.stem),
              QSchemaField(
                  id: 'img', label: 'Picture', kind: QFieldKind.diagram),
              QSchemaField(
                  id: 'ans',
                  label: 'Answer',
                  kind: QFieldKind.answer,
                  required: false),
            ]),
        QuestionSchema(
            id: 'qs-crossword',
            name: 'Crossword',
            builtIn: true,
            fields: [
              QSchemaField(id: 'stem', label: 'Clues', kind: QFieldKind.stem),
              QSchemaField(id: 'ans', label: 'Words', kind: QFieldKind.answer),
            ]),
        QuestionSchema(
            id: 'qs-sequence',
            name: 'Sequencing',
            builtIn: true,
            fields: [
              QSchemaField(
                  id: 'stem', label: 'Items to order', kind: QFieldKind.stem),
              QSchemaField(
                  id: 'opts',
                  label: 'Items',
                  kind: QFieldKind.options,
                  optionCount: 5,
                  allowMoreOptions: true),
              QSchemaField(
                  id: 'ans', label: 'Correct order', kind: QFieldKind.answer),
            ]),
        QuestionSchema(
            id: 'qs-categorize',
            name: 'Categorize',
            builtIn: true,
            fields: [
              QSchemaField(
                  id: 'stem', label: 'Instruction', kind: QFieldKind.stem),
              QSchemaField(
                  id: 'opts',
                  label: 'Items to sort',
                  kind: QFieldKind.options,
                  optionCount: 8,
                  allowMoreOptions: true),
              QSchemaField(
                  id: 'ans',
                  label: 'Categories with grouping',
                  kind: QFieldKind.answer),
            ]),
        QuestionSchema(
            id: 'qs-openended',
            name: 'Open-Ended',
            builtIn: true,
            fields: [
              QSchemaField(id: 'stem', label: 'Prompt', kind: QFieldKind.stem),
              QSchemaField(
                  id: 'ans',
                  label: 'Suggested response',
                  kind: QFieldKind.answer,
                  required: false),
            ]),
        QuestionSchema(
            id: 'qs-drawing',
            name: 'Drawing',
            builtIn: true,
            fields: [
              QSchemaField(
                  id: 'stem',
                  label: 'Drawing instruction',
                  kind: QFieldKind.stem),
              QSchemaField(
                  id: 'ans',
                  label: 'Key elements expected',
                  kind: QFieldKind.answer,
                  required: false),
            ]),
        QuestionSchema(id: 'qs-map', name: 'Map Work', builtIn: true, fields: [
          QSchemaField(id: 'stem', label: 'Instruction', kind: QFieldKind.stem),
          QSchemaField(
              id: 'img', label: 'Reference map', kind: QFieldKind.diagram),
          QSchemaField(
              id: 'ans', label: 'Labels expected', kind: QFieldKind.answer),
        ]),
      ];
}
