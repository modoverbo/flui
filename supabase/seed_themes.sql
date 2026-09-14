-- flui local/dev theme seed. Applied by `supabase db reset` AFTER seed.sql
-- (see the `sql_paths` list in supabase/config.toml), because every row here
-- references a word that seed.sql inserts.
--
-- WHY THIS IS A SEPARATE FILE
-- ---------------------------
-- `supabase/seed.sql` is generated from `content/` by `dart run content:emit`,
-- and `app/tool/seed_fixture_check.dart` proves that generated file round-trips
-- into the Flutter fake-backend fixture byte for byte. The emitter
-- (`content/lib/src/sql/seed_emitter.dart`) writes a fixed preamble plus the
-- word rows; it emits neither `themes`, nor `word_themes`, nor
-- `words.semantic_set_id`, and the `Word` model in `content/` has no
-- `semantic_set_id` field at all. Teaching it to do so means editing
-- `content/`, which the content agents own. So the theme rows live here
-- instead, hand-written and applied after the generated seed, until the
-- emitter grows theme support. When it does, move these rows into
-- `content/templates/seed_preamble.sql` and delete this file.
--
-- Copy (slug, family, name, tagline, jtbd, content_type, sort_order) is copied
-- verbatim from content/themes.yml. Do not invent themes here.
--
-- Invariants covered by supabase/tests/database/070_themes.test.sql.

-- ============================================================================
-- 1. The 16 launch themes (content/themes.yml)
-- ============================================================================
--
-- `status` is the offer, not the taxonomy: a theme is 'live' once the seed has
-- at least one word tagged with it, and 'soon' while it has none. Shipping an
-- empty theme in the picker would be a promise the catalog cannot keep.

insert into public.themes
  (id, slug, family, name, tagline, jtbd, content_type, status, sort_order, published)
values
  ('c0000000-0000-4000-8000-000000000001', 'reuniones', 'trabajo', 'Reuniones',
   'Que se note que estabas ahí.',
   'Quiero intervenir en una reunión y que mi idea se entienda a la primera.',
   'word_driven', 'live', 1, true),
  ('c0000000-0000-4000-8000-000000000002', 'presentaciones-oratoria', 'publico', 'Presentaciones',
   'Hablar delante de gente sin sonar a guion.',
   'Quiero presentar mi trabajo y sonar seguro sin memorizar cada frase.',
   'mixed', 'live', 2, true),
  ('c0000000-0000-4000-8000-000000000003', 'entrevistas', 'trabajo', 'Entrevistas',
   'Contar lo que vales sin exagerar.',
   'Quiero responder en una entrevista con ejemplos concretos y palabras justas.',
   'mixed', 'live', 3, true),
  ('c0000000-0000-4000-8000-000000000004', 'negociacion', 'trabajo', 'Negociación',
   'Pedir claro y quedar bien.',
   'Quiero pedir un aumento o cerrar un trato sin sonar agresivo ni inseguro.',
   'mixed', 'live', 4, true),
  ('c0000000-0000-4000-8000-000000000005', 'liderazgo-feedback', 'trabajo', 'Liderazgo y feedback',
   'Decir lo que hay que decir sin romper nada.',
   'Quiero dar feedback a mi equipo de forma que se entienda y no duela.',
   'word_driven', 'live', 5, true),
  ('c0000000-0000-4000-8000-000000000006', 'conflicto-desacuerdo', 'emocion', 'Desacuerdos',
   'No estar de acuerdo sin convertirlo en pelea.',
   'Quiero discrepar en voz alta y que la conversación siga siendo posible.',
   'expression_driven', 'live', 6, true),
  ('c0000000-0000-4000-8000-000000000007', 'correos-mensajes', 'trabajo', 'Correos y mensajes',
   'Escribir corto y que no suene seco.',
   'Quiero escribir un correo breve que consiga respuesta y no parezca brusco.',
   'expression_driven', 'live', 7, true),
  ('c0000000-0000-4000-8000-000000000008', 'redaccion-ejecutiva', 'trabajo', 'Escribir para que te lean',
   'Menos palabras, más decisión.',
   'Quiero resumir un tema complejo en un párrafo que alguien ocupado entienda.',
   'word_driven', 'live', 8, true),
  ('c0000000-0000-4000-8000-000000000009', 'persuasion-storytelling', 'publico', 'Convencer y contar',
   'Una idea se recuerda cuando tiene forma de historia.',
   'Quiero contar lo que hice de modo que la otra persona lo recuerde mañana.',
   'mixed', 'live', 9, true),
  ('c0000000-0000-4000-8000-000000000010', 'conversaciones-dificiles', 'emocion', 'Conversaciones difíciles',
   'Abrir el tema que llevas semanas evitando.',
   'Quiero empezar una conversación incómoda sin que la otra persona se cierre.',
   'expression_driven', 'live', 10, true),
  ('c0000000-0000-4000-8000-000000000011', 'matices-precision', 'precision', 'Matices',
   'La diferencia entre parecido y exacto.',
   'Quiero decir exactamente lo que pienso, ni más fuerte ni más flojo.',
   'word_driven', 'live', 11, true),
  ('c0000000-0000-4000-8000-000000000012', 'conectores-estructura', 'precision', 'Conectores',
   'Las palabras que sostienen una idea larga.',
   'Quiero enlazar mis ideas para que se sigan sin perderse a la mitad.',
   'expression_driven', 'soon', 12, true),
  ('c0000000-0000-4000-8000-000000000013', 'paronimos', 'precision', 'Palabras que se parecen',
   'Dos palabras casi iguales, dos significados distintos.',
   'Quiero dejar de confundir pares que se parecen y suenan a descuido.',
   'word_driven', 'soon', 13, true),
  ('c0000000-0000-4000-8000-000000000014', 'elogio-reconocimiento', 'social', 'Reconocer a otros',
   'Un elogio preciso vale por diez genéricos.',
   'Quiero reconocer el trabajo de alguien de forma específica y creíble.',
   'word_driven', 'live', 14, true),
  ('c0000000-0000-4000-8000-000000000015', 'decir-que-no', 'emocion', 'Decir que no',
   'Negarte sin dar diez explicaciones.',
   'Quiero rechazar una petición y mantener la relación intacta.',
   'expression_driven', 'soon', 15, true),
  ('c0000000-0000-4000-8000-000000000016', 'conversacion-cotidiana', 'social', 'Conversación diaria',
   'Hablar del día a día con palabras que encajan.',
   'Quiero contar lo que me pasa sin repetir siempre cosa, tema y hacer.',
   'mixed', 'soon', 16, true)
on conflict (id) do update
  set slug = excluded.slug,
      family = excluded.family,
      name = excluded.name,
      tagline = excluded.tagline,
      jtbd = excluded.jtbd,
      content_type = excluded.content_type,
      status = excluded.status,
      sort_order = excluded.sort_order,
      published = excluded.published;

-- ============================================================================
-- 2. Semantic sets of the starter words
-- ============================================================================
--
-- A semantic set is a synonym, antonym or category-mate group, which is what
-- Tinkham (1993, 1997) and Nation (2000) found to interfere when learned
-- together. Only one such group exists among the eight starter words:
-- «contundente» (reinforce an assertion) and «matizar» (soften it) sit at the
-- two ends of the same axis, so they are never introduced within 7 days of
-- each other. The other six are thematically related at most, which the same
-- research found harmless, so their `semantic_set_id` stays NULL.

update public.words
   set semantic_set_id = 'fuerza-de-la-afirmacion'
 where slug in ('contundente', 'matizar');

-- ============================================================================
-- 3. Which themes each starter word belongs to
-- ============================================================================
--
-- relevance 3 = the word is the point of the theme, 2 = clearly useful,
-- 1 = adjacent. `sort_order` mirrors the catalog order, so a theme introduces
-- its words in the same sequence the global pool would.

insert into public.word_themes (word_id, theme_id, relevance, sort_order)
select w.id, t.id, v.relevance, w.sort_order
from (values
  -- perspicaz: an adjective you use to praise someone else's read of a room.
  ('perspicaz', 'elogio-reconocimiento', 3),
  ('perspicaz', 'reuniones', 2),
  ('perspicaz', 'matices-precision', 1),
  -- plantear: putting a subject on the table, at work or at home.
  ('plantear', 'reuniones', 3),
  ('plantear', 'conversaciones-dificiles', 2),
  ('plantear', 'correos-mensajes', 2),
  -- matizar: the word for "that is true, but".
  ('matizar', 'matices-precision', 3),
  ('matizar', 'conflicto-desacuerdo', 2),
  ('matizar', 'reuniones', 2),
  -- sopesar: weighing an offer before answering it.
  ('sopesar', 'negociacion', 3),
  ('sopesar', 'entrevistas', 2),
  ('sopesar', 'liderazgo-feedback', 1),
  -- pertinente: whether a question belongs in this conversation.
  ('pertinente', 'entrevistas', 3),
  ('pertinente', 'reuniones', 2),
  ('pertinente', 'redaccion-ejecutiva', 2),
  -- concretar: turning "we should" into a date, a number and an owner.
  ('concretar', 'reuniones', 3),
  ('concretar', 'redaccion-ejecutiva', 2),
  ('concretar', 'negociacion', 2),
  -- contundente: an argument that leaves no room for doubt.
  ('contundente', 'persuasion-storytelling', 3),
  ('contundente', 'presentaciones-oratoria', 2),
  ('contundente', 'negociacion', 2),
  -- zanjar: ending a discussion for good.
  ('zanjar', 'conflicto-desacuerdo', 3),
  ('zanjar', 'negociacion', 2),
  ('zanjar', 'reuniones', 1)
) as v (word_slug, theme_slug, relevance)
join public.words w on w.slug = v.word_slug
join public.themes t on t.slug = v.theme_slug
on conflict (word_id, theme_id) do update
  set relevance = excluded.relevance,
      sort_order = excluded.sort_order;
