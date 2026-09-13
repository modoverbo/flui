import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/shared/widgets/state_chip.dart';

extension WordStateChipKind on WordState {
  WordStateKind get chipKind => switch (this) {
    WordState.nueva => WordStateKind.nueva,
    WordState.practica => WordStateKind.practica,
    WordState.tuya => WordStateKind.tuya,
  };
}
