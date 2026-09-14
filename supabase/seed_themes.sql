-- flui local/dev theme catalogue. Applied by `supabase db reset` BEFORE seed.sql
-- (see the `sql_paths` list in supabase/config.toml), because the generated
-- seed links words to the themes this file inserts.
--
-- WHAT LIVES HERE
-- ---------------
-- Only the 16 theme rows. `supabase/seed.sql` is generated from `content/` by
-- `dart run content:emit`, and that generator owns `words.semantic_set_id` and
-- every `word_themes` link, resolved by slug against the themes below. Keep the
-- two files disjoint: a link or a semantic set added here would be overwritten
-- on the next emit.
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
