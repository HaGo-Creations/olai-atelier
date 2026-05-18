// lib/screens/settings_sections/branding_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class BrandingSection extends ConsumerStatefulWidget {
  const BrandingSection({super.key});
  @override
  ConsumerState<BrandingSection> createState() => _BrandingSectionState();
}

class _BrandingSectionState extends ConsumerState<BrandingSection> {
  DocFormat _selectedFormat = DocFormat.docx;

  @override
  Widget build(BuildContext context) {
    final b = ref.watch(brandingProvider);
    final n = ref.read(brandingProvider.notifier);
    final locked = b.locked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brand & Layout'),
        actions: [
          LockToggle(
            locked: locked,
            tooltip: locked ? 'Unlock' : 'Lock',
            onChanged: (_) => n.toggleLock(),
          ),
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ModelBadgeChip()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (locked) ...[
            PastelCard(
              pastel: Pastels.butter,
              child: Row(
                children: const [
                  Icon(Icons.lock, size: 18),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: Text(
                          'Brand & Layout is locked. Unlock from the top bar to edit.')),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const SectionHeader(title: 'Identity'),
          PastelCard(
            child: Column(
              children: [
                _logoRow(context, b, n, locked),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  initialValue: b.schoolName,
                  enabled: !locked,
                  decoration: const InputDecoration(labelText: 'School name'),
                  onChanged: n.setSchoolName,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  initialValue: b.address,
                  enabled: !locked,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2,
                  onChanged: n.setAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                        child: TextFormField(
                      initialValue: b.phone,
                      enabled: !locked,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      onChanged: n.setPhone,
                    )),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: TextFormField(
                      initialValue: b.email,
                      enabled: !locked,
                      decoration: const InputDecoration(labelText: 'Email'),
                      onChanged: n.setEmail,
                    )),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  initialValue: b.footerText,
                  enabled: !locked,
                  decoration: const InputDecoration(
                    labelText: 'Footer text',
                    hintText: 'Appears at the bottom of every page',
                  ),
                  maxLines: 2,
                  onChanged: n.setFooter,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Page Layout per Format'),
          PastelCard(
            child: Column(
              children: [
                SegmentedButton<DocFormat>(
                  segments: const [
                    ButtonSegment(value: DocFormat.docx, label: Text('Word')),
                    ButtonSegment(value: DocFormat.pdf, label: Text('PDF')),
                    ButtonSegment(value: DocFormat.pptx, label: Text('PPT')),
                  ],
                  selected: {_selectedFormat},
                  onSelectionChanged: (s) =>
                      setState(() => _selectedFormat = s.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(builder: (context, c) {
                  final wide = c.maxWidth >= 640;
                  final layout = b.layoutFor(_selectedFormat);
                  final form = _PageLayoutForm(
                    layout: layout,
                    locked: locked,
                    format: _selectedFormat,
                    onChanged: (l) => n.setLayout(_selectedFormat, l),
                  );
                  final preview = _PagePreview(
                      branding: b, layout: layout, format: _selectedFormat);
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: form),
                        const SizedBox(width: AppSpacing.lg),
                        SizedBox(width: 260, child: preview),
                      ],
                    );
                  }
                  return Column(children: [
                    form,
                    const SizedBox(height: AppSpacing.lg),
                    preview
                  ]);
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PastelCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Apply on export (global default)'),
              subtitle: const Text(
                  'When ON, header/footer apply to every export. You can override per document in Studio Output.'),
              value: b.applyOnExport,
              onChanged: locked ? null : n.setApplyOnExport,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoRow(
      BuildContext context, Branding b, BrandingNotifier n, bool locked) {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          clipBehavior: Clip.antiAlias,
          child: b.logoPath != null
              ? Icon(Icons.check_circle,
                  size: 32,
                  color: Pastels.butter.fgFor(Theme.of(context).brightness))
              : Icon(Icons.image_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4)),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  b.logoPath != null
                      ? b.logoPath!.split(RegExp(r'[\\/]+')).last
                      : 'No logo selected',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: locked
                        ? null
                        : () async {
                            final x = await ImagePicker()
                                .pickImage(source: ImageSource.gallery);
                            if (x != null) n.setLogo(x.path);
                          },
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text('Choose'),
                  ),
                  const SizedBox(width: 8),
                  if (b.logoPath != null)
                    TextButton.icon(
                      onPressed: locked ? null : () => n.setLogo(null),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Layout form (now with PDF dual-mode, PPT aspect, typography pair) ──────

class _PageLayoutForm extends StatelessWidget {
  const _PageLayoutForm({
    required this.layout,
    required this.locked,
    required this.format,
    required this.onChanged,
  });
  final PageLayout layout;
  final bool locked;
  final DocFormat format;
  final ValueChanged<PageLayout> onChanged;

  bool get _isSlides =>
      format == DocFormat.pptx ||
      (format == DocFormat.pdf && layout.pdfMode == PdfMode.slides);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (format == DocFormat.pdf) ...[
          Text('PDF mode', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<PdfMode>(
            segments: const [
              ButtonSegment(
                  value: PdfMode.document,
                  label: Text('Document (Word-style)')),
              ButtonSegment(
                  value: PdfMode.slides, label: Text('Slides (PPT-style)')),
            ],
            selected: {layout.pdfMode},
            onSelectionChanged: locked
                ? null
                : (s) => onChanged(layout.copyWith(pdfMode: s.first)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_isSlides) ...[
          Text('Slide aspect', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<SlideAspect>(
            segments: const [
              ButtonSegment(value: SlideAspect.ar16_9, label: Text('16:9')),
              ButtonSegment(value: SlideAspect.ar4_3, label: Text('4:3')),
              ButtonSegment(value: SlideAspect.custom, label: Text('Custom')),
            ],
            selected: {layout.slideAspect},
            onSelectionChanged: locked
                ? null
                : (s) => onChanged(layout.copyWith(slideAspect: s.first)),
          ),
        ] else ...[
          Text('Page Size', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<PageSize>(
            segments: const [
              ButtonSegment(value: PageSize.a4, label: Text('A4')),
              ButtonSegment(value: PageSize.letter, label: Text('US Letter')),
            ],
            selected: {layout.pageSize},
            onSelectionChanged: locked
                ? null
                : (s) => onChanged(layout.copyWith(pageSize: s.first)),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Margins (mm)', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: _marginField('Top', layout.marginTop, locked,
                  (v) => onChanged(layout.copyWith(marginTop: v)))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: _marginField('Bottom', layout.marginBottom, locked,
                  (v) => onChanged(layout.copyWith(marginBottom: v)))),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(
              child: _marginField('Left', layout.marginLeft, locked,
                  (v) => onChanged(layout.copyWith(marginLeft: v)))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: _marginField('Right', layout.marginRight, locked,
                  (v) => onChanged(layout.copyWith(marginRight: v)))),
        ]),
        const SizedBox(height: AppSpacing.lg),
        Text('Typography — Headings',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: _numField(
            'Size (pt)',
            layout.typography.headingSize,
            locked,
            (v) => onChanged(layout.copyWith(
                typography: layout.typography.copyWith(headingSize: v))),
          )),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: _numField(
            'Weight',
            layout.typography.headingWeight.toDouble(),
            locked,
            (v) => onChanged(layout.copyWith(
                typography:
                    layout.typography.copyWith(headingWeight: v.toInt()))),
          )),
        ]),
        const SizedBox(height: AppSpacing.md),
        Text('Typography — Body',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: _numField(
            'Size (pt)',
            layout.typography.bodySize,
            locked,
            (v) => onChanged(layout.copyWith(
                typography: layout.typography.copyWith(bodySize: v))),
          )),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: _numField(
            'Weight',
            layout.typography.bodyWeight.toDouble(),
            locked,
            (v) => onChanged(layout.copyWith(
                typography: layout.typography.copyWith(bodyWeight: v.toInt()))),
          )),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: _numField(
            'Line spacing',
            layout.typography.lineSpacing,
            locked,
            (v) => onChanged(layout.copyWith(
                typography: layout.typography.copyWith(lineSpacing: v))),
          )),
        ]),
        const SizedBox(height: AppSpacing.lg),
        Text('Logo position', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<LogoPosition>(
          segments: const [
            ButtonSegment(
                value: LogoPosition.left,
                icon: Icon(Icons.format_align_left, size: 14)),
            ButtonSegment(
                value: LogoPosition.center,
                icon: Icon(Icons.format_align_center, size: 14)),
            ButtonSegment(
                value: LogoPosition.right,
                icon: Icon(Icons.format_align_right, size: 14)),
          ],
          selected: {layout.logoPosition},
          onSelectionChanged: locked
              ? null
              : (s) => onChanged(layout.copyWith(logoPosition: s.first)),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Footer alignment', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<FooterAlignment>(
          segments: const [
            ButtonSegment(
                value: FooterAlignment.left,
                icon: Icon(Icons.format_align_left, size: 14)),
            ButtonSegment(
                value: FooterAlignment.center,
                icon: Icon(Icons.format_align_center, size: 14)),
            ButtonSegment(
                value: FooterAlignment.right,
                icon: Icon(Icons.format_align_right, size: 14)),
          ],
          selected: {layout.footerAlignment},
          onSelectionChanged: locked
              ? null
              : (s) => onChanged(layout.copyWith(footerAlignment: s.first)),
        ),
      ],
    );
  }

  Widget _marginField(
      String label, double value, bool locked, ValueChanged<double> onChanged) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: value.toStringAsFixed(0),
      enabled: !locked,
      decoration: InputDecoration(labelText: label, isDense: true),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final n = double.tryParse(v);
        if (n != null) onChanged(n);
      },
    );
  }

  Widget _numField(
      String label, double value, bool locked, ValueChanged<double> onChanged) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: value.toStringAsFixed(label == 'Line spacing' ? 2 : 0),
      enabled: !locked,
      decoration: InputDecoration(labelText: label, isDense: true),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final n = double.tryParse(v);
        if (n != null) onChanged(n);
      },
    );
  }
}

// ── Page preview (now renders logo/name/address) ───────────────────────────

class _PagePreview extends StatelessWidget {
  const _PagePreview(
      {required this.branding, required this.layout, required this.format});
  final Branding branding;
  final PageLayout layout;
  final DocFormat format;

  double get _aspect {
    final isSlides = format == DocFormat.pptx ||
        (format == DocFormat.pdf && layout.pdfMode == PdfMode.slides);
    if (isSlides) return layout.slideAspect.ratio;
    return layout.pageSize == PageSize.a4 ? 210 / 297 : 215.9 / 279.4;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: _aspect,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: AppShadows.card(Theme.of(context).brightness),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: _PageContent(branding: branding, layout: layout),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _summary(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _summary() {
    final isSlides = format == DocFormat.pptx ||
        (format == DocFormat.pdf && layout.pdfMode == PdfMode.slides);
    if (isSlides) {
      return 'Slides ${layout.slideAspect.label} • margins ${layout.marginTop.toStringAsFixed(0)}/${layout.marginRight.toStringAsFixed(0)}/${layout.marginBottom.toStringAsFixed(0)}/${layout.marginLeft.toStringAsFixed(0)} mm';
    }
    return '${layout.pageSize.label} • margins ${layout.marginTop.toStringAsFixed(0)}/${layout.marginRight.toStringAsFixed(0)}/${layout.marginBottom.toStringAsFixed(0)}/${layout.marginLeft.toStringAsFixed(0)} mm';
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.branding, required this.layout});
  final Branding branding;
  final PageLayout layout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final unitX = c.maxWidth / 210.0;
      final mL = layout.marginLeft * unitX;
      final mR = layout.marginRight * unitX;
      final mT = layout.marginTop * unitX * 0.5;
      final mB = layout.marginBottom * unitX * 0.5;

      // Header alignment helpers
      Alignment logoAlign() => switch (layout.logoPosition) {
            LogoPosition.left => Alignment.centerLeft,
            LogoPosition.center => Alignment.center,
            LogoPosition.right => Alignment.centerRight,
          };
      Alignment footerAlign() => switch (layout.footerAlignment) {
            FooterAlignment.left => Alignment.centerLeft,
            FooterAlignment.center => Alignment.center,
            FooterAlignment.right => Alignment.centerRight,
          };

      return Padding(
        padding: EdgeInsets.fromLTRB(mL, mT, mR, mB),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Align(
                alignment: logoAlign(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4E3470),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: branding.logoPath != null
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 12)
                          : const Icon(Icons.school,
                              color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branding.schoolName.isEmpty
                                ? 'School Name'
                                : branding.schoolName,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: branding.schoolName.isEmpty
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (branding.address.isNotEmpty)
                            Text(branding.address,
                                style: const TextStyle(
                                    fontSize: 6, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Body — sample heading + lines using configured typography
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Heading sample
                    Text(
                      'Sample Heading',
                      style: TextStyle(
                        fontSize:
                            layout.typography.headingSize.clamp(8, 28) * 0.55,
                        fontWeight: FontWeight.values[
                            (layout.typography.headingWeight ~/ 100)
                                .clamp(0, 8)],
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Body lines
                    Expanded(
                      child: ListView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          for (var i = 0; i < 10; i++)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: layout.typography.lineSpacing
                                          .clamp(1, 2) *
                                      1.5),
                              child: Container(
                                height:
                                    layout.typography.bodySize.clamp(6, 18) *
                                        0.4,
                                width: (i % 3 == 0)
                                    ? c.maxWidth * 0.6
                                    : c.maxWidth * (0.7 + (i % 3) * 0.07),
                                color: Colors.grey.shade300,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Align(
                alignment: footerAlign(),
                child: Text(
                  branding.footerText.isNotEmpty
                      ? branding.footerText
                      : (branding.phone.isNotEmpty || branding.email.isNotEmpty
                          ? '${branding.phone}  ${branding.email}'.trim()
                          : 'Footer text'),
                  style: TextStyle(
                    fontSize: 7,
                    color: branding.footerText.isEmpty &&
                            branding.phone.isEmpty &&
                            branding.email.isEmpty
                        ? Colors.grey
                        : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
