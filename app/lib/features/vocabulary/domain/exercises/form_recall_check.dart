import 'package:flui/features/vocabulary/domain/exercises/spoken_answer.dart';
import 'package:flui/features/vocabulary/domain/exercises/text_matching.dart';
import 'package:flui/features/vocabulary/domain/exercises/word_forms.dart';
import 'package:meta/meta.dart';

enum FormRecallStatus { pending, accepted, revealed }

/// Typed or spoken recall of a word from its meaning and a masked sentence.
///
/// Typed answers ([submit]) are compared lowercase, trimmed and without
/// diacritics against the expected form, the lemma and its known forms. One
/// typo (edit distance 1) is tolerated for forms of 6 letters or more.
/// Spoken answers ([submitHeard]) additionally tolerate the [spanishSoundKey]
/// homophones of [SpokenAnswer.matchesForm] (design D35). Up to two hints
/// (the second is the first letter), then the word is revealed.
@immutable
final class FormRecallCheck {
  const new({
    required this.expectedForm,
    required this.forms,
    this.hintsUsed = 0,
    this.status = FormRecallStatus.pending,
    this.lastAnswerRejected = false,
    this.lastHeard,
  });

  static const maxHints = 2;
  static const typoToleranceMinLength = 6;

  /// The form that fits the masked sentence (for example "zanjó").
  final String expectedForm;
  final WordForms forms;
  final int hintsUsed;
  final FormRecallStatus status;
  final bool lastAnswerRejected;

  /// The last transcript heard through [submitHeard], for the UI's
  /// "Escuché: «...»" display. `null` until a spoken answer is submitted.
  final String? lastHeard;

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

  /// The spoken counterpart of [submit]: [transcript] is a speech-to-text
  /// result rather than typed input.
  ///
  /// An empty transcript (no words heard) leaves the state entirely
  /// unchanged — no hint is consumed, mirroring the caller never having
  /// spoken. Otherwise this has the same accept/hint/reveal shape as
  /// [submit], but matches through [SpokenAnswer.matchesForm] (window scan +
  /// typo tolerance + Spanish sound key) instead of [accepts]. Stores
  /// [transcript] in [lastHeard] whenever it is actually evaluated.
  FormRecallCheck submitHeard(String transcript) {
    if (isResolved || wordTokens(transcript).isEmpty) return this;
    final heard = transcript.trim();
    if (SpokenAnswer.matchesForm(
      transcript,
      expectedForm: expectedForm,
      forms: forms,
    )) {
      return _copy(
        status: FormRecallStatus.accepted,
        rejected: false,
        heard: heard,
      );
    }
    return _nextHint(rejected: true, heard: heard);
  }

  FormRecallCheck _nextHint({required bool rejected, String? heard}) {
    if (hintsUsed >= maxHints) {
      return _copy(
        status: FormRecallStatus.revealed,
        rejected: rejected,
        heard: heard,
      );
    }
    return _copy(hints: hintsUsed + 1, rejected: rejected, heard: heard);
  }

  FormRecallCheck _copy({
    required bool rejected,
    int? hints,
    FormRecallStatus? status,
    String? heard,
  }) => FormRecallCheck(
    expectedForm: expectedForm,
    forms: forms,
    hintsUsed: hints ?? hintsUsed,
    status: status ?? this.status,
    lastAnswerRejected: rejected,
    lastHeard: heard ?? lastHeard,
  );
}
