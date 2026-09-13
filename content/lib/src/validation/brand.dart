import 'package:content/src/model/word.dart';
import 'package:content/src/model/word_texts.dart';
import 'package:content/src/text/spanish_text.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/issue.dart';
import 'package:content/src/validation/validator.dart';

Issue _issue(
  ContentValidator validator,
  String slug,
  String location,
  String message,
) => Issue(
  code: validator.code,
  severity: validator.severity,
  slug: slug,
  location: location,
  message: message,
);

/// School and exam vocabulary from docs/brand.md, plus the registered
/// "#SinMuletillas" trademark and "error" used as a verdict.
final class BannedWordsValidator extends WordValidator {
  const BannedWordsValidator();

  /// Folded token prefixes. A token matches when it starts with one of them.
  static const bannedPrefixes = <String>{
    'leccion',
    'examen',
    'examenes',
    'alumn',
    'profesor',
    'tarea',
    // Only the nouns brand.md bans: "calificar"/"evaluar" also mean "to
    // describe as" and "to assess", which are ordinary Spanish.
    'calificacion',
    'gramatic',
    'memoriza',
    'evaluacion',
    'incorrect',
  };

  static final _sinMuletillas = RegExp('sinmuletillas');

  /// "error" as a verdict on the learner, not "error" as an ordinary noun and
  /// not the negated "no es un error", which reassures rather than judges.
  static final _errorVerdict = RegExp(
    r'(?<!no )\b(eso es|es|fue|ha sido|tuviste|cometiste|has cometido|tienes)\s+(un\s+)?error\b',
  );

  @override
  String get code => 'banned_words';

  @override
  String get description =>
      'no school/exam vocabulary, no #SinMuletillas, no "error" as a verdict';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    for (final text in wordTexts(word)) {
      final folded = foldForComparison(text.value);
      for (final token in foldedTokens(text.value)) {
        final hit = bannedPrefixes.firstWhere(
          token.startsWith,
          orElse: () => '',
        );
        if (hit.isNotEmpty) {
          issues.add(
            _issue(
              this,
              word.slug,
              text.location,
              'banned word "$token" (brand voice)',
            ),
          );
          break;
        }
      }
      if (_sinMuletillas.hasMatch(folded.replaceAll(RegExp('[^a-z]'), ''))) {
        issues.add(
          _issue(
            this,
            word.slug,
            text.location,
            'the #SinMuletillas trademark must not appear',
          ),
        );
      }
      if (_errorVerdict.hasMatch(folded)) {
        issues.add(
          _issue(
            this,
            word.slug,
            text.location,
            '"error" is used as a verdict; flui says "Casi." instead',
          ),
        );
      }
    }
    return issues;
  }
}

/// flui addresses the learner as "tú": never "usted", never "vosotros".
final class SecondPersonValidator extends WordValidator {
  const SecondPersonValidator();

  static const _ustedTokens = <String>{'usted', 'ustedes'};
  static const _vosotrosTokens = <String>{
    'vosotros',
    'vosotras',
    'vuestro',
    'vuestra',
    'vuestros',
    'vuestras',
  };

  /// Vosotros verb endings, matched with their accent: `sabéis`, `habláis`.
  static final _vosotrosVerb = RegExp(r'(áis|éis)$');

  @override
  String get code => 'second_person';

  @override
  String get description =>
      '"tú" only toward the learner: no usted in instructional copy, no vosotros anywhere';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    for (final text in wordTexts(word)) {
      for (final raw in tokenizeWords(text.value)) {
        final token = raw.toLowerCase();
        final folded = foldForComparison(raw);
        if (text.role == TextRole.instructional &&
            _ustedTokens.contains(folded)) {
          issues.add(
            _issue(
              this,
              word.slug,
              text.location,
              'addresses the learner as "$token"; use "tú"',
            ),
          );
          break;
        }
        if (_vosotrosTokens.contains(folded) || _vosotrosVerb.hasMatch(token)) {
          issues.add(
            _issue(
              this,
              word.slug,
              text.location,
              'peninsular "vosotros" form "$token"',
            ),
          );
          break;
        }
      }
    }
    return issues;
  }
}

/// A regional term, tagged with the country it belongs to.
final class RegionalTerm {
  const RegionalTerm(this.term, this.countries, {this.accentSensitive = false});

  final String term;
  final List<String> countries;

  /// Voseo imperatives only differ from standard forms by the accent, so they
  /// must be matched before folding.
  final bool accentSensitive;
}

/// Regional vocabulary that breaks the pan-Hispanic contract, plus the
/// ordenador/computadora consistency rule.
final class RegionalBlocklistValidator extends WordValidator {
  const RegionalBlocklistValidator();

  static const blocklist = <RegionalTerm>[
    RegionalTerm('platicar', ['mx']),
    RegionalTerm('platica', ['mx']),
    RegionalTerm('platicando', ['mx']),
    RegionalTerm('padrisimo', ['mx']),
    RegionalTerm('chevere', ['ve', 'co']),
    RegionalTerm('guay', ['es']),
    RegionalTerm('curro', ['es']),
    RegionalTerm('currar', ['es']),
    RegionalTerm('ordenador', ['es']),
    RegionalTerm('laburo', ['ar']),
    RegionalTerm('laburar', ['ar']),
    RegionalTerm('vos', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('sos', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('tenés', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('querés', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('podés', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('hacés', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('decís', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('sabés', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('andá', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('mirá', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('vení', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('contá', ['ar', 'uy'], accentSensitive: true),
    RegionalTerm('pensá', ['ar', 'uy'], accentSensitive: true),
  ];

  /// Variants that are each fine on their own but must not be mixed.
  static const variantPairs = <List<String>>[
    ['ordenador'],
    ['computadora', 'computador'],
  ];

  @override
  String get code => 'regional_blocklist';

  @override
  String get description =>
      'no country-specific vocabulary or voseo, and no ordenador/computadora mix';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    for (final text in wordTexts(word)) {
      for (final raw in tokenizeWords(text.value)) {
        final lower = raw.toLowerCase();
        final folded = foldForComparison(raw);
        for (final term in blocklist) {
          final hit = term.accentSensitive
              ? lower == term.term
              : folded == term.term;
          if (hit) {
            issues.add(
              _issue(
                this,
                word.slug,
                text.location,
                'regional term "$raw" (${term.countries.join(', ')}); use a pan-Hispanic word',
              ),
            );
          }
        }
      }
    }
    issues.addAll(_variantConsistency(word, context));
    return issues;
  }

  List<Issue> _variantConsistency(Word word, LibraryContext context) {
    final usedByWord = _variantsUsed(word);
    if (usedByWord.isEmpty) return const [];
    final usedByLibrary = <int>{
      for (final other in context.words) ..._variantsUsed(other),
    };
    if (usedByLibrary.length < 2) return const [];
    return [
      _issue(
        this,
        word.slug,
        'library',
        'inconsistent regional variants across the library: '
            '${variantPairs.map((v) => v.first).join(' / ')}',
      ),
    ];
  }

  Set<int> _variantsUsed(Word word) {
    final tokens = <String>{
      for (final text in wordTexts(word)) ...foldedTokens(text.value),
    };
    return {
      for (var i = 0; i < variantPairs.length; i++)
        if (variantPairs[i].any(tokens.contains)) i,
    };
  }
}

/// Topic screen. Content must stay neutral and safe for an adult audience of
/// mixed nationalities.
final class SensitiveTopicValidator extends WordValidator {
  const SensitiveTopicValidator();

  static final topics = <String, List<RegExp>>{
    'politics': [
      RegExp(r'\belecciones\b'),
      RegExp(r'\bpartido politico\b'),
      RegExp(r'\bcampana electoral\b'),
      RegExp(r'\bdictadura\b'),
      RegExp(r'\b(comunismo|fascismo|socialismo)\b'),
      RegExp(r'\b(diputad|senador|ministr)\w*\b'),
    ],
    'religion': [
      RegExp(r'\b(misa|iglesia|parroquia|rezar|rezo|oracion religiosa)\b'),
      RegExp(r'\b(dios|alá|biblia|coran|evangelio)\b'),
      RegExp(r'\b(catolic|cristian|musulman|judio|judia|ateo|budist)\w*\b'),
    ],
    'immigration': [
      RegExp(
        r'\b(inmigrante|migrante|indocumentad\w*|deportac\w*|deportar|refugiad\w*)\b',
      ),
      RegExp(r'\bpapeles en regla\b'),
    ],
    'health': [
      RegExp(r'\b(cancer|quimioterapia|suicid\w*|funeral|velorio|luto)\b'),
      RegExp(r'\b(murio|muerte|fallecio|fallecido|difunto)\b'),
      RegExp(r'\benfermedad (grave|terminal)\b'),
    ],
    'sex': [
      RegExp(
        r'\b(sexo|sexual|sexuales|erotic\w*|porno\w*|prostitu\w*|orgasmo)\b',
      ),
    ],
    'violence': [
      RegExp(r'\b(matar|asesin\w*|apunalar|golpear|paliza|maltrat\w*|abuso)\b'),
      RegExp(r'\b(guerra|pistola|arma de fuego|secuestr\w*)\b'),
    ],
    'money_shaming': [
      RegExp(r'\bganas poco\b'),
      RegExp(r'\bsueldo (miserable|de hambre)\b'),
      RegExp(r'\b(fracasado|pringado|muerto de hambre)\b'),
    ],
    'stereotype': [
      RegExp(
        r'\b(los|las) (mexican|espanol|argentin|colombian|chilen|peruan|venezolan|cuban|gringo)\w* son\b',
      ),
    ],
  };

  /// Named companies and public figures. Not exhaustive by design: it catches
  /// the names an LLM reaches for first.
  static const namedEntities = <String>{
    'google',
    'apple',
    'microsoft',
    'amazon',
    'facebook',
    'meta',
    'instagram',
    'tiktok',
    'whatsapp',
    'netflix',
    'spotify',
    'tesla',
    'nike',
    'adidas',
    'uber',
    'youtube',
    'twitter',
    'zara',
    'mercadona',
    'walmart',
    'bimbo',
    'telefonica',
    'movistar',
    'santander',
    'bbva',
    'openai',
    'nvidia',
    'coca',
    'pepsi',
    'starbucks',
    'mcdonalds',
    'messi',
    'maradona',
    'ronaldo',
    'shakira',
    'trump',
    'biden',
    'putin',
    'musk',
    'bezos',
    'milei',
    'petro',
    'sheinbaum',
    'bukele',
    'maduro',
    'chavez',
    'castro',
    'franco',
    'peron',
  };

  @override
  String get code => 'sensitive_topic';

  @override
  String get description =>
      'no politics, religion, immigration, illness or death, sex, violence, '
      'real names or brands, salary shaming or national stereotypes';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    for (final text in wordTexts(word)) {
      final folded = foldForComparison(text.value);
      for (final entry in topics.entries) {
        for (final pattern in entry.value) {
          final match = pattern.firstMatch(folded);
          if (match != null) {
            issues.add(
              _issue(
                this,
                word.slug,
                text.location,
                'sensitive topic (${entry.key}): "${match[0]}"',
              ),
            );
            break;
          }
        }
      }
      for (final token in foldedTokens(text.value)) {
        if (namedEntities.contains(token)) {
          issues.add(
            _issue(
              this,
              word.slug,
              text.location,
              'named real brand or person: "$token"',
            ),
          );
          break;
        }
      }
    }
    return issues;
  }
}

/// Spanish typography: « », paired ¿ ¡, curly quotes, no double spaces.
final class TypographyValidator extends WordValidator {
  const TypographyValidator();

  @override
  String get code => 'typography';

  @override
  String get description =>
      'Spanish typography: « », paired ¿/¡, curly quotes, no double spaces';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateWord(Word word, LibraryContext context) {
    final issues = <Issue>[];
    for (final text in wordTexts(word)) {
      final value = text.value;
      void fail(String message) =>
          issues.add(_issue(this, word.slug, text.location, message));

      if (value.contains('"')) {
        fail('straight double quote; use « » or curly quotes');
      }
      if (value.contains("'")) {
        fail('straight apostrophe; use a curly quote');
      }
      if (value.contains('  ')) fail('double space');
      // Spanish writes "20 %" with a space, so the percent sign is not part of
      // the closing-punctuation set.
      if (RegExp(r'\s+[,.;:!?]').hasMatch(value)) {
        fail('space before a closing punctuation mark');
      }
      final opens = '«'.allMatches(value).length;
      final closes = '»'.allMatches(value).length;
      if (opens != closes) fail('unbalanced « » ($opens open, $closes close)');
      final questions = '?'.allMatches(value).length;
      final openQuestions = '¿'.allMatches(value).length;
      if (questions != openQuestions) {
        fail('every ? needs its ¿ ($openQuestions vs $questions)');
      }
      final bangs = '!'.allMatches(value).length;
      final openBangs = '¡'.allMatches(value).length;
      if (bangs != openBangs) {
        fail('every ! needs its ¡ ($openBangs vs $bangs)');
      }
    }
    return issues;
  }
}
