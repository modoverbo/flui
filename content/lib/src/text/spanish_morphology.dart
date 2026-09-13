/// Pragmatic Spanish morphology: enough to check agreement and to fold a
/// surface form back onto a plausible lemma, without bundling a tagger.
///
/// Every helper is deliberately conservative. Where a form is ambiguous the
/// helpers return `null` or a set of possibilities, and the validators only act
/// on unambiguous conflicts.
library;

import 'package:content/src/text/spanish_text.dart';

enum Gender { masculine, feminine }

enum GNumber { singular, plural }

enum Person { first, second, third }

final class Morphology {
  const Morphology({required this.number, this.gender});

  final Gender? gender;
  final GNumber number;
}

/// Determiners that mark gender and/or number of what follows.
const determiners = <String, Morphology>{
  'el': Morphology(gender: Gender.masculine, number: GNumber.singular),
  'los': Morphology(gender: Gender.masculine, number: GNumber.plural),
  'la': Morphology(gender: Gender.feminine, number: GNumber.singular),
  'las': Morphology(gender: Gender.feminine, number: GNumber.plural),
  'un': Morphology(gender: Gender.masculine, number: GNumber.singular),
  'una': Morphology(gender: Gender.feminine, number: GNumber.singular),
  'unos': Morphology(gender: Gender.masculine, number: GNumber.plural),
  'unas': Morphology(gender: Gender.feminine, number: GNumber.plural),
  'este': Morphology(gender: Gender.masculine, number: GNumber.singular),
  'esta': Morphology(gender: Gender.feminine, number: GNumber.singular),
  'estos': Morphology(gender: Gender.masculine, number: GNumber.plural),
  'estas': Morphology(gender: Gender.feminine, number: GNumber.plural),
  'ese': Morphology(gender: Gender.masculine, number: GNumber.singular),
  'esa': Morphology(gender: Gender.feminine, number: GNumber.singular),
  'esos': Morphology(gender: Gender.masculine, number: GNumber.plural),
  'esas': Morphology(gender: Gender.feminine, number: GNumber.plural),
  'aquel': Morphology(gender: Gender.masculine, number: GNumber.singular),
  'aquella': Morphology(gender: Gender.feminine, number: GNumber.singular),
  'aquellos': Morphology(gender: Gender.masculine, number: GNumber.plural),
  'aquellas': Morphology(gender: Gender.feminine, number: GNumber.plural),
  'nuestro': Morphology(gender: Gender.masculine, number: GNumber.singular),
  'nuestra': Morphology(gender: Gender.feminine, number: GNumber.singular),
  'nuestros': Morphology(gender: Gender.masculine, number: GNumber.plural),
  'nuestras': Morphology(gender: Gender.feminine, number: GNumber.plural),
  'otro': Morphology(gender: Gender.masculine, number: GNumber.singular),
  'otra': Morphology(gender: Gender.feminine, number: GNumber.singular),
  'otros': Morphology(gender: Gender.masculine, number: GNumber.plural),
  'otras': Morphology(gender: Gender.feminine, number: GNumber.plural),
  'mi': Morphology(number: GNumber.singular),
  'mis': Morphology(number: GNumber.plural),
  'tu': Morphology(number: GNumber.singular),
  'tus': Morphology(number: GNumber.plural),
  'su': Morphology(number: GNumber.singular),
  'sus': Morphology(number: GNumber.plural),
  'cada': Morphology(number: GNumber.singular),
};

/// Words that may stand between a determiner (or noun) and the blank without
/// changing agreement.
const degreeModifiers = <String>{
  'muy',
  'tan',
  'mas',
  'menos',
  'poco',
  'bastante',
  'demasiado',
  'realmente',
  'verdaderamente',
  'francamente',
  'sumamente',
  'tremendamente',
  'increiblemente',
  'especialmente',
  'ciertamente',
};

/// Function words that stop the agreement scan: when one of them sits right
/// before the blank there is no nominal head to agree with.
const agreementStopWords = <String>{
  'es',
  'son',
  'era',
  'eran',
  'fue',
  'fueron',
  'sea',
  'sean',
  'ser',
  'esta',
  'estan',
  'estaba',
  'estaban',
  'estar',
  'parece',
  'parecen',
  'resulta',
  'resultan',
  'suena',
  'suenan',
  'y',
  'e',
  'o',
  'u',
  'ni',
  'pero',
  'que',
  'si',
  'como',
  'cuando',
  'donde',
  'porque',
  'aunque',
  'de',
  'en',
  'a',
  'con',
  'por',
  'para',
  'sin',
  'sobre',
  'entre',
  'hasta',
  'desde',
  'tras',
  'ya',
  'aun',
  'tambien',
  'tampoco',
  'siempre',
  'nunca',
  'se',
  'le',
  'les',
  'me',
  'te',
  'nos',
  'lo',
  'al',
  'del',
  'no',
};

/// Subject pronouns and the person/number they impose on a following verb.
const subjectPronouns = <String, (Person, GNumber)>{
  'yo': (Person.first, GNumber.singular),
  'tu': (Person.second, GNumber.singular),
  'usted': (Person.third, GNumber.singular),
  'el': (Person.third, GNumber.singular),
  'ella': (Person.third, GNumber.singular),
  'nosotros': (Person.first, GNumber.plural),
  'nosotras': (Person.first, GNumber.plural),
  'ustedes': (Person.third, GNumber.plural),
  'ellos': (Person.third, GNumber.plural),
  'ellas': (Person.third, GNumber.plural),
};

/// Gender and number a nominal surface form marks, when it marks any.
Morphology nominalMorphology(String surface) {
  final folded = foldForComparison(surface).trim();
  if (folded.endsWith('os')) {
    return const Morphology(gender: Gender.masculine, number: GNumber.plural);
  }
  if (folded.endsWith('as')) {
    return const Morphology(gender: Gender.feminine, number: GNumber.plural);
  }
  if (folded.endsWith('es') || folded.endsWith('s')) {
    return const Morphology(number: GNumber.plural);
  }
  if (folded.endsWith('o')) {
    return const Morphology(gender: Gender.masculine, number: GNumber.singular);
  }
  if (folded.endsWith('a')) {
    return const Morphology(gender: Gender.feminine, number: GNumber.singular);
  }
  return const Morphology(number: GNumber.singular);
}

/// Person/number combinations a finite verb form is compatible with.
Set<(Person, GNumber)> verbAgreement(String surface) {
  final folded = foldForComparison(surface).trim().split(' ').last;
  if (folded.endsWith('mos')) return {(Person.first, GNumber.plural)};
  if (folded.endsWith('n')) return {(Person.third, GNumber.plural)};
  if (folded.endsWith('s')) return {(Person.second, GNumber.singular)};
  return {(Person.first, GNumber.singular), (Person.third, GNumber.singular)};
}

const _verbEndings = <String, List<String>>{
  'ar': [
    'o',
    'as',
    'a',
    'amos',
    'an',
    'e',
    'es',
    'en',
    'aba',
    'abas',
    'aban',
    'abamos',
    'ado',
    'ando',
    'ara',
    'aron',
    'aria',
  ],
  'er': [
    'o',
    'es',
    'e',
    'emos',
    'en',
    'a',
    'as',
    'an',
    'ia',
    'ias',
    'ian',
    'ido',
    'iendo',
    'io',
    'ieron',
  ],
  'ir': [
    'o',
    'es',
    'e',
    'imos',
    'en',
    'a',
    'as',
    'an',
    'ia',
    'ias',
    'ian',
    'ido',
    'iendo',
    'io',
    'ieron',
  ],
};

/// Clitics that glue onto an infinitive or gerund.
final _cliticSuffix = RegExp(
  r'(ar|er|ir|ando|iendo)(me|te|se|nos|os|lo|la|le|los|las|les|selo|sela)$',
);

const _irregularLemmas = <String, String>{
  'dijo': 'decir',
  'dijeron': 'decir',
  'hizo': 'hacer',
  'hicieron': 'hacer',
  'puso': 'poner',
  'pusieron': 'poner',
  'tuvo': 'tener',
  'tuvieron': 'tener',
  'vino': 'venir',
  'vinieron': 'venir',
  'quiso': 'querer',
  'quisieron': 'querer',
  'supo': 'saber',
  'pudo': 'poder',
  'pudieron': 'poder',
  'dio': 'dar',
  'dieron': 'dar',
  'vio': 'ver',
  'vieron': 'ver',
  'fue': 'ser',
  'fueron': 'ser',
  'es': 'ser',
  'son': 'ser',
  'era': 'ser',
  'eran': 'ser',
  'esta': 'estar',
  'estan': 'estar',
  'ha': 'haber',
  'han': 'haber',
  'hay': 'haber',
  'va': 'ir',
  'van': 'ir',
  'tiene': 'tener',
  'tienen': 'tener',
  'hace': 'hacer',
  'hacen': 'hacer',
  'dice': 'decir',
  'dicen': 'decir',
};

/// Plausible lemmas for a surface form: the form itself plus a handful of
/// mechanical reductions. Used only for membership tests against a frequency
/// list, never to rewrite content.
Set<String> lemmaCandidates(String surface) {
  final folded = foldForComparison(surface);
  final candidates = <String>{folded};
  final irregular = _irregularLemmas[folded];
  if (irregular != null) candidates.add(irregular);
  final clitic = _cliticSuffix.firstMatch(folded);
  if (clitic != null) {
    candidates.add(folded.substring(0, clitic.start + clitic[1]!.length));
  }
  if (folded.endsWith('es') && folded.length > 3) {
    candidates.add(folded.substring(0, folded.length - 2));
  }
  if (folded.endsWith('s') && folded.length > 2) {
    candidates.add(folded.substring(0, folded.length - 1));
  }
  if (folded.endsWith('a') || folded.endsWith('as')) {
    final stemOf = folded.replaceFirst(RegExp(r'as?$'), '');
    candidates
      ..add('${stemOf}o')
      ..add(stemOf);
  }
  for (final entry in _verbEndings.entries) {
    for (final ending in entry.value) {
      if (folded.endsWith(ending) && folded.length > ending.length) {
        final candidate =
            folded.substring(0, folded.length - ending.length) + entry.key;
        if (candidate.length >= 3) candidates.add(candidate);
      }
    }
  }
  return candidates;
}

/// Spanish function words that are not "content words" for the vocabulary
/// check.
const spanishFunctionWords = <String>{
  'el',
  'la',
  'los',
  'las',
  'un',
  'una',
  'unos',
  'unas',
  'lo',
  'al',
  'del',
  'de',
  'a',
  'en',
  'con',
  'por',
  'para',
  'sin',
  'sobre',
  'entre',
  'hasta',
  'desde',
  'tras',
  'hacia',
  'segun',
  'contra',
  'ante',
  'bajo',
  'durante',
  'y',
  'e',
  'o',
  'u',
  'ni',
  'pero',
  'sino',
  'aunque',
  'porque',
  'pues',
  'que',
  'quien',
  'quienes',
  'cual',
  'cuales',
  'cuyo',
  'cuya',
  'cuando',
  'donde',
  'como',
  'si',
  'no',
  'se',
  'me',
  'te',
  'le',
  'les',
  'nos',
  'os',
  'mi',
  'mis',
  'tu',
  'tus',
  'su',
  'sus',
  'nuestro',
  'nuestra',
  'nuestros',
  'nuestras',
  'yo',
  'ella',
  'usted',
  'nosotros',
  'nosotras',
  'ustedes',
  'ellos',
  'ellas',
  'este',
  'esta',
  'estos',
  'estas',
  'ese',
  'esa',
  'esos',
  'esas',
  'aquel',
  'aquella',
  'aquellos',
  'aquellas',
  'esto',
  'eso',
  'aquello',
  'es',
  'son',
  'ser',
  'era',
  'eran',
  'fue',
  'fueron',
  'sea',
  'sean',
  'estan',
  'estar',
  'ha',
  'han',
  'hay',
  'haber',
  'muy',
  'mas',
  'menos',
  'tan',
  'tanto',
  'ya',
  'aun',
  'todavia',
  'siempre',
  'nunca',
  'tambien',
  'tampoco',
  'solo',
  'todo',
  'toda',
  'todos',
  'todas',
  'otro',
  'otra',
  'otros',
  'otras',
  'algo',
  'alguien',
  'alguno',
  'alguna',
  'nada',
  'nadie',
  'cada',
  'mismo',
  'misma',
  'mismos',
  'mismas',
  'poco',
  'poca',
  'pocos',
  'pocas',
  'mucho',
  'mucha',
  'muchos',
  'muchas',
  'bien',
  'mal',
  'asi',
  'aqui',
  'alli',
  'ahi',
};
