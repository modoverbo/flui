import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:flui/shared/widgets/section_header.dart';
import 'package:flui/shared/widgets/state_chip.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// End of a session: what was added, what became yours, and one way back.
class SessionSummaryView extends StatelessWidget {
  const new({
    required this.newWordCount,
    required this.words,
    required this.ownedLemmas,
    required this.seeding,
    required this.onDone,
    super.key,
  });

  final int newWordCount;
  final List<({String lemma, WordStateKind state})> words;
  final List<String> ownedLemmas;
  final bool seeding;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FluiSpacing.lg),
        const Align(child: FluiSymbol(size: 72)),
        const SizedBox(height: FluiSpacing.lg),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            l10n.sessionEndNewWords(newWordCount),
            textAlign: TextAlign.center,
            style: FluiTypography.h1.copyWith(color: FluiColors.charcoal),
          ),
        ),
        for (final lemma in ownedLemmas) ...[
          const SizedBox(height: FluiSpacing.lg),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: FluiColors.greenDeep,
              borderRadius: FluiRadii.xlAll,
            ),
            child: Padding(
              padding: const EdgeInsets.all(FluiSpacing.lg),
              child: Column(
                children: [
                  const FluiSymbol(tone: FluiSymbolTone.yellow),
                  const SizedBox(height: FluiSpacing.sm),
                  Text(
                    l10n.sessionEndOwned,
                    style: FluiTypography.h1.copyWith(color: FluiColors.cream),
                  ),
                  const SizedBox(height: FluiSpacing.xxs),
                  Text(
                    l10n.sessionEndOwnedBody(lemma),
                    textAlign: TextAlign.center,
                    style: FluiTypography.body.copyWith(
                      color: FluiColors.cream,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (seeding) ...[
          const SizedBox(height: FluiSpacing.lg),
          FluiNotice(
            tone: FluiNoticeTone.info,
            icon: LucideIcons.sprout,
            message: l10n.sessionSeeding,
          ),
        ],
        if (words.isNotEmpty) ...[
          const SizedBox(height: FluiSpacing.xl),
          SectionHeader(title: l10n.sessionEndWordsTitle),
          for (final word in words) ...[
            FluiCard(
              padding: const EdgeInsets.symmetric(
                horizontal: FluiSpacing.md,
                vertical: FluiSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      word.lemma,
                      style: FluiTypography.bodyEmphasis.copyWith(
                        color: FluiColors.charcoal,
                      ),
                    ),
                  ),
                  StateChip(state: word.state),
                ],
              ),
            ),
            const SizedBox(height: FluiSpacing.xs),
          ],
        ],
        const SizedBox(height: FluiSpacing.xl),
        FluiButton.primary(label: l10n.sessionEndDone, onPressed: onDone),
      ],
    );
  }
}
