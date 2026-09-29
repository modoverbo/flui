import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/widgets/training_loop_view.dart';
import 'package:flui/features/vocabulary/presentation/controllers/word_speak_target.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// PALABRAS' own spoken-use loop (`AppRoutes.wordSpeak`, U17, design
/// §19.4): a branch child of `/words/:wordId`, reached from
/// `TodayWordTarget`/`WordSpeakTarget`'s own first captured attempt. Hands
/// off entirely to the shared `TrainingLoopView` (`context = word`,
/// `LoopScript.wordUse()`), the same pattern `TodayTrainPage`/
/// `TrainingLabModePage` use.
///
/// Builds the exact same [LoopRequest] shape [WordSpeakTarget.requestFor]
/// does (not a call to it directly — `WidgetRef` and the plain `Ref` a
/// `MicTarget` holds are different Riverpod interfaces), keyed on the
/// SAME app-lifetime `wordSpeakSessionIdProvider(wordId)`, so this page
/// resolves to the exact same `TrainingLoopController` family instance the
/// target already advanced, never a second, unrelated session.
class WordSpeakPage extends ConsumerWidget {
  const new({required this.wordId, super.key});

  final String wordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: TrainingLoopView(
        request: LoopRequest(
          context: TrainingContext.word,
          sessionId: ref.watch(wordSpeakSessionIdProvider(wordId)),
          script: const LoopScript.wordUse(),
          targetWordIds: [wordId],
        ),
      ),
    ),
  );
}
