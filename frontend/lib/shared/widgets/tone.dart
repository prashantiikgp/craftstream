/// Colour roles a component can take. Each maps to tokens: text (ink), background (wash) and border.
library;

import 'package:flutter/widgets.dart';

import '../../domain/ui/theme_engine.dart';

enum Tone { brand, secondary, success, danger, info, warning, neutral }

class ToneColors {
  final Color ink, wash, border, fill;
  const ToneColors({required this.ink, required this.wash, required this.border, required this.fill});
}

ToneColors toneColors(DesignTokens t, Tone tone) => switch (tone) {
      Tone.brand => ToneColors(ink: t.brandInk, wash: t.brandLl, border: t.brandLine, fill: t.brand),
      Tone.secondary => ToneColors(ink: t.secondaryInk, wash: t.secondaryL, border: t.secondaryL, fill: t.secondary),
      Tone.success => _status(t.success),
      Tone.danger => _status(t.danger),
      Tone.info => _status(t.info),
      Tone.warning => _status(t.warning),
      Tone.neutral => ToneColors(ink: t.sub, wash: t.surfaceSoft, border: t.hair, fill: t.sub),
    };

ToneColors _status(StatusColors s) => ToneColors(ink: s.ink, wash: s.wash, border: s.border, fill: s.fill);
