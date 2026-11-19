import 'package:flutter/material.dart';

import 'l10n.dart';

/// A [Text] that translates its English string through [L10n] and rebuilds
/// when the language changes. Phrases without a translation are shown as is
/// (note names, numbers, instrument names).
class Tx extends StatelessWidget {
  const Tx(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: L10n.i,
    builder: (context, _) => Text(
      L10n.i.t(text),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    ),
  );
}
