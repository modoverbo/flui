import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flui/features/vocabulary/domain/word.dart';

/// The theme taxonomy of `supabase/seed_themes.sql`, in memory.
///
/// Hand-written, unlike `seed_content.dart`: `supabase/seed.sql` is generated
/// from `content/` by `dart run content:emit` and proven byte-identical by
/// `tool/seed_fixture_check.dart`, and that emitter does not write the 16
/// `themes` rows. So the taxonomy lives in a second seed file and its fixture
/// lives here, layered on top of the generated words instead of edited into
/// them. The *links* are not hand-written: `content:emit` owns `word_themes`,
/// so `seedWordThemeSlugs` is generated into `seed_content.dart` and the map
/// from slug to theme id is all this file adds.
/// `test/features/themes/data/themes_data_test.dart` keeps the two in step.
const seedThemes = <Theme>[
  Theme(
    id: 'c0000000-0000-4000-8000-000000000001',
    slug: 'reuniones',
    family: ThemeFamily.trabajo,
    name: 'Reuniones',
    tagline: 'Que se note que estabas ahí.',
    jtbd:
        'Quiero intervenir en una reunión y que mi idea se entienda a la '
        'primera.',
    contentType: ThemeContentType.wordDriven,
    status: ThemeStatus.live,
    sortOrder: 1,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000002',
    slug: 'presentaciones-oratoria',
    family: ThemeFamily.publico,
    name: 'Presentaciones',
    tagline: 'Hablar delante de gente sin sonar a guion.',
    jtbd:
        'Quiero presentar mi trabajo y sonar seguro sin memorizar cada '
        'frase.',
    contentType: ThemeContentType.mixed,
    status: ThemeStatus.live,
    sortOrder: 2,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000003',
    slug: 'entrevistas',
    family: ThemeFamily.trabajo,
    name: 'Entrevistas',
    tagline: 'Contar lo que vales sin exagerar.',
    jtbd:
        'Quiero responder en una entrevista con ejemplos concretos y '
        'palabras justas.',
    contentType: ThemeContentType.mixed,
    status: ThemeStatus.live,
    sortOrder: 3,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000004',
    slug: 'negociacion',
    family: ThemeFamily.trabajo,
    name: 'Negociación',
    tagline: 'Pedir claro y quedar bien.',
    jtbd:
        'Quiero pedir un aumento o cerrar un trato sin sonar agresivo ni '
        'inseguro.',
    contentType: ThemeContentType.mixed,
    status: ThemeStatus.live,
    sortOrder: 4,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000005',
    slug: 'liderazgo-feedback',
    family: ThemeFamily.trabajo,
    name: 'Liderazgo y feedback',
    tagline: 'Decir lo que hay que decir sin romper nada.',
    jtbd:
        'Quiero dar feedback a mi equipo de forma que se entienda y no '
        'duela.',
    contentType: ThemeContentType.wordDriven,
    status: ThemeStatus.live,
    sortOrder: 5,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000006',
    slug: 'conflicto-desacuerdo',
    family: ThemeFamily.emocion,
    name: 'Desacuerdos',
    tagline: 'No estar de acuerdo sin convertirlo en pelea.',
    jtbd:
        'Quiero discrepar en voz alta y que la conversación siga siendo '
        'posible.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.live,
    sortOrder: 6,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000007',
    slug: 'correos-mensajes',
    family: ThemeFamily.trabajo,
    name: 'Correos y mensajes',
    tagline: 'Escribir corto y que no suene seco.',
    jtbd:
        'Quiero escribir un correo breve que consiga respuesta y no parezca '
        'brusco.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.live,
    sortOrder: 7,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000008',
    slug: 'redaccion-ejecutiva',
    family: ThemeFamily.trabajo,
    name: 'Escribir para que te lean',
    tagline: 'Menos palabras, más decisión.',
    jtbd:
        'Quiero resumir un tema complejo en un párrafo que alguien ocupado '
        'entienda.',
    contentType: ThemeContentType.wordDriven,
    status: ThemeStatus.live,
    sortOrder: 8,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000009',
    slug: 'persuasion-storytelling',
    family: ThemeFamily.publico,
    name: 'Convencer y contar',
    tagline: 'Una idea se recuerda cuando tiene forma de historia.',
    jtbd:
        'Quiero contar lo que hice de modo que la otra persona lo recuerde '
        'mañana.',
    contentType: ThemeContentType.mixed,
    status: ThemeStatus.live,
    sortOrder: 9,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000010',
    slug: 'conversaciones-dificiles',
    family: ThemeFamily.emocion,
    name: 'Conversaciones difíciles',
    tagline: 'Abrir el tema que llevas semanas evitando.',
    jtbd:
        'Quiero empezar una conversación incómoda sin que la otra persona '
        'se cierre.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.live,
    sortOrder: 10,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000011',
    slug: 'matices-precision',
    family: ThemeFamily.precision,
    name: 'Matices',
    tagline: 'La diferencia entre parecido y exacto.',
    jtbd:
        'Quiero decir exactamente lo que pienso, ni más fuerte ni más '
        'flojo.',
    contentType: ThemeContentType.wordDriven,
    status: ThemeStatus.live,
    sortOrder: 11,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000012',
    slug: 'conectores-estructura',
    family: ThemeFamily.precision,
    name: 'Conectores',
    tagline: 'Las palabras que sostienen una idea larga.',
    jtbd:
        'Quiero enlazar mis ideas para que se sigan sin perderse a la '
        'mitad.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.soon,
    sortOrder: 12,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000013',
    slug: 'paronimos',
    family: ThemeFamily.precision,
    name: 'Palabras que se parecen',
    tagline: 'Dos palabras casi iguales, dos significados distintos.',
    jtbd:
        'Quiero dejar de confundir pares que se parecen y suenan a '
        'descuido.',
    contentType: ThemeContentType.wordDriven,
    status: ThemeStatus.soon,
    sortOrder: 13,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000014',
    slug: 'elogio-reconocimiento',
    family: ThemeFamily.social,
    name: 'Reconocer a otros',
    tagline: 'Un elogio preciso vale por diez genéricos.',
    jtbd:
        'Quiero reconocer el trabajo de alguien de forma específica y '
        'creíble.',
    contentType: ThemeContentType.wordDriven,
    status: ThemeStatus.live,
    sortOrder: 14,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000015',
    slug: 'decir-que-no',
    family: ThemeFamily.emocion,
    name: 'Decir que no',
    tagline: 'Negarte sin dar diez explicaciones.',
    jtbd: 'Quiero rechazar una petición y mantener la relación intacta.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.soon,
    sortOrder: 15,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000016',
    slug: 'conversacion-cotidiana',
    family: ThemeFamily.social,
    name: 'Conversación diaria',
    tagline: 'Hablar del día a día con palabras que encajan.',
    jtbd:
        'Quiero contar lo que me pasa sin repetir siempre cosa, tema y '
        'hacer.',
    contentType: ThemeContentType.mixed,
    status: ThemeStatus.soon,
    sortOrder: 16,
  ),
];

/// Word slug to `words.semantic_set_id`. «Contundente» reinforces an
/// assertion and «matizar» softens it: two ends of one axis, so they are
/// never introduced within 7 days of each other (Tinkham 1993; Nation 2000).
const seedWordSemanticSets = <String, String>{
  'contundente': 'fuerza-de-la-afirmacion',
  'matizar': 'fuerza-de-la-afirmacion',
};

/// The generated seed words with their themes and semantic sets layered on.
final seedWordsWithThemes = <Word>[
  for (final word in seedWords)
    word.copyWith(
      themeIds: [
        for (final slug in seedWordThemeSlugs[word.slug] ?? const <String>[])
          _themeIdOf(slug),
      ],
      semanticSetId: seedWordSemanticSets[word.slug],
    ),
];

final Map<String, String> _themeIdBySlug = {
  for (final theme in seedThemes) theme.slug: theme.id,
};

String _themeIdOf(String slug) =>
    _themeIdBySlug[slug] ?? (throw StateError('unknown theme slug: $slug'));
