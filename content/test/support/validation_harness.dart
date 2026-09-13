import 'dart:io';

import 'package:content/src/model/theme.dart';
import 'package:content/src/model/word.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/issue.dart';
import 'package:content/src/validation/validator.dart';

import 'fixtures.dart';

final ThemeTaxonomy testTaxonomy = ThemeTaxonomy.parse(
  File('themes.yml').readAsStringSync(),
);

LibraryContext contextOf(
  List<Word> words, {
  Set<String>? commonLemmas,
  ValidationOptions options = const ValidationOptions(),
}) => LibraryContext(
  words: words,
  taxonomy: testTaxonomy,
  commonLemmas: commonLemmas,
  options: options,
);

/// Runs a word validator against a one-word library.
List<Issue> runWord(
  WordValidator validator,
  Word word, {
  LibraryContext? context,
  Set<String>? commonLemmas,
  ValidationOptions options = const ValidationOptions(),
}) => validator.validateWord(
  word,
  context ?? contextOf([word], commonLemmas: commonLemmas, options: options),
);

List<Issue> runLibrary(
  LibraryValidator validator,
  List<Word> words, {
  ValidationOptions options = const ValidationOptions(),
}) => validator.validateLibrary(contextOf(words, options: options));

/// Canonical word with top-level keys replaced.
Word wordFrom(Map<String, Object?> overrides) =>
    Word.fromMap(validWordMap()..addAll(overrides));

/// Canonical word with one field of exercise [index] replaced.
Word wordWithExercise(int index, Map<String, Object?> overrides) {
  final map = validWordMap();
  final exercises = (map['exercises']! as List<Object?>)
      .cast<Map<String, Object?>>();
  exercises[index].addAll(overrides);
  return Word.fromMap(map);
}

/// Canonical word with one field of option [optionIndex] of exercise
/// [exerciseIndex] replaced. A null value removes the key.
Word wordWithOption(
  int exerciseIndex,
  int optionIndex,
  Map<String, Object?> overrides,
) {
  final map = validWordMap();
  final exercises = (map['exercises']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final options = (exercises[exerciseIndex]['options']! as List<Object?>)
      .cast<Map<String, Object?>>();
  options[optionIndex].addAll(overrides);
  return Word.fromMap(map);
}

/// Canonical word with one reading field replaced.
Word wordWithReading(int index, Map<String, Object?> overrides) {
  final map = validWordMap();
  final readings = (map['readings']! as List<Object?>)
      .cast<Map<String, Object?>>();
  readings[index].addAll(overrides);
  return Word.fromMap(map);
}
