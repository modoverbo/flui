import 'package:content/src/model/behavior_catalog.dart';
import 'package:content/src/model/challenge.dart';
import 'package:content/src/text/spanish_text.dart';
import 'package:content/src/validation/brand.dart';
import 'package:content/src/validation/issue.dart';
import 'package:content/src/validation/validator.dart';

/// Runs against the raw YAML map, before the challenge model exists.
///
/// Does not touch the word validator types of
/// `content/lib/src/validation/registry.dart`/`validator.dart` — challenges
/// have their own raw/parsed base types, mirroring the word ones without
/// extending them (a challenge is not a word).
abstract class RawChallengeValidator extends ContentValidator {
  const RawChallengeValidator();

  List<Issue> validateRaw(String slug, Map<String, Object?> raw);
}

/// Runs against one parsed challenge.
abstract class ChallengeValidator extends ContentValidator {
  const ChallengeValidator();

  List<Issue> validateChallenge(Challenge challenge);
}

/// Runs against every parsed challenge at once. Mirrors
/// `content/lib/src/validation/validator.dart`'s `LibraryValidator`, kept
/// separate because a challenge library check needs only the flat list of
/// challenges, not a word `LibraryContext` (taxonomy, common lemmas, etc.).
abstract class ChallengeLibraryValidator extends ContentValidator {
  const ChallengeLibraryValidator();

  List<Issue> validateChallengeLibrary(List<Challenge> challenges);
}

/// Structural conformance of a raw challenge file, run before the model is
/// built. Mirrors `content/lib/src/validation/schema.dart`'s
/// `SchemaConformanceValidator` and `content/schema/challenge.schema.json`;
/// covers field presence, enum membership, the slug/file-name match, the
/// purpose<->diagnosis_slot/mode consistency, transfer-prompt count, and
/// every numeric range (difficulty, diagnosis_slot, target_seconds).
final class ChallengeSchemaConformanceValidator extends RawChallengeValidator {
  const ChallengeSchemaConformanceValidator();

  static const requiredKeys = <String>{
    'slug',
    'status',
    'purpose',
    'skill',
    'difficulty',
    'prompt',
    'focus',
    'transfer_prompts',
    'target_seconds',
  };

  static const optionalKeys = <String>{
    'id',
    'sort_order',
    'diagnosis_slot',
    'mode',
    'cue',
    'focus_behaviors',
  };

  static Set<String> get knownKeys => {...requiredKeys, ...optionalKeys};

  static const _statuses = {'draft', 'validated', 'gated', 'approved'};
  static const _purposes = {'training', 'diagnosis'};
  static const _skills = {'thinking', 'language', 'voice'};
  static const _modes = {
    'think_and_speak',
    'speak_with_precision',
    'master_your_voice',
    'real_situations',
  };

  static final _slugPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  @override
  String get code => 'challenge_schema';

  @override
  String get description =>
      'the file conforms to content/schema/challenge.schema.json';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateRaw(String slug, Map<String, Object?> raw) {
    final issues = <Issue>[];
    void fail(String location, String message) => issues.add(
      Issue(
        code: code,
        severity: severity,
        slug: slug,
        location: location,
        message: message,
      ),
    );

    for (final key in requiredKeys) {
      if (!raw.containsKey(key)) fail(key, 'missing required key "$key"');
    }
    for (final key in raw.keys) {
      if (!knownKeys.contains(key)) fail(key, 'unknown key "$key"');
    }

    void expectString(
      String key,
      Object? value, {
      bool nullable = false,
      int? minLength,
      int? maxLength,
    }) {
      if (value == null && nullable) return;
      if (value is! String || value.trim().isEmpty) {
        fail(key, '"$key" must be a non-empty string');
        return;
      }
      if (minLength != null && value.length < minLength) {
        fail(key, '"$key" must be at least $minLength characters');
      }
      if (maxLength != null && value.length > maxLength) {
        fail(key, '"$key" must be at most $maxLength characters');
      }
    }

    void expectInt(
      String key,
      Object? value, {
      int? min,
      int? max,
      bool nullable = false,
    }) {
      if (value == null && nullable) return;
      if (value is! int) {
        fail(key, '"$key" must be an integer');
        return;
      }
      if (min != null && value < min) fail(key, '"$key" must be >= $min');
      if (max != null && value > max) fail(key, '"$key" must be <= $max');
    }

    void expectEnum(
      String key,
      Object? value,
      Set<String> allowed, {
      bool nullable = false,
    }) {
      if (value == null && nullable) return;
      if (value is! String || !allowed.contains(value)) {
        fail(key, '"$key" must be one of ${allowed.toList()..sort()}');
      }
    }

    if (raw.containsKey('slug')) {
      final value = raw['slug'];
      if (value is! String || !_slugPattern.hasMatch(value)) {
        fail('slug', 'slug must be kebab-case ([a-z0-9] and single hyphens)');
      } else if (value != slug) {
        fail(
          'slug',
          'the file is named "$slug.yml" but declares slug "$value"',
        );
      }
    }
    if (raw.containsKey('status')) {
      expectEnum('status', raw['status'], _statuses);
    }
    final purpose = raw['purpose'];
    if (raw.containsKey('purpose')) expectEnum('purpose', purpose, _purposes);
    if (raw.containsKey('skill')) expectEnum('skill', raw['skill'], _skills);
    if (raw.containsKey('difficulty')) {
      expectInt('difficulty', raw['difficulty'], min: 1, max: 3);
    }
    if (raw.containsKey('prompt')) {
      expectString('prompt', raw['prompt'], minLength: 10, maxLength: 280);
    }
    expectString('cue', raw['cue'], nullable: true, maxLength: 200);
    if (raw.containsKey('focus')) {
      expectString('focus', raw['focus'], minLength: 5, maxLength: 200);
    }
    if (raw.containsKey('target_seconds')) {
      expectInt('target_seconds', raw['target_seconds'], min: 15, max: 60);
    }
    if (raw['id'] != null) expectString('id', raw['id'], nullable: true);
    if (raw['sort_order'] != null) {
      expectInt('sort_order', raw['sort_order'], min: 1);
    }

    final isDiagnosis = purpose == 'diagnosis';
    final isTraining = purpose == 'training';
    final slotValue = raw['diagnosis_slot'];
    if (isDiagnosis) {
      expectInt('diagnosis_slot', slotValue, min: 1, max: 3);
    } else if (slotValue != null) {
      fail(
        'diagnosis_slot',
        'diagnosis_slot must be null unless purpose is "diagnosis"',
      );
    }
    final modeValue = raw['mode'];
    if (isTraining) {
      expectEnum('mode', modeValue, _modes);
    } else if (modeValue != null) {
      fail('mode', 'mode must be null unless purpose is "training"');
    }

    if (raw.containsKey('transfer_prompts')) {
      final value = raw['transfer_prompts'];
      if (value is! List) {
        fail('transfer_prompts', '"transfer_prompts" must be a list');
      } else {
        final minCount = isTraining ? 1 : 0;
        if (value.length < minCount) {
          fail(
            'transfer_prompts',
            'training challenges need at least 1 transfer prompt',
          );
        }
        if (value.length > 3) {
          fail(
            'transfer_prompts',
            'transfer_prompts allows at most 3 items, found ${value.length}',
          );
        }
        for (var i = 0; i < value.length; i++) {
          expectString('transfer_prompts[$i]', value[i]);
        }
      }
    }
    if (raw['focus_behaviors'] != null) {
      final value = raw['focus_behaviors'];
      if (value is! List) {
        fail('focus_behaviors', '"focus_behaviors" must be a list');
      } else {
        for (var i = 0; i < value.length; i++) {
          expectString('focus_behaviors[$i]', value[i]);
        }
      }
    }

    return issues;
  }
}

/// Every `focus_behaviors` wire code must be a known
/// `content/lib/src/model/behavior_catalog.dart` code, and its area must
/// match the challenge's own `skill` (fluency codes match `skill: voice`).
final class FocusBehaviorsValidator extends ChallengeValidator {
  const FocusBehaviorsValidator();

  @override
  String get code => 'focus_behaviors_catalog';

  @override
  String get description =>
      'focus_behaviors are known wire codes matching the challenge skill';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateChallenge(Challenge challenge) {
    final issues = <Issue>[];
    for (var i = 0; i < challenge.focusBehaviors.length; i++) {
      final wireCode = challenge.focusBehaviors[i];
      final behavior = BehaviorCode.fromWireCode(wireCode);
      if (behavior == null) {
        issues.add(
          Issue(
            code: code,
            severity: severity,
            slug: challenge.slug,
            location: 'focus_behaviors[$i]',
            message: 'unknown behavior code "$wireCode"',
          ),
        );
        continue;
      }
      if (behavior.area.skill != challenge.skill) {
        issues.add(
          Issue(
            code: code,
            severity: severity,
            slug: challenge.slug,
            location: 'focus_behaviors[$i]',
            message:
                'behavior "$wireCode" belongs to ${behavior.area.name}, '
                'not ${challenge.skill.name}',
          ),
        );
      }
    }
    return issues;
  }
}

/// No two challenges may share a slug. The file loader already forces a
/// file's own `slug` field to match its file name
/// (`ChallengeSchemaConformanceValidator`), so within one `challenges/`
/// directory this can only fire on a loader bug or a future multi-source
/// setup — it stays a real, cheap invariant either way, mirroring
/// `content/lib/src/validation/catalog.dart`'s `DuplicateLemmaValidator` for
/// words.
final class UniqueChallengeSlugsValidator extends ChallengeLibraryValidator {
  const UniqueChallengeSlugsValidator();

  @override
  String get code => 'unique_challenge_slugs';

  @override
  String get description => 'no two challenges share a slug';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateChallengeLibrary(List<Challenge> challenges) {
    final owners = <String, List<Challenge>>{};
    for (final challenge in challenges) {
      owners.putIfAbsent(challenge.slug, () => []).add(challenge);
    }
    return [
      for (final entry in owners.entries)
        if (entry.value.length > 1)
          Issue(
            code: code,
            severity: severity,
            slug: entry.key,
            location: 'slug',
            message:
                'slug "${entry.key}" is used by ${entry.value.length} '
                'challenges',
          ),
    ];
  }
}

/// Every diagnosis slot (1-3) needs at least one `approved` challenge
/// (blocking) so the diagnosis loop always has a prompt to run; design part-3
/// §10 also relies on a second, unused variant being available for a retake,
/// so a slot with exactly one approved challenge only warns.
final class DiagnosisSlotCoverageValidator extends ChallengeLibraryValidator {
  const DiagnosisSlotCoverageValidator();

  static const _slots = [1, 2, 3];

  @override
  String get code => 'diagnosis_slot_coverage';

  @override
  String get description =>
      'each diagnosis slot 1-3 has >=1 approved challenge (warns below 2, '
      'the retake variant)';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateChallengeLibrary(List<Challenge> challenges) {
    final approvedBySlot = <int, int>{};
    for (final challenge in challenges) {
      if (challenge.status != ChallengeStatus.approved) continue;
      if (challenge.purpose != ChallengePurpose.diagnosis) continue;
      final slot = challenge.diagnosisSlot;
      if (slot == null) continue;
      approvedBySlot[slot] = (approvedBySlot[slot] ?? 0) + 1;
    }
    final issues = <Issue>[];
    for (final slot in _slots) {
      final count = approvedBySlot[slot] ?? 0;
      if (count == 0) {
        issues.add(
          Issue(
            code: code,
            severity: Severity.blocking,
            slug: '',
            location: 'diagnosis_slot[$slot]',
            message: 'diagnosis slot $slot has no approved challenge',
          ),
        );
      } else if (count < 2) {
        issues.add(
          Issue(
            code: code,
            severity: Severity.warn,
            slug: '',
            location: 'diagnosis_slot[$slot]',
            message:
                'diagnosis slot $slot has only $count approved '
                'challenge; a second variant lets a retake avoid repeating '
                'the same prompt',
          ),
        );
      }
    }
    return issues;
  }
}

/// Every training mode needs an `approved` challenge at difficulty 1
/// (blocking — ENTRENAR and the planner must always have an entry point) and
/// at difficulty 2 and 3 (warning — needed before real users progress there,
/// but not before the first slice ships).
final class TrainingModeCoverageValidator extends ChallengeLibraryValidator {
  const TrainingModeCoverageValidator();

  static const _difficulties = [1, 2, 3];

  @override
  String get code => 'training_mode_coverage';

  @override
  String get description =>
      'each training mode has an approved challenge at difficulty 1 (error) '
      'and at 2 and 3 (warning)';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateChallengeLibrary(List<Challenge> challenges) {
    final approved = <TrainingMode, Map<int, int>>{
      for (final mode in TrainingMode.values) mode: {1: 0, 2: 0, 3: 0},
    };
    for (final challenge in challenges) {
      if (challenge.status != ChallengeStatus.approved) continue;
      if (challenge.purpose != ChallengePurpose.training) continue;
      final mode = challenge.mode;
      if (mode == null) continue;
      final byDifficulty = approved[mode]!;
      if (_difficulties.contains(challenge.difficulty)) {
        byDifficulty[challenge.difficulty] =
            (byDifficulty[challenge.difficulty] ?? 0) + 1;
      }
    }
    final issues = <Issue>[];
    for (final mode in TrainingMode.values) {
      final byDifficulty = approved[mode]!;
      for (final difficulty in _difficulties) {
        if ((byDifficulty[difficulty] ?? 0) > 0) continue;
        issues.add(
          Issue(
            code: code,
            severity: difficulty == 1 ? Severity.blocking : Severity.warn,
            slug: '',
            location: 'training_mode[${mode.wireName}].difficulty[$difficulty]',
            message:
                'training mode "${mode.wireName}" has no approved '
                'challenge at difficulty $difficulty',
          ),
        );
      }
    }
    return issues;
  }
}

/// Every learner-facing text field (`prompt`, `cue`, `focus`, each
/// `transfer_prompts` entry) must respect flui's brand voice: no
/// school/exam vocabulary, "tú" only (no "usted", no "vosotros"), no
/// regional vocabulary, no sensitive topics or named real people/brands, and
/// correct Spanish typography.
///
/// Reuses the closed catalogs `content/lib/src/validation/brand.dart`'s
/// word-level validators already maintain —
/// [BannedWordsValidator.bannedPrefixes], [RegionalBlocklistValidator.blocklist]
/// and [SensitiveTopicValidator.topics]/[SensitiveTopicValidator.namedEntities]
/// are public static constants, so there is exactly one banned-word list, one
/// regional blocklist and one sensitive-topic list for the whole package.
/// The "tú"-only and typography checks are re-implemented at matching
/// strictness: their word-level counterparts (`SecondPersonValidator`,
/// `TypographyValidator`) key their regexes to `WordText`'s role/location
/// tracking and declare them library-private (a bare leading underscore, not
/// a class member), so there is nothing importable to call from here.
final class ChallengeBrandValidator extends ChallengeValidator {
  const ChallengeBrandValidator();

  static final _vosotrosVerb = RegExp(r'(áis|éis)$');
  static const _ustedTokens = <String>{'usted', 'ustedes'};
  static const _vosotrosTokens = <String>{
    'vosotros',
    'vosotras',
    'vuestro',
    'vuestra',
    'vuestros',
    'vuestras',
  };

  @override
  String get code => 'challenge_brand';

  @override
  String get description =>
      'prompt/cue/focus/transfer_prompts follow brand voice: no banned '
      'words, "tú" only, no regional terms, no sensitive topics, correct '
      'Spanish typography';

  @override
  Severity get severity => Severity.blocking;

  List<(String, String)> _texts(Challenge challenge) => [
    ('prompt', challenge.prompt),
    if (challenge.cue != null) ('cue', challenge.cue!),
    ('focus', challenge.focus),
    for (var i = 0; i < challenge.transferPrompts.length; i++)
      ('transfer_prompts[$i]', challenge.transferPrompts[i]),
  ];

  @override
  List<Issue> validateChallenge(Challenge challenge) {
    final issues = <Issue>[];
    void fail(String location, String message) => issues.add(
      Issue(
        code: code,
        severity: severity,
        slug: challenge.slug,
        location: location,
        message: message,
      ),
    );

    for (final (location, text) in _texts(challenge)) {
      final folded = foldForComparison(text);

      for (final token in foldedTokens(text)) {
        final hit = BannedWordsValidator.bannedPrefixes.firstWhere(
          token.startsWith,
          orElse: () => '',
        );
        if (hit.isNotEmpty) {
          fail(location, 'banned word "$token" (brand voice)');
          break;
        }
      }

      for (final raw in tokenizeWords(text)) {
        final foldedWord = foldForComparison(raw);
        if (_ustedTokens.contains(foldedWord)) {
          fail(location, 'addresses the learner as "$raw"; use "tú"');
          break;
        }
        if (_vosotrosTokens.contains(foldedWord) ||
            _vosotrosVerb.hasMatch(raw.toLowerCase())) {
          fail(location, 'peninsular "vosotros" form "$raw"');
          break;
        }
      }

      for (final term in RegionalBlocklistValidator.blocklist) {
        for (final raw in tokenizeWords(text)) {
          final hit = term.accentSensitive
              ? raw.toLowerCase() == term.term
              : foldForComparison(raw) == term.term;
          if (hit) {
            fail(
              location,
              'regional term "$raw" (${term.countries.join(', ')}); use a '
              'pan-Hispanic word',
            );
          }
        }
      }

      for (final entry in SensitiveTopicValidator.topics.entries) {
        final match = entry.value
            .map((pattern) => pattern.firstMatch(folded))
            .firstWhere((m) => m != null, orElse: () => null);
        if (match != null) {
          fail(location, 'sensitive topic (${entry.key}): "${match[0]}"');
        }
      }
      for (final token in foldedTokens(text)) {
        if (SensitiveTopicValidator.namedEntities.contains(token)) {
          fail(location, 'named real brand or person: "$token"');
          break;
        }
      }

      if (text.contains('"')) {
        fail(location, 'straight double quote; use « » or curly quotes');
      }
      if (text.contains("'")) {
        fail(location, 'straight apostrophe; use a curly quote');
      }
      if (text.contains('  ')) fail(location, 'double space');
      if (RegExp(r'\s+[,.;:!?]').hasMatch(text)) {
        fail(location, 'space before a closing punctuation mark');
      }
      final opens = '«'.allMatches(text).length;
      final closes = '»'.allMatches(text).length;
      if (opens != closes) {
        fail(location, 'unbalanced « » ($opens open, $closes close)');
      }
      final questions = '?'.allMatches(text).length;
      final openQuestions = '¿'.allMatches(text).length;
      if (questions != openQuestions) {
        fail(location, 'every ? needs its ¿ ($openQuestions vs $questions)');
      }
      final bangs = '!'.allMatches(text).length;
      final openBangs = '¡'.allMatches(text).length;
      if (bangs != openBangs) {
        fail(location, 'every ! needs its ¡ ($openBangs vs $bangs)');
      }
    }
    return issues;
  }
}

/// The one place that says which challenge validators exist and in which
/// order they run. Does not touch `content/lib/src/validation/registry.dart`'s
/// word `ValidatorRegistry`.
abstract final class ChallengeValidatorRegistry {
  static const rawValidators = <RawChallengeValidator>[
    ChallengeSchemaConformanceValidator(),
  ];

  static const challengeValidators = <ChallengeValidator>[
    FocusBehaviorsValidator(),
    ChallengeBrandValidator(),
  ];

  static const libraryValidators = <ChallengeLibraryValidator>[
    UniqueChallengeSlugsValidator(),
    DiagnosisSlotCoverageValidator(),
    TrainingModeCoverageValidator(),
  ];

  /// Every validator, for `--list` and for the docs.
  static List<ContentValidator> all() => [
    ...rawValidators,
    ...challengeValidators,
    ...libraryValidators,
  ];
}
