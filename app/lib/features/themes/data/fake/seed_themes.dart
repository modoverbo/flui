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

/// The twelve recombination themes of `supabase/seed_themes.sql` section 2
/// (sort_order 17..28): `published = false` there, so `FakeThemeRepository`
/// (mirroring the real `.eq('published', true)` query) never serves them and
/// they stay out of [seedThemes]. Content authors tag words with them ahead
/// of launch — "reuse the words the first sixteen introduce" — so a word's
/// `themeIds` can resolve one of these ids long before the theme is offered.
/// This list exists only so [_themeIdOf] has somewhere to look them up.
const unpublishedSeedThemes = <Theme>[
  Theme(
    id: 'c0000000-0000-4000-8000-000000000017',
    slug: 'ventas',
    family: ThemeFamily.trabajo,
    name: 'Ventas',
    tagline: 'Que el valor se vea, sin inflarlo.',
    jtbd:
        'Quiero explicar lo que ofrezco con ejemplos concretos y que el '
        'precio deje de ser el único tema.',
    contentType: ThemeContentType.mixed,
    status: ThemeStatus.soon,
    sortOrder: 17,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000018',
    slug: 'networking',
    family: ThemeFamily.trabajo,
    name: 'Hacer contactos',
    tagline: 'Que te recuerden después de treinta segundos.',
    jtbd:
        'Quiero presentarme en un evento y que después recuerden a qué me '
        'dedico.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.soon,
    sortOrder: 18,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000019',
    slug: 'redes-sociales',
    family: ThemeFamily.publico,
    name: 'Redes sociales',
    tagline: 'Un gancho que no es un cebo.',
    jtbd:
        'Quiero abrir una publicación con una frase que atrape y que el '
        'resto la sostenga.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.soon,
    sortOrder: 19,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000020',
    slug: 'docencia',
    family: ThemeFamily.publico,
    name: 'Enseñar',
    tagline: 'Lo difícil explicado como si fuera fácil.',
    jtbd:
        'Quiero explicar un tema que domino a quien parte de cero y que se '
        'quede con la idea.',
    contentType: ThemeContentType.mixed,
    status: ThemeStatus.soon,
    sortOrder: 20,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000021',
    slug: 'medios-entrevistas',
    family: ThemeFamily.publico,
    name: 'Hablar con medios',
    tagline: 'Responder lo que preguntan y decir lo tuyo.',
    jtbd:
        'Quiero contestar una pregunta incómoda en público sin esquivarla '
        'ni regalar un titular.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.soon,
    sortOrder: 21,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000022',
    slug: 'humor',
    family: ThemeFamily.social,
    name: 'Humor',
    tagline: 'Hacer reír sin que nadie pague el chiste.',
    jtbd:
        'Quiero contar algo con gracia y que la broma no caiga sobre '
        'alguien.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.soon,
    sortOrder: 22,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000023',
    slug: 'citas',
    family: ThemeFamily.social,
    name: 'Citas',
    tagline: 'Coquetear con palabras tuyas, no con frases hechas.',
    jtbd:
        'Quiero decir lo que me atrae de alguien sin recurrir a una frase '
        'prestada.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.soon,
    sortOrder: 23,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000024',
    slug: 'amistad',
    family: ThemeFamily.social,
    name: 'Amistad',
    tagline: 'Decir lo que sientes sin taparlo con una broma.',
    jtbd:
        'Quiero decirle a un amigo lo que significa para mí sin restarle '
        'importancia.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.soon,
    sortOrder: 24,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000025',
    slug: 'small-talk',
    family: ThemeFamily.social,
    name: 'Romper el hielo',
    tagline: 'Los primeros noventa segundos.',
    jtbd:
        'Quiero empezar una conversación con alguien que acabo de conocer '
        'y que no se apague en dos frases.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.soon,
    sortOrder: 25,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000026',
    slug: 'familia-crianza',
    family: ThemeFamily.social,
    name: 'Familia y crianza',
    tagline: 'Explicar sin sermonear.',
    jtbd:
        'Quiero explicar una decisión en casa sin que suene a sermón y sin '
        'ceder en el fondo.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.soon,
    sortOrder: 26,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000027',
    slug: 'empatia-escucha',
    family: ThemeFamily.emocion,
    name: 'Escuchar',
    tagline: 'Que se note que entendiste.',
    jtbd:
        'Quiero responder a quien me cuenta algo difícil y que sienta que '
        'lo escuché de verdad.',
    contentType: ThemeContentType.expressionDriven,
    status: ThemeStatus.soon,
    sortOrder: 27,
  ),
  Theme(
    id: 'c0000000-0000-4000-8000-000000000028',
    slug: 'pedir-disculparse',
    family: ThemeFamily.emocion,
    name: 'Pedir y disculparse',
    tagline: 'Pedir sin encogerte, disculparte sin excusas.',
    jtbd:
        'Quiero pedir lo que necesito y reconocer un fallo sin justificarme '
        'de más.',
    contentType: ThemeContentType.mixed,
    status: ThemeStatus.soon,
    sortOrder: 28,
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
  for (final theme in [...seedThemes, ...unpublishedSeedThemes])
    theme.slug: theme.id,
};

String _themeIdOf(String slug) =>
    _themeIdBySlug[slug] ?? (throw StateError('unknown theme slug: $slug'));
