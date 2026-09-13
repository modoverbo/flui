import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/exercises/domain/word_forms.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/reading/presentation/widgets/reading_card.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// Mira: one reading at a time with "1 de 3" and previous/next.
class ReadingsCarousel extends StatefulWidget {
  const new({required this.readings, required this.forms, super.key});

  final List<Reading> readings;
  final WordForms forms;

  @override
  State<ReadingsCarousel> createState() => _ReadingsCarouselState();
}

class _ReadingsCarouselState extends State<ReadingsCarousel> {
  var _index = 0;

  @override
  void didUpdateWidget(ReadingsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.readings.length) _index = 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final readings = widget.readings;
    if (readings.isEmpty) return const SizedBox.shrink();
    final total = readings.length;
    final position = l10n.readingPosition(_index + 1, total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReadingCard(reading: readings[_index], forms: widget.forms),
        const SizedBox(height: FluiSpacing.md),
        Row(
          children: [
            IconButton.outlined(
              tooltip: l10n.commonPrevious,
              onPressed: _index == 0 ? null : () => setState(() => _index--),
              icon: const Icon(LucideIcons.arrow_left, size: 18),
            ),
            const SizedBox(width: FluiSpacing.sm),
            FluiLabel(position),
            const SizedBox(width: FluiSpacing.sm),
            Expanded(
              child: FluiProgressBar(
                value: (_index + 1) / total,
                semanticLabel: position,
                height: 4,
              ),
            ),
            const SizedBox(width: FluiSpacing.sm),
            IconButton.outlined(
              tooltip: l10n.commonNext,
              onPressed: _index >= total - 1
                  ? null
                  : () => setState(() => _index++),
              icon: const Icon(LucideIcons.arrow_right, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}
