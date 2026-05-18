// lib/widgets/markdown_view.dart
//
// Markdown renderer with LaTeX math support.
// Math syntax: $x = 5$ inline, $$\frac{1}{2}$$ block.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

class MarkdownView extends StatelessWidget {
  const MarkdownView({
    super.key,
    required this.data,
    this.selectable = true,
    this.styleSheet,
  });

  final String data;
  final bool selectable;
  final MarkdownStyleSheet? styleSheet;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: selectable,
      styleSheet: styleSheet ??
          MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            tableBorder: TableBorder.all(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
            tableHead: const TextStyle(fontWeight: FontWeight.w700),
            tableCellsPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            h1: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            h2: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            h3: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
      builders: {'latex': LatexElementBuilder()},
      extensionSet: md.ExtensionSet(
        [LatexBlockSyntax(), ...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
        [LatexInlineSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
      ),
    );
  }
}

class LatexInlineSyntax extends md.InlineSyntax {
  LatexInlineSyntax() : super(r'\$([^\$\n]+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('latex', match[1]!);
    element.attributes['display'] = 'inline';
    parser.addNode(element);
    return true;
  }
}

class LatexBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\$\$\s*$');

  @override
  bool canParse(md.BlockParser parser) =>
      parser.current.content.trim() == r'$$';

  @override
  md.Node parse(md.BlockParser parser) {
    parser.advance();
    final lines = <String>[];
    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.trim() == r'$$') {
        parser.advance();
        break;
      }
      lines.add(line);
      parser.advance();
    }
    final element = md.Element.text('latex', lines.join('\n'));
    element.attributes['display'] = 'block';
    return element;
  }
}

class LatexElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tex = element.textContent;
    final isBlock = element.attributes['display'] == 'block';
    final style =
        preferredStyle ?? parentStyle ?? DefaultTextStyle.of(context).style;

    final math = Math.tex(
      tex,
      textStyle: style,
      mathStyle: isBlock ? MathStyle.display : MathStyle.text,
      onErrorFallback: (err) => Text(
        '\$$tex\$',
        style: style.copyWith(color: Theme.of(context).colorScheme.error),
      ),
    );

    if (isBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(child: math),
      );
    }
    return math;
  }
}
