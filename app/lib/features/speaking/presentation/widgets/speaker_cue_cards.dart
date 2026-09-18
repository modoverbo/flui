import 'package:flui/core/theme/flui_colors.dart';
import 'package:material_ui/material_ui.dart';

class SpeakerCueCards extends StatefulWidget {
  const new({super.key});

  @override
  State<SpeakerCueCards> createState() => _SpeakerCueCardsState();
}

class _SpeakerCueCardsState extends State<SpeakerCueCards> {
  var _revealed = 0;

  static const _cards = [
    ('ABRE', '¿Qué decisión tomaste?'),
    ('CONECTA', '¿Qué cambió después?'),
    ('CIERRA', 'Resume el aprendizaje en una frase.'),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Tarjetas guía',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (_revealed < _cards.length)
            TextButton(
              onPressed: () => setState(() => _revealed++),
              child: const Text('ABRIR'),
            ),
        ],
      ),
      SizedBox(
        height: 92,
        child: Stack(
          children: [
            for (var index = 0; index < _revealed; index++)
              AnimatedPositioned(
                key: ValueKey(index),
                duration: const Duration(milliseconds: 260),
                left: index * 14,
                right: (_revealed - index - 1) * 14,
                top: index * 5,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: [
                      FluiColors.softPink,
                      FluiColors.acidLime,
                      FluiColors.lavender,
                    ][index],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FluiColors.ink, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _cards[index].$1,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_cards[index].$2)),
                    ],
                  ),
                ),
              ),
            if (_revealed == 0)
              Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FluiColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FluiColors.lavender, width: 1.5),
                ),
                child: const Text('Ábrelas solo si pierdes el hilo'),
              ),
          ],
        ),
      ),
    ],
  );
}
