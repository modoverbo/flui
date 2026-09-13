import 'package:flui/features/exercises/domain/text_matching.dart';
import 'package:flui/features/exercises/domain/word_forms.dart';
import 'package:meta/meta.dart';

enum FormRecallStatus { pending, accepted, revealed }

/// Typed recall of a word from its meaning and a masked sentence.
///
/// Answers are compared lowercase, trimmed and without diacritics against the
/// expected form, the lemma and its known forms. One typo (edit distance 1)
/// is tolerated for forms of 6 letters or more. Up to two hints (the second
/// is the first letter), then the word is revealed.
@immutable
final class FormRecallCheck {
  const new({
    required this.expectedForm,
    required this.forms,
    this.hintsUsed = 0,
    this.status = FormRecallStatus.pending,
    this.lastAnswerRejected = false,
  });

  static const maxHints = 2;
  static const typoToleranceMinLength = 6;

  /// The form that fits the masked sentence (for example "zanjó").
  final String expectedForm;
  final WordForms forms;
  final int hintsUsed;
  final FormRecallStatus status;
  final bool lastAnswerRejected;

  bool get isResolved => status != FormRecallStatus.pending;

  /// `form_recall_done`: accepted without a reveal (hints are fine).
  bool get countsAsDone => status == FormRecallStatus.accepted;

  String get firstLetter => expectedForm.isEmpty ? '' : expectedForm[0];

  static bool accepts(
    String input, {
    required String expectedForm,
    required WordForms forms,
  }) {
    final answer = normalizeText(input);
    if (answer.isEmpty) return false;
    final candidates = {normalizeText(expectedForm), ...forms.knownForms};
    for (final candidate in candidates) {
      if (answer == candidate) return true;
      if (candidate.length >= typoToleranceMinLength &&
          levenshtein(answer, candidate) <= 1) {
        return true;
      }
    }
    return false;
  }

  FormRecallCheck submit(String input) {
    if (isResolved || normalizeText(input).isEmpty) return this;
    if (accepts(input, expectedForm: expectedForm, forms: forms)) {
      return _copy(status: FormRecallStatus.accepted, rejected: false);
    }
    return _nextHint(rejected: true);
  }

  /// "Pista": the next hint, or the reveal after [maxHints].
  FormRecallCheck takeHint() => isResolved ? this : _nextHint(rejected: false);

  FormRecallCheck _nextHint({required bool rejected}) {
    if (hintsUsed >= maxHints) {
      return _copy(status: FormRecallStatus.revealed, rejected: rejected);
    }
    return _copy(hints: hintsUsed + 1, rejected: rejected);
  }

  FormRecallCheck _copy({
    required bool rejected,
    int? hints,
    FormRecallStatus? status,
  }) => FormRecallCheck(
    expectedForm: expectedForm,
    forms: forms,
    hintsUsed: hints ?? hintsUsed,
    status: status ?? this.status,
    lastAnswerRejected: rejected,
  );
}
