import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/shared/widgets/placeholder_page.dart';
import 'package:material_ui/material_ui.dart';

/// "Practica". Phase B: exercise flow, hint policy, grading, attempts.
class PracticePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PlaceholderPage(
      title: l10n.navPractice,
      message: l10n.practiceComingSoonBody,
    );
  }
}
