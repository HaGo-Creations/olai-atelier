// lib/screens/studio.dart
import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../main.dart';
import '../models/models.dart';
import '../services/download_helper.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/markdown_view.dart';

class _StudioState {
  int currentStep = 0;
  ResourceType? resourceType;
  String? subject;
  String? grade;
  String lesson = '';
  String topic = '';

  List<String> objectives = [];
  String extraInstructions = '';
  String sourceText = '';
  final List<String> uploadedFiles = [];
  final List<String> uploadIds = [];
  String? suggestedTopic;

  String webSearchQuery = '';
  int webSearchResultCount = 0;

  OutputLanguageMode langMode = OutputLanguageMode.monolingual;
  List<String> languages = const ['English'];

  bool useExactTextbook = true;
  bool useAdditionalContent = true;

  List<FieldToggle> fieldToggles = [];
  OutputComposition composition = const OutputComposition();
  FormatSettings format = const FormatSettings();

  String? generatedContent;
  bool generating = false;
  HeaderFooterOverride hf = const HeaderFooterOverride();

  String? savedResourceId;
  String tweakRefinement = '';
}

class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key});
  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  final _state = _StudioState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final preset = ref.read(studioPresetProvider);
      if (preset != null) {
        setState(() {
          _state.resourceType = preset;
          _state.fieldToggles = DefaultFieldSets.forType(preset);
        });
        ref.read(studioPresetProvider.notifier).state = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Studio',
      pastel: Pastels.studio,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Steps(
              currentStep: _state.currentStep,
              onTap: (i) {
                if (i < _state.currentStep) {
                  setState(() => _state.currentStep = i);
                }
              }),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: SingleChildScrollView(child: _stepContent())),
          const SizedBox(height: AppSpacing.md),
          _navigationButtons(),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _stepContent() {
    switch (_state.currentStep) {
      case 0:
        return _ExtractStep(state: _state, onChanged: _onExtractChanged);
      case 1:
        return _CraftStep(state: _state, onChanged: () => setState(() {}));
      case 2:
        return _GenerateStep(
          state: _state,
          onChanged: () => setState(() {}),
          onRegenerate: _regenerate,
          onSaveAndDone: _saveAndDone,
        );
    }
    return const SizedBox.shrink();
  }

  void _onExtractChanged() {
    setState(() {
      if (_state.resourceType != null && _state.fieldToggles.isEmpty) {
        _state.fieldToggles = DefaultFieldSets.forType(_state.resourceType!);
      }
    });
  }

  Widget _navigationButtons() {
    final isLast = _state.currentStep == 2;
    final canGoNext = _validateCurrentStep();

    if (isLast) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() => _state.currentStep -= 1),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to Craft'),
          ),
        ],
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 400;
      final backBtn = _state.currentStep > 0
          ? OutlinedButton.icon(
              onPressed: () => setState(() => _state.currentStep -= 1),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
            )
          : null;

      final nextBtn = FilledButton.icon(
        onPressed: canGoNext
            ? () async {
                if (_state.currentStep == 1) {
                  setState(() {
                    _state.currentStep = 2;
                    _state.generating = true;
                    _state.generatedContent = null;
                    _state.savedResourceId = null;
                  });
                  await _generate();
                } else {
                  setState(() {
                    _state.currentStep += 1;
                    if (_state.resourceType != null &&
                        _state.fieldToggles.isEmpty) {
                      _state.fieldToggles =
                          DefaultFieldSets.forType(_state.resourceType!);
                    }
                  });
                }
              }
            : null,
        icon: Icon(
            _state.currentStep == 1 ? Icons.auto_awesome : Icons.arrow_forward,
            size: 18),
        label: Text(_state.currentStep == 1 ? 'Generate' : 'Next'),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.md : AppSpacing.xl,
              vertical: AppSpacing.md),
        ),
      );

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (backBtn != null) backBtn else const SizedBox(width: 1),
          nextBtn,
        ],
      );
    });
  }

  bool _validateCurrentStep() {
    if (_state.currentStep == 0) {
      return _state.resourceType != null &&
          _state.subject != null &&
          _state.subject!.isNotEmpty &&
          _state.grade != null &&
          _state.grade!.isNotEmpty &&
          _state.topic.trim().isNotEmpty &&
          _state.extraInstructions.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _generate() async {
    final api = ref.read(apiServiceProvider);
    final profile = ref.read(profileProvider);

    try {
      final formatMap = <String, bool>{
        'include_header': _state.format.includeHeader,
        'include_footer': _state.format.includeFooter,
        'include_page_number': _state.format.includePageNumber,
        'table_borders': _state.format.tableBorders,
        'bw_mode': _state.format.colorMode == 'bw',
        for (final t in _state.fieldToggles) 'field_${t.id}': t.enabled,
      };

      final disabledFields = _state.fieldToggles
          .where((t) => !t.enabled)
          .map((t) => t.label)
          .toList();
      final enabledFields = _state.fieldToggles
          .where((t) => t.enabled)
          .map((t) => t.label)
          .toList();

      final extras = <String>[
        _state.extraInstructions,
        if (_state.tweakRefinement.trim().isNotEmpty)
          'REFINEMENT FROM PREVIOUS ATTEMPT: ${_state.tweakRefinement}',
        if (enabledFields.isNotEmpty)
          'Include these fields in the output: ${enabledFields.join(", ")}.',
        if (disabledFields.isNotEmpty)
          'Do NOT include these fields: ${disabledFields.join(", ")}.',
        if (_state.format.includePreparedBy && profile.name.isNotEmpty)
          'At the END of the document, on the last line, add: "${_state.format.preparedByPrefix} ${profile.name}".',
        'Body text alignment: ${_state.format.bodyAlignment.name}.',
        if (_state.format.colorMode == 'bw')
          'Use black and white formatting only — no colored highlights.',
        if (!_state.format.tableBorders)
          'If tables are used, use spacing instead of borders.',
        'Use Markdown formatting. For math, use \$..\$ for inline and \$\$..\$\$ for blocks. Use Markdown tables for tabular data.',
        if (_state.composition.mode == OutputMode.questionsOnly)
          'Output only the questions, no answers.',
        if (_state.composition.mode == OutputMode.answersOnly)
          'Output only the answer key and mark scheme.',
        if (_state.composition.separateAnswerKey)
          'Place the answer key in a clearly separated section at the end labeled "ANSWER KEY (FOR TEACHER)".',
      ].where((s) => s.trim().isNotEmpty).join('\n\n');

      final req = GenerationRequest(
        resourceType: _state.resourceType!,
        subject: _state.subject!,
        grade: _state.grade!,
        lesson: _state.lesson,
        topic: _state.topic,
        objective: _state.objectives.join(' • '),
        languageMode: _state.langMode,
        languages: _state.languages,
        extraInstructions: extras,
        formatToggles: formatMap,
        useExactTextbook: _state.useExactTextbook,
        useAdditionalContent: _state.useAdditionalContent,
        sourceText: _state.sourceText,
        uploadIds: _state.uploadIds,
        webSearchQuery: _state.webSearchQuery,
        webSearchResultCount: _state.webSearchResultCount,
      );

      final out = await api.generateResource(req);
      if (!mounted) return;

      setState(() {
        _state.generatedContent = out;
        _state.generating = false;
      });

      if (out.isNotEmpty && !out.startsWith('Error:')) {
        await _autoSave(out);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state.generatedContent = 'Error: $e';
          _state.generating = false;
        });
      }
    }
  }

  Future<void> _autoSave(String content) async {
    try {
      final api = ref.read(apiServiceProvider);
      final resource = Resource(
        id: const Uuid().v4(),
        title: '${_state.topic} — ${_state.grade}',
        type: _state.resourceType!,
        subject: _state.subject!,
        grade: _state.grade!,
        lesson: _state.lesson,
        content: content,
        createdAt: DateTime.now(),
        modelUsed: 'cloud',
        sourceUploadIds: _state.uploadIds,
      );
      final saved = await api.saveResource(resource);
      if (mounted) {
        setState(() => _state.savedResourceId = saved.id);
      }
      ref.invalidate(resourcesProvider);
    } catch (_) {
      // Silent fail
    }
  }

  Future<void> _regenerate(String refinementText) async {
    setState(() {
      _state.tweakRefinement = refinementText;
      _state.generating = true;
      _state.generatedContent = null;
      _state.savedResourceId = null;
    });
    await _generate();
    if (mounted) {
      setState(() => _state.tweakRefinement = '');
    }
  }

  void _saveAndDone() {
    ref.read(navIndexProvider.notifier).state = 2;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to Cabinet')),
    );
  }
}

// ── Stepper, ExtractStep, etc. (unchanged from current) ────────────────────

class _Steps extends StatelessWidget {
  const _Steps({required this.currentStep, required this.onTap});
  final int currentStep;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const labels = ['Extract', 'Craft', 'Generate'];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              Flexible(child: _stepDot(context, i, labels[i])),
              if (i < labels.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: i < currentStep
                          ? Pastels.studio.fgFor(Theme.of(context).brightness)
                          : Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepDot(BuildContext context, int i, String label) {
    final active = i == currentStep;
    final done = i < currentStep;
    final pastel = Pastels.studio;
    final b = Theme.of(context).brightness;
    return InkWell(
      onTap: () => onTap(i),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (active || done)
                    ? pastel.bgFor(b)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: done
                  ? Icon(Icons.check, size: 16, color: pastel.fgFor(b))
                  : Text('${i + 1}',
                      style: TextStyle(
                        color: active
                            ? pastel.fgFor(b)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      )),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtractStep extends ConsumerWidget {
  const _ExtractStep({required this.state, required this.onChanged});
  final _StudioState state;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(teacherGradesProvider);
    final subjects = ref.watch(teacherSubjectsProvider);
    final lessonChips = ref.watch(lessonSuggestionsProvider((
      grade: state.grade,
      subject: state.subject,
    )));
    final outcomeChips = ref.watch(outcomeSuggestionsProvider((
      grade: state.grade,
      subject: state.subject,
    )));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Add Source Material'),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _UploadZone(state: state, onChanged: onChanged),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Choose Resource Type'),
        _ResourceTypeGrid(
          selected: state.resourceType,
          onSelect: (t) {
            state.resourceType = t;
            state.fieldToggles = DefaultFieldSets.forType(t);
            onChanged();
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Details'),
        PastelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: _dropdown('Subject *', subjects, state.subject,
                        'Add subjects in Profile first', (v) {
                  state.subject = v;
                  onChanged();
                })),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: _dropdown('Grade *', grades, state.grade,
                        'Add grades in Profile first', (v) {
                  state.grade = v;
                  onChanged();
                })),
              ]),
              const SizedBox(height: AppSpacing.md),
              _LessonPicker(
                lessons: lessonChips,
                currentValue: state.lesson,
                onChanged: (v) {
                  state.lesson = v;
                  onChanged();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _textField('Topic *', state.topic, (v) {
                state.topic = v;
                onChanged();
              }),
              if (state.suggestedTopic != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Text('Suggested from upload:',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 6),
                  ActionChip(
                    label: Text(state.suggestedTopic!,
                        style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      state.topic = state.suggestedTopic!;
                      onChanged();
                    },
                  ),
                ]),
              ],
              const SizedBox(height: AppSpacing.md),
              _LearningObjectivePicker(
                outcomes: outcomeChips,
                selectedObjectives: state.objectives,
                topic: state.topic,
                onChanged: (list) {
                  state.objectives = list;
                  onChanged();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _LanguageSelector(state: state, onChanged: onChanged),
              const SizedBox(height: AppSpacing.md),
              _textField(
                'Extra instructions *',
                state.extraInstructions,
                (v) {
                  state.extraInstructions = v;
                  onChanged();
                },
                maxLines: 3,
                hint: 'Any specific tone, examples, or requirements?',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dropdown(String label, List<String> opts, String? value,
      String emptyHint, ValueChanged<String?> onChanged) {
    if (opts.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(emptyHint,
            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
      );
    }
    return DropdownButtonFormField<String>(
      value: opts.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o))],
      onChanged: onChanged,
    );
  }

  Widget _textField(
      String label, String initial, ValueChanged<String> onChanged,
      {int maxLines = 1, String? hint}) {
    return TextFormField(
      key: ValueKey(label),
      initialValue: initial,
      decoration: InputDecoration(labelText: label, hintText: hint),
      onChanged: onChanged,
      maxLines: maxLines,
    );
  }
}

class _LessonPicker extends StatelessWidget {
  const _LessonPicker(
      {required this.lessons,
      required this.currentValue,
      required this.onChanged});
  final List<({String code, String text})> lessons;
  final String currentValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return TextFormField(
        key: const ValueKey('lesson-text'),
        initialValue: currentValue,
        decoration: const InputDecoration(
            labelText: 'Lesson',
            hintText: 'Type lesson name (no curriculum lessons defined)'),
        onChanged: onChanged,
      );
    }
    final useDropdown = lessons.length > 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lesson', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        if (useDropdown)
          DropdownButtonFormField<String>(
            value: lessons.any((l) => l.text == currentValue)
                ? currentValue
                : null,
            decoration: const InputDecoration(
                hintText: 'Select a lesson…', isDense: true),
            items: [
              for (final l in lessons)
                DropdownMenuItem(
                    value: l.text,
                    child: Text('${l.code} • ${l.text}',
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final l in lessons)
                ChoiceChip(
                  selected: currentValue == l.text,
                  label: Text(l.text, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onChanged(l.text),
                ),
            ],
          ),
      ],
    );
  }
}

class _LearningObjectivePicker extends StatefulWidget {
  const _LearningObjectivePicker(
      {required this.outcomes,
      required this.selectedObjectives,
      required this.topic,
      required this.onChanged});
  final List<({String code, String text})> outcomes;
  final List<String> selectedObjectives;
  final String topic;
  final ValueChanged<List<String>> onChanged;
  @override
  State<_LearningObjectivePicker> createState() =>
      _LearningObjectivePickerState();
}

class _LearningObjectivePickerState extends State<_LearningObjectivePicker> {
  bool _showAll = false;
  bool _relevant(({String code, String text}) o) {
    if (widget.topic.trim().isEmpty) return false;
    final topicWords = widget.topic
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 3)
        .toSet();
    final outcomeWords = o.text.toLowerCase().split(RegExp(r'\W+')).toSet();
    return topicWords.any(outcomeWords.contains);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.outcomes.isEmpty) {
      return TextFormField(
        key: const ValueKey('lo-text'),
        initialValue: widget.selectedObjectives.join(', '),
        decoration: const InputDecoration(
            labelText: 'Learning objectives',
            hintText: 'Type comma-separated objectives.'),
        onChanged: (v) => widget.onChanged(v
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()),
      );
    }
    final relevant = widget.outcomes.where(_relevant).toList();
    final others = widget.outcomes.where((o) => !_relevant(o)).toList();
    final visible =
        _showAll ? [...relevant, ...others] : relevant.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Text('Learning objectives',
                  style: Theme.of(context).textTheme.labelLarge)),
          Text('${widget.selectedObjectives.length} selected',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('No outcomes to show.',
                      style: Theme.of(context).textTheme.bodySmall))
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in visible)
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: widget.selectedObjectives.contains(o.text),
                        title: Text('${o.code} • ${o.text}',
                            style: const TextStyle(fontSize: 12)),
                        onChanged: (v) {
                          final list =
                              List<String>.from(widget.selectedObjectives);
                          if (v == true && !list.contains(o.text))
                            list.add(o.text);
                          if (v == false) list.remove(o.text);
                          widget.onChanged(list);
                        },
                      ),
                  ],
                ),
        ),
        TextButton.icon(
          onPressed: () => setState(() => _showAll = !_showAll),
          icon:
              Icon(_showAll ? Icons.unfold_less : Icons.unfold_more, size: 14),
          label: Text(
              _showAll
                  ? 'Show only relevant'
                  : 'Show all ${widget.outcomes.length} outcomes',
              style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}

class _LanguageSelector extends ConsumerStatefulWidget {
  const _LanguageSelector({required this.state, required this.onChanged});
  final _StudioState state;
  final VoidCallback onChanged;
  @override
  ConsumerState<_LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends ConsumerState<_LanguageSelector> {
  @override
  Widget build(BuildContext context) {
    final langs = ref.watch(masterLanguagesProvider);
    final mode = widget.state.langMode;
    final selected = widget.state.languages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Output language', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<OutputLanguageMode>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(
                value: OutputLanguageMode.monolingual, label: Text('Mono')),
            ButtonSegment(
                value: OutputLanguageMode.bilingual, label: Text('Bilingual')),
            ButtonSegment(
                value: OutputLanguageMode.multilingual, label: Text('Multi')),
          ],
          selected: {mode},
          onSelectionChanged: (s) {
            setState(() => widget.state.langMode = s.first);
            widget.onChanged();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final l in langs)
              FilterChip(
                label: Text(l),
                selected: selected.contains(l),
                onSelected: (sel) {
                  setState(() {
                    final list = List<String>.from(selected);
                    if (sel) {
                      if (!list.contains(l)) list.add(l);
                    } else {
                      list.remove(l);
                      if (list.isEmpty) list.add('English');
                    }
                    widget.state.languages = list;
                  });
                  widget.onChanged();
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _UploadZone extends ConsumerStatefulWidget {
  const _UploadZone({required this.state, required this.onChanged});
  final _StudioState state;
  final VoidCallback onChanged;
  @override
  ConsumerState<_UploadZone> createState() => _UploadZoneState();
}

class _UploadZoneState extends ConsumerState<_UploadZone> {
  bool _hovering = false;
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  // ── Live audio recording state ───────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _transcribing = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _registerFile(String name, int size, {String parsedText = ''}) {
    final preview = parsedText.isNotEmpty ? parsedText : 'Uploaded: $name';
    final id = ref.read(uploadsProvider.notifier).record(
          fileName: name,
          sizeBytes: size,
          source: UploadSource.studio,
          parsedTextPreview: preview,
        );
    widget.state.uploadedFiles.add(name);
    widget.state.uploadIds.add(id);
    final base = name
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    widget.state.suggestedTopic = base.trim();
    widget.onChanged();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt'],
    );
    if (result != null) {
      setState(() {
        for (final f in result.files) {
          _registerFile(f.name, f.size);
        }
      });
    }
  }

  Future<void> _pasteText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        widget.state.sourceText += '\n${data.text}';
        widget.onChanged();
      });
    }
  }

  // ── Live audio recording ─────────────────────────────────────────────────

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
              'Microphone permission denied. Enable it in your browser settings.',
            )),
          );
        }
        return;
      }
      // Web records to memory; mobile/desktop need a file path. Use blob on web,
      // tmp path elsewhere. The record package handles this via startStream on
      // web, but the simpler `start()` API also works with a path on every
      // platform via path_provider — for web we pass an empty path and the
      // plugin returns a blob URL.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.opus, // webm/opus — Gemma & Whisper both accept
          bitRate: 64000,
          sampleRate: 16000, // 16kHz mono is optimal for ASR
          numChannels: 1,
        ),
        path: 'recording.webm',
      );
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordDuration += const Duration(seconds: 1));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path == null) return;

    // On web, `path` is a blob URL (blob:...). On native it's a file path.
    // Both are fetchable via package:http.
    List<int> bytes;
    try {
      final response = await http.get(Uri.parse(path));
      bytes = response.bodyBytes;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read recording: $e')),
        );
      }
      return;
    }

    if (bytes.isEmpty) return;

    // The Details section's "Output language" drives where we translate to.
    // Use the first chosen output language (works for mono/bilingual/multi).
    final targetLang = widget.state.languages.isNotEmpty
        ? widget.state.languages.first
        : 'English';

    setState(() => _transcribing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final parsed = await api.parseFile(
        bytes: bytes,
        filename: 'recording_${DateTime.now().millisecondsSinceEpoch}.webm',
        sourceLang: 'auto',
        targetLang: targetLang,
      );
      if (!mounted) return;
      if (parsed.text.trim().isNotEmpty) {
        setState(() {
          widget.state.sourceText = widget.state.sourceText.isEmpty
              ? parsed.text
              : '${widget.state.sourceText}\n\n${parsed.text}';
          widget.onChanged();
        });
        // Pull the auto-detected language out of the response text if the
        // backend embedded it as "_Original (LANG):_ ..." (see parser.py).
        final detectedMatch =
            RegExp(r'_Original \(([^)]+)\):_').firstMatch(parsed.text);
        final detected = detectedMatch?.group(1);
        final dur = _formatDuration(_recordDuration);
        final msg = detected != null
            ? 'Transcribed $dur of $detected → $targetLang'
            : 'Transcribed $dur of audio';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No speech detected in the recording.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transcription failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _searching = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      widget.state.webSearchQuery = q;
      widget.state.webSearchResultCount = 5;
      _searching = false;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (detail) {
        setState(() {
          for (final f in detail.files) _registerFile(f.name, 0);
          _hovering = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _hovering
              ? Pastels.studio.bgFor(b)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: _hovering
                ? Pastels.studio.fgFor(b)
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
            width: _hovering ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
        child: Column(children: [
          const Icon(Icons.cloud_upload_outlined, size: 40),
          const SizedBox(height: AppSpacing.sm),
          Text('Drop files here, or use the options below',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          // Primary actions: Browse, Paste text, Record audio
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonalIcon(
                  onPressed: _isRecording || _transcribing ? null : _pickFiles,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Browse device')),
              FilledButton.tonalIcon(
                  onPressed: _isRecording || _transcribing ? null : _pasteText,
                  icon: const Icon(Icons.content_paste, size: 16),
                  label: const Text('Paste text')),
              _transcribing
                  ? const _TranscribingChip()
                  : FilledButton.tonalIcon(
                      onPressed: _toggleRecord,
                      icon: Icon(
                        _isRecording ? Icons.stop_circle : Icons.mic,
                        size: 16,
                        color: _isRecording ? Colors.red : null,
                      ),
                      label: Text(_isRecording
                          ? 'Stop  ${_formatDuration(_recordDuration)}'
                          : 'Record audio'),
                    ),
            ],
          ),
          // Web search divider + input
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('OR SEARCH THE WEB',
                    style: Theme.of(context).textTheme.labelSmall),
              ),
              const Expanded(child: Divider()),
            ]),
          ),
          Row(children: [
            const Icon(Icons.travel_explore, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                    hintText: 'Search for context…',
                    isDense: true,
                    border: InputBorder.none),
                onSubmitted: _runSearch,
              ),
            ),
            if (_searching)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.search),
                onPressed: () => _runSearch(_searchCtrl.text),
              ),
          ]),
          // Uploaded file chips (shown only after at least one upload)
          if (widget.state.uploadedFiles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final f in widget.state.uploadedFiles)
                  Chip(
                    avatar: Icon(
                      f.toLowerCase().endsWith('.pdf')
                          ? Icons.picture_as_pdf
                          : Icons.image_outlined,
                      size: 14,
                    ),
                    label: Text(f, style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() {
                      final idx = widget.state.uploadedFiles.indexOf(f);
                      if (idx >= 0) {
                        widget.state.uploadedFiles.removeAt(idx);
                        if (idx < widget.state.uploadIds.length) {
                          widget.state.uploadIds.removeAt(idx);
                        }
                      }
                      widget.onChanged();
                    }),
                    deleteIcon: const Icon(Icons.close, size: 14),
                  ),
              ],
            ),
          ],
        ]),
      ),
    );
  }
}

class _ResourceTypeGrid extends StatelessWidget {
  const _ResourceTypeGrid({required this.selected, required this.onSelect});
  final ResourceType? selected;
  final ValueChanged<ResourceType> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth >= 720 ? 6 : 3;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1,
        children: [
          for (final t in ResourceType.values)
            PastelCard(
              pastel: Pastels.forResourceType(t.apiKey),
              selected: selected == t,
              onTap: () => onSelect(t),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_iconFor(t), size: 22),
                  const SizedBox(height: 4),
                  Text(t.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      );
    });
  }

  IconData _iconFor(ResourceType t) => switch (t) {
        ResourceType.worksheet => Icons.assignment_outlined,
        ResourceType.lessonPlan => Icons.menu_book_outlined,
        ResourceType.questionPaper => Icons.quiz_outlined,
        ResourceType.presentation => Icons.slideshow_outlined,
        ResourceType.activity => Icons.extension_outlined,
        ResourceType.notes => Icons.sticky_note_2_outlined,
      };
}

// ── Craft step (unchanged from before) ─────────────────────────────────────

class _CraftStep extends ConsumerWidget {
  const _CraftStep({required this.state, required this.onChanged});
  final _StudioState state;
  final VoidCallback onChanged;

  bool get _hasQuestions =>
      state.resourceType == ResourceType.worksheet ||
      state.resourceType == ResourceType.questionPaper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '1. Content Balance'),
        PastelCard(
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exact textbook content'),
              subtitle:
                  const Text('Use vocabulary and phrasing from the syllabus'),
              value: state.useExactTextbook,
              onChanged: (v) {
                state.useExactTextbook = v;
                onChanged();
              },
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Additional content'),
              subtitle: const Text('Allow Gemma to add helpful extras'),
              value: state.useAdditionalContent,
              onChanged: (v) {
                state.useAdditionalContent = v;
                onChanged();
              },
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: '2. Fields',
          trailing: state.resourceType == null
              ? null
              : Text('${state.resourceType!.label} template',
                  style: Theme.of(context).textTheme.bodySmall),
        ),
        PastelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Each resource type has its own field set. Toggle individual fields off to omit from this generation.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (state.fieldToggles.isEmpty)
                const Text(
                    'No fields defined. Choose a resource type in Extract.',
                    style: TextStyle(fontStyle: FontStyle.italic))
              else
                ...List.generate(state.fieldToggles.length, (i) {
                  final f = state.fieldToggles[i];
                  return Column(children: [
                    if (i > 0) const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(f.label),
                      value: f.enabled,
                      onChanged: f.locked
                          ? null
                          : (v) {
                              final updated = [...state.fieldToggles];
                              updated[i] = f.copyWith(enabled: v);
                              state.fieldToggles = updated;
                              onChanged();
                            },
                    ),
                  ]);
                }),
              if (_hasQuestions) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text('Question / Answer composition',
                      style: Theme.of(context).textTheme.labelLarge),
                ),
                SegmentedButton<OutputMode>(
                  segments: const [
                    ButtonSegment(
                        value: OutputMode.questionsOnly,
                        label: Text('Questions Only')),
                    ButtonSegment(
                        value: OutputMode.answersOnly,
                        label: Text('Answers Only')),
                    ButtonSegment(value: OutputMode.both, label: Text('Both')),
                  ],
                  selected: {state.composition.mode},
                  onSelectionChanged: (s) {
                    state.composition = state.composition.applyMode(s.first);
                    onChanged();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Export answer key as a separate document'),
                  subtitle: const Text(
                      'Generates two files: one for students, one for the teacher.',
                      style: TextStyle(fontSize: 11)),
                  value: state.composition.separateAnswerKey,
                  onChanged: (v) {
                    state.composition = state.composition
                        .copyWith(separateAnswerKey: v ?? false);
                    onChanged();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: '3. Format'),
        _FormatCard(
            state: state, profileName: profile.name, onChanged: onChanged),
      ],
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard(
      {required this.state,
      required this.profileName,
      required this.onChanged});
  final _StudioState state;
  final String profileName;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final f = state.format;
    return PastelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
                'Synced with Brand & Layout. Override per-document below.',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Include header (school letterhead)'),
            value: f.includeHeader,
            onChanged: (v) {
              state.format = f.copyWith(includeHeader: v);
              onChanged();
            },
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Include footer'),
            value: f.includeFooter,
            onChanged: (v) {
              state.format = f.copyWith(includeFooter: v);
              onChanged();
            },
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Page numbers in footer'),
            value: f.includePageNumber,
            onChanged: (v) {
              state.format = f.copyWith(includePageNumber: v);
              onChanged();
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(children: [
              Switch(
                value: f.includePreparedBy,
                onChanged: (v) {
                  state.format = f.copyWith(includePreparedBy: v);
                  onChanged();
                },
              ),
              const SizedBox(width: 8),
              const Text('Include', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              SizedBox(
                width: 130,
                child: TextFormField(
                  key: ValueKey('prepared-by-prefix-${f.preparedByPrefix}'),
                  initialValue: f.preparedByPrefix,
                  enabled: f.includePreparedBy,
                  decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder()),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) {
                    state.format = f.copyWith(preparedByPrefix: v);
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  profileName.isEmpty
                      ? '(Set teacher name in Profile)'
                      : profileName,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: profileName.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ]),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Color mode'),
            trailing: SegmentedButton<String>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: 'color', label: Text('Color')),
                ButtonSegment(value: 'bw', label: Text('B & W')),
              ],
              selected: {f.colorMode},
              onSelectionChanged: (s) {
                state.format = f.copyWith(colorMode: s.first);
                onChanged();
              },
            ),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Table borders'),
            value: f.tableBorders,
            onChanged: (v) {
              state.format = f.copyWith(tableBorders: v);
              onChanged();
            },
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Body alignment'),
            trailing: SegmentedButton<AlignmentChoice>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(
                    value: AlignmentChoice.left,
                    icon: Icon(Icons.format_align_left, size: 16)),
                ButtonSegment(
                    value: AlignmentChoice.center,
                    icon: Icon(Icons.format_align_center, size: 16)),
                ButtonSegment(
                    value: AlignmentChoice.right,
                    icon: Icon(Icons.format_align_right, size: 16)),
                ButtonSegment(
                    value: AlignmentChoice.justify,
                    icon: Icon(Icons.format_align_justify, size: 16)),
              ],
              selected: {f.bodyAlignment},
              onSelectionChanged: (s) {
                state.format = f.copyWith(bodyAlignment: s.first);
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// GENERATE step — SKY blue banner, working regenerate, no-plugin download
// ════════════════════════════════════════════════════════════════════════════

class _GenerateStep extends ConsumerStatefulWidget {
  const _GenerateStep({
    required this.state,
    required this.onChanged,
    required this.onRegenerate,
    required this.onSaveAndDone,
  });
  final _StudioState state;
  final VoidCallback onChanged;
  final Future<void> Function(String refinement) onRegenerate;
  final VoidCallback onSaveAndDone;

  @override
  ConsumerState<_GenerateStep> createState() => _GenerateStepState();
}

class _GenerateStepState extends ConsumerState<_GenerateStep> {
  final _tweakCtrl = TextEditingController();
  bool _showTweakField = false;
  bool _exporting = false;
  bool _tweakHasText = false;

  @override
  void initState() {
    super.initState();
    _tweakCtrl.addListener(() {
      final has = _tweakCtrl.text.trim().isNotEmpty;
      if (has != _tweakHasText) setState(() => _tweakHasText = has);
    });
  }

  @override
  void dispose() {
    _tweakCtrl.dispose();
    super.dispose();
  }

  Future<void> _share(String format) async {
    if (widget.state.savedResourceId == null) return;
    setState(() => _exporting = true);
    try {
      final api = ref.read(apiServiceProvider);
      final branding = ref.read(brandingProvider);

      final resources = await api.listResources();
      final resource = resources.firstWhere(
        (r) => r.id == widget.state.savedResourceId,
        orElse: () => Resource(
          id: widget.state.savedResourceId!,
          title: widget.state.topic,
          type: widget.state.resourceType!,
          subject: widget.state.subject ?? '',
          grade: widget.state.grade ?? '',
          lesson: widget.state.lesson,
          content: widget.state.generatedContent ?? '',
          createdAt: DateTime.now(),
        ),
      );

      final url = await api.exportResource(
        resource: resource,
        format: format,
        branding: branding,
      );

      final filename =
          '${resource.title.replaceAll(RegExp(r"[^\w\s-]"), "").replaceAll(RegExp(r"\s+"), "_")}.$format';

      launchDownload(url, suggestedFilename: filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading $filename…')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _onRegenerate() async {
    final refinement = _tweakCtrl.text.trim();
    if (refinement.isEmpty) return;
    final captured = refinement; // capture before clearing
    setState(() {
      _showTweakField = false;
      _tweakHasText = false;
    });
    _tweakCtrl.clear();
    await widget.onRegenerate(captured);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    if (state.generating) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('Generating with Gemma 4…'),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Cloud generation typically takes 10–30 seconds',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final md = state.generatedContent ?? '_No content yet._';
    final isError = md.startsWith('Error:');
    final saved = state.savedResourceId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (saved && !isError) ...[
          _ActionBanner(
            showTweak: _showTweakField,
            tweakCtrl: _tweakCtrl,
            exporting: _exporting,
            canRegenerate: _tweakHasText,
            onTweakToggle: () =>
                setState(() => _showTweakField = !_showTweakField),
            onRegenerate: _onRegenerate,
            onSaveAndDone: widget.onSaveAndDone,
            onShareDocx: () => _share('docx'),
            onSharePdf: () => _share('pdf'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        PastelCard(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: isError
              ? SelectableText(
                  md,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              : MarkdownView(data: md),
        ),
      ],
    );
  }
}

class _ActionBanner extends StatelessWidget {
  const _ActionBanner({
    required this.showTweak,
    required this.tweakCtrl,
    required this.exporting,
    required this.canRegenerate,
    required this.onTweakToggle,
    required this.onRegenerate,
    required this.onSaveAndDone,
    required this.onShareDocx,
    required this.onSharePdf,
  });

  final bool showTweak;
  final TextEditingController tweakCtrl;
  final bool exporting;
  final bool canRegenerate;
  final VoidCallback onTweakToggle;
  final VoidCallback onRegenerate;
  final VoidCallback onSaveAndDone;
  final VoidCallback onShareDocx;
  final VoidCallback onSharePdf;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return PastelCard(
      pastel: Pastels.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_done, size: 20, color: Pastels.sky.fgFor(b)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saved to Cabinet',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tweak & regenerate, finalize, or download.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onTweakToggle,
                icon: Icon(showTweak ? Icons.close : Icons.tune, size: 16),
                label: Text(showTweak ? 'Cancel tweak' : 'Tweak & regenerate'),
              ),
              FilledButton.tonalIcon(
                onPressed: exporting ? null : onShareDocx,
                icon: const Icon(Icons.description, size: 16),
                label: const Text('Download DOCX'),
              ),
              FilledButton.tonalIcon(
                onPressed: exporting ? null : onSharePdf,
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('Download PDF'),
              ),
              FilledButton.icon(
                onPressed: onSaveAndDone,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save & Done'),
              ),
            ],
          ),
          if (showTweak) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: tweakCtrl,
              decoration: const InputDecoration(
                labelText: 'What should change?',
                hintText:
                    'e.g. "Add more visual examples"; "Use simpler words"',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: canRegenerate ? onRegenerate : null,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Regenerate'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Small chip shown while audio is being uploaded/transcribed.
class _TranscribingChip extends StatelessWidget {
  const _TranscribingChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Transcribing…', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
