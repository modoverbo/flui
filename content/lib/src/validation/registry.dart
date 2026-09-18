import 'package:content/src/validation/brand.dart';
import 'package:content/src/validation/catalog.dart';
import 'package:content/src/validation/library_text.dart';
import 'package:content/src/validation/linguistic.dart';
import 'package:content/src/validation/originality.dart';
import 'package:content/src/validation/schema.dart';
import 'package:content/src/validation/structural.dart';
import 'package:content/src/validation/validator.dart';

/// The one place that says which validators exist and in which order they run.
abstract final class ValidatorRegistry {
  static const rawValidators = <RawWordValidator>[
    SchemaConformanceValidator(),
  ];

  static const wordValidators = <WordValidator>[
    // Structural
    SlugMatchesLemmaValidator(),
    SyllablesValidator(),
    ExerciseCountValidator(),
    OptionSetValidator(),
    DistractorFieldsValidator(),
    DistractorTypeCoverageValidator(),
    ReadingSetValidator(),
    ConfusionValidator(),
    ReplacesValidator(),
    // Linguistic
    AgreementValidator(),
    DistractorOverlapValidator(),
    AnswerLeakageValidator(),
    HintCueValidator(),
    LengthCapsValidator(),
    ExerciseExplanationCoverageValidator(),
    ExplanationCircularityValidator(),
    CommonVocabularyValidator(),
    // Brand and safety
    BannedWordsValidator(),
    SecondPersonValidator(),
    RegionalBlocklistValidator(),
    SensitiveTopicValidator(),
    TypographyValidator(),
    // Catalog
    ThemeTaxonomyValidator(),
    PedantryGateValidator(),
  ];

  static const libraryValidators = <LibraryValidator>[
    SentenceUniquenessValidator(),
    TemplateDiversityValidator(),
    NameDiversityValidator(),
    DuplicateLemmaValidator(),
    ConfusionSymmetryValidator(),
    SchedulingSimulationValidator(),
  ];

  /// Async validators are opt-in and run last.
  static List<AsyncWordValidator> asyncValidators(SearchFetcher fetcher) => [
    RaeProbeValidator(fetcher),
  ];

  /// Every validator, for `--list` and for the docs.
  static List<ContentValidator> all(SearchFetcher fetcher) => [
    ...rawValidators,
    ...wordValidators,
    ...libraryValidators,
    ...asyncValidators(fetcher),
  ];
}
