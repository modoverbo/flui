import 'package:content/src/model/behavior_catalog.dart';
import 'package:content/src/model/challenge.dart';
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

/// The one place that says which challenge validators exist and in which
/// order they run. Does not touch `content/lib/src/validation/registry.dart`'s
/// word `ValidatorRegistry`.
abstract final class ChallengeValidatorRegistry {
  static const rawValidators = <RawChallengeValidator>[
    ChallengeSchemaConformanceValidator(),
  ];

  static const challengeValidators = <ChallengeValidator>[
    FocusBehaviorsValidator(),
  ];

  /// Every validator, for `--list` and for the docs.
  static List<ContentValidator> all() => [
    ...rawValidators,
    ...challengeValidators,
  ];
}
