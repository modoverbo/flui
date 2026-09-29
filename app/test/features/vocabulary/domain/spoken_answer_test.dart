import 'package:flui/features/vocabulary/domain/exercises/spoken_answer.dart';
import 'package:flui/features/vocabulary/domain/exercises/word_forms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const vaca = WordForms(lemma: 'vaca', isVerb: false);
  const calle = WordForms(lemma: 'calle', isVerb: false);
  const hola = WordForms(lemma: 'hola', isVerb: false);
  const zapato = WordForms(lemma: 'zapato', isVerb: false);
  const camion = WordForms(lemma: 'camión', isVerb: false);
  const susto = WordForms(lemma: 'susto', isVerb: false);
  const zanjar = WordForms(lemma: 'zanjar', isVerb: true);
  const perspicaz = WordForms(
    lemma: 'perspicaz',
    isVerb: false,
    extraForms: ['perspicacia'],
  );
  const esDecir = WordForms(lemma: 'es decir', isVerb: false);
  const casa = WordForms(lemma: 'casa', isVerb: false);
  const cielo = WordForms(lemma: 'cielo', isVerb: false);
  const gusto = WordForms(lemma: 'gusto', isVerb: false);

  group('spanishSoundKey', () {
    final cases = <(String label, String a, String b, bool equal)>[
      ('b/v merge', 'vaca', 'baca', true),
      ('ll/y merge', 'calle', 'caye', true),
      ('silent h dropped', 'hola', 'ola', true),
      ('c/z/s seseo', 'zapato', 'sapato', true),
      ('different consonant, not merged', 'gusto', 'susto', false),
      ('different vowel after merge, not equal', 'cielo', 'cerro', false),
    ];
    for (final (label, a, b, equal) in cases) {
      test('$label: spanishSoundKey($a) == spanishSoundKey($b) is $equal', () {
        expect(spanishSoundKey(a) == spanishSoundKey(b), equal);
      });
    }
  });

  group('SpokenAnswer.matchesForm — accepted', () {
    final cases =
        <
          (
            String label,
            String transcript,
            String expected,
            WordForms forms,
            bool ok,
          )
        >[
          ('accents', 'Vamos en el camion ayer', 'camión', camion, true),
          ('case', 'Fuimos en CAMIÓN', 'camión', camion, true),
          ('punctuation', '¡Qué susto, casi me caigo!', 'susto', susto, true),
          ('b/v', 'vi una baca cerca', 'vaca', vaca, true),
          ('ll/y', 'vivo en la caye principal', 'calle', calle, true),
          ('silent h', 'ola, ¿qué tal?', 'hola', hola, true),
          ('c/z/s', 'compré un sapato ayer', 'zapato', zapato, true),
          (
            'multi-word lemma',
            'bueno, es decir que sí',
            'es decir',
            esDecir,
            true,
          ),
          (
            'embedded inside a longer phrase',
            'tenemos que zanjar esto pronto',
            'zanjar',
            zanjar,
            true,
          ),
          (
            '1-letter-edit typo on 6+ letters',
            'que persona tan perspikaz',
            'perspicaz',
            perspicaz,
            true,
          ),
        ];
    for (final (label, transcript, expected, forms, ok) in cases) {
      test('$label -> $ok', () {
        expect(
          SpokenAnswer.matchesForm(
            transcript,
            expectedForm: expected,
            forms: forms,
          ),
          ok,
        );
      });
    }
  });

  group(
    'SpokenAnswer.matchesForm — rejected (near-misses must not over-accept)',
    () {
      test('empty transcript: no window to scan', () {
        expect(
          SpokenAnswer.matchesForm(
            '',
            expectedForm: 'perspicaz',
            forms: perspicaz,
          ),
          isFalse,
        );
      });

      test('a different word shares a sound-key rule but the keys differ', () {
        expect(
          SpokenAnswer.matchesForm(
            'Miramos el cerro',
            expectedForm: 'cielo',
            forms: cielo,
          ),
          isFalse,
        );
      });

      test(
        'a 5-letter word with a 1-letter typo gets no edit-distance tolerance',
        () {
          expect(
            SpokenAnswer.matchesForm(
              'sentí un gran susto',
              expectedForm: 'gusto',
              forms: gusto,
            ),
            isFalse,
          );
        },
      );

      test('the answer appears only as a substring of another token', () {
        expect(
          SpokenAnswer.matchesForm(
            'Nos casamos ayer',
            expectedForm: 'casa',
            forms: casa,
          ),
          isFalse,
        );
      });

      test('an unrelated word never matches', () {
        expect(
          SpokenAnswer.matchesForm(
            'el cielo esta despejado',
            expectedForm: 'zanjar',
            forms: zanjar,
          ),
          isFalse,
        );
      });
    },
  );
}
