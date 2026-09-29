import 'package:flui/features/vocabulary/domain/exercises/text_matching.dart';
import 'package:flui/features/vocabulary/domain/exercises/word_forms.dart';

/// Maps an already-normalized (lowercase, diacritics-stripped) Spanish
/// string to a coarse phonetic key, so that spellings that actually sound
/// the same ("baca"/"vaca", "caye"/"calle", "ola"/"hola", "sapato"/"zapato")
/// compare equal.
///
/// Only the mergers spoken Spanish genuinely has are modeled: betacismo
/// (b/v), yeísmo (ll/y), a silent h, and seseo (c before e/i, z -> s) plus
/// the matching hard sounds (qu/k/c before a/o/u -> k; g before e/i, j -> j).
/// This is a lookup key for [SpokenAnswer.matchesForm], not a phonetic
/// transcription — it never softens vowels or digraphs beyond these rules.
String spanishSoundKey(String normalized) {
  final buffer = StringBuffer();
  final chars = normalized.split('');
  for (var i = 0; i < chars.length; i++) {
    final char = chars[i];
    final next = i + 1 < chars.length ? chars[i + 1] : null;
    switch (char) {
      case 'h':
        continue; // silent h dropped
      case 'v':
        buffer.write('b'); // b/v merge
      case 'l':
        if (next == 'l') {
          buffer.write('y'); // ll -> y (yeísmo)
          i++;
        } else {
          buffer.write('l');
        }
      case 'q':
        if (next == 'u') {
          buffer.write('k'); // qu -> k
          i++;
        } else {
          buffer.write('q');
        }
      case 'c':
        buffer.write(next == 'e' || next == 'i' ? 's' : 'k'); // seseo / hard c
      case 'z':
        buffer.write('s'); // seseo
      case 'g':
        buffer.write(next == 'e' || next == 'i' ? 'j' : 'g'); // soft g -> j
      default:
        buffer.write(char);
    }
  }
  return buffer.toString();
}

/// Client-side matcher for a word answered aloud (design D35).
///
/// Expected answers are never sent to the server: this runs entirely on the
/// already-transcribed text, reusing `FormRecallCheck`'s existing
/// normalization and typo tolerance instead of introducing new rules.
abstract final class SpokenAnswer {
  static const _typoToleranceMinLength = 6;

  /// Whether [transcript] contains, anywhere, a spoken form of
  /// [expectedForm] or of any of [forms]'s known forms.
  ///
  /// A candidate matches a transcript window when the window is exactly
  /// equal to it, when it is a single-letter-edit typo of it (forms of 6+
  /// letters only — `FormRecallCheck.accepts`'s existing rule), or when
  /// both share the same [spanishSoundKey]. Comparison always happens on
  /// whole token windows — never on a substring inside a single token — so
  /// a word can never match by merely appearing inside a longer one.
  static bool matchesForm(
    String transcript, {
    required String expectedForm,
    required WordForms forms,
  }) {
    final tokens = wordTokens(transcript);
    final candidates = {normalizeText(expectedForm), ...forms.knownForms}
      ..remove('');
    for (final candidate in candidates) {
      final candidateTokens = candidate.split(' ');
      final windowSize = candidateTokens.length;
      if (windowSize > tokens.length) continue;
      for (var start = 0; start <= tokens.length - windowSize; start++) {
        final window = tokens.sublist(start, start + windowSize).join(' ');
        if (window == candidate) return true;
        if (candidate.length >= _typoToleranceMinLength &&
            levenshtein(window, candidate) <= 1) {
          return true;
        }
        if (spanishSoundKey(window) == spanishSoundKey(candidate)) {
          return true;
        }
      }
    }
    return false;
  }
}
