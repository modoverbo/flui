-- flui local/dev seed. Applied by `supabase db reset` (never pushed to production by `db push`).
--
-- Contents:
--   1. subscription_plans: the two Whop plans. PLACEHOLDER PRICES (USD cents) to be
--      confirmed by the founder. whop_plan_id values point to the Whop SANDBOX
--      product; production needs its own plans and an UPDATE of whop_plan_id
--      (see docs/deployment.md).
--   2. Eight original starter words (Spanish product content) that follow the
--      selection criteria and content guidelines in docs/learning-method.md.
--      Definitions are written in-house (no RAE text). AI-assisted drafts: they
--      require human linguistic review before production use.
--
-- Invariants covered by supabase/tests/database/060_seed_content.test.sql.
-- Each exercise and its options are inserted in ONE statement so the deferred
-- "exactly 3 options, exactly 1 correct" constraint trigger passes even in
-- autocommit mode.

-- ============================================================================
-- 1. Subscription plans (founder-confirmed prices; Whop sandbox plan ids)
-- ============================================================================

insert into public.subscription_plans
  (id, whop_plan_id, billing_period_days, price_cents, currency, label, savings_label, sort_order, active)
values
  ('monthly', 'plan_rtRdHbN0gLgBh', 30, 699, 'USD', 'Mensual', null, 1, true),     -- founder-confirmed price
  ('quarterly', 'plan_xr6Skp0dSxxcz', 90, 1615, 'USD', 'Trimestral', 'Ahorra 23%', 2, true) -- founder-confirmed price
on conflict (id) do update
  set whop_plan_id = excluded.whop_plan_id,
      billing_period_days = excluded.billing_period_days,
      price_cents = excluded.price_cents,
      currency = excluded.currency,
      label = excluded.label,
      savings_label = excluded.savings_label,
      sort_order = excluded.sort_order,
      active = excluded.active;

-- ============================================================================
-- 2. Starter words
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. perspicaz
-- ----------------------------------------------------------------------------

insert into public.words
  (id, slug, lemma, part_of_speech, syllables, stressed_syllable, ipa_latam, ipa_es, explanation,
   example_sentence, register, pedantry_risk, usage_tip, when_not_to_use, collocations, replaces, family,
   semantic_set_id, sort_order, published)
values (
  'a0000000-0000-4000-8000-000000000001',
  'perspicaz',
  'perspicaz',
  'adjetivo',
  array['pers', 'pi', 'caz']::text[],
  3,
  '[pers.piˈkas]',
  '[pers.piˈkaθ]',
  'Que se da cuenta rápido de lo que no es obvio: capta detalles, intenciones o problemas que otros no ven.',
  'Qué observación tan perspicaz: nadie más había notado que el cliente no mencionó el precio.',
  'neutral',
  1,
  'Suena natural como elogio a otra persona o a una idea. Para describirte a ti, «soy muy perspicaz» suena a presumir.',
  'No la uses para decir que alguien desconfía (eso es «suspicaz») ni para decir que algo se entiende bien (eso es «claro» o «perspicuo»).',
  array['observación perspicaz', 'pregunta perspicaz', 'mirada perspicaz', 'ser perspicaz para los negocios']::text[],
  '[{"before": "Es muy listo, se da cuenta de todo", "after": "Es muy perspicaz"}, {"before": "¡Qué buena pregunta, qué lista!", "after": "Qué pregunta tan perspicaz"}, {"before": "Tiene buen ojo para los problemas", "after": "Es perspicaz para detectar problemas"}]'::jsonb,
  array['perspicacia', 'perspicazmente']::text[],
  null,
  1,
  true
);

insert into public.word_confusions (word_id, confused_with, difference, memory_trick)
values
  ('a0000000-0000-4000-8000-000000000001', 'suspicaz', '«Suspicaz» describe a quien tiende a desconfiar y sospechar de los demás. «Perspicaz» describe a quien capta lo que no es evidente.', 'El suspicaz sospecha; el perspicaz descubre.'),
  ('a0000000-0000-4000-8000-000000000001', 'perspicuo', '«Perspicuo» se dice de lo que se entiende con claridad, como un texto o una explicación. Comparte raíz con «perspicaz», pero no describe a quien observa.', 'El perspicaz ve; lo perspicuo se ve.');

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000011',
    'a0000000-0000-4000-8000-000000000001',
    'Andrés confía plenamente en su equipo, pero es tan {{blank}} que detectó en dos minutos el error de las cifras que nadie había visto.',
    'La palabra describe a alguien que capta rápido lo que no es evidente.',
    'Perspicaz: que se da cuenta rápido de lo que no es obvio. «Suspicaz» se parece, pero es quien desconfía. «Perspicuo» comparte raíz, pero describe lo que se entiende fácilmente. El perspicaz ve; lo perspicuo se ve.',
    1
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('suspicaz', false, 'paronym', '«Suspicaz» es quien sospecha de los demás, y Andrés confía en su equipo.', 'Fíjate en el inicio: Andrés confía en su equipo. ¿Encaja alguien que sospecha de todos?', 1),
    ('perspicaz', true, null, null, null, 2),
    ('perspicuo', false, 'paronym', '«Perspicuo» se dice de lo que se entiende con claridad, como una explicación. Andrés no explica: descubre.', '«Perspicuo» describe algo fácil de entender, como un texto. ¿Andrés es fácil de entender o descubre algo?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000012',
    'a0000000-0000-4000-8000-000000000001',
    'Tomás notó que su hermana cambiaba de tema cada vez que alguien mencionaba la mudanza. Fue muy {{blank}}: sin que nadie le dijera nada, entendió que algo le preocupaba.',
    'Busca la palabra para alguien que entiende lo que pasa sin que se lo digan.',
    'Perspicaz: Tomás captó una señal que nadie le explicó. «Locuaz» describe a quien habla mucho y «tenaz» a quien no se rinde; ninguna de las dos habla de darse cuenta.',
    2
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('perspicaz', true, null, null, null, 1),
    ('locuaz', false, 'paronym', '«Locuaz» es quien habla mucho y con facilidad. Aquí lo importante es que Tomás se dio cuenta de algo, no cuánto habló.', '«Locuaz» tiene que ver con hablar mucho. ¿La frase cuenta cuánto habla Tomás?', 2),
    ('tenaz', false, 'paronym', '«Tenaz» es quien no se rinde. Tomás no insistió en nada: captó una señal que otros no vieron.', '«Tenaz» describe a quien persiste. Relee: ¿Tomás insiste o se da cuenta?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000013',
    'a0000000-0000-4000-8000-000000000001',
    'Camila no desconfía de nadie, pero es muy {{blank}}: en la primera reunión intuyó que el plazo del proveedor era imposible, y acertó.',
    'La frase elogia a Camila por notar un problema antes que los demás.',
    'Perspicaz: Camila captó a tiempo lo que no era evidente. «Suspicaz» no encaja porque no desconfía de nadie, y «fisgona» es un reproche coloquial para quien curiosea, no un elogio.',
    3
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('fisgona', false, 'register', '«Fisgona» es coloquial y describe a quien curiosea en asuntos ajenos; es una crítica, y aquí se elogia su intuición.', '«Fisgona» es un reproche por meterse en lo ajeno. ¿La frase critica o elogia a Camila?', 1),
    ('suspicaz', false, 'paronym', '«Suspicaz» describe a quien desconfía, y la frase dice que Camila no desconfía de nadie.', 'Relee el inicio: Camila no desconfía de nadie. ¿Encaja una palabra que significa desconfiar?', 2),
    ('perspicaz', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

insert into public.readings (word_id, scene, conversation_type, title, body, before_phrase, after_phrase, position)
values
  ('a0000000-0000-4000-8000-000000000001', 'trabajo', 'practica', 'La pregunta que nadie hizo',
   'Mientras todos discutían el calendario, Carla preguntó: «¿Y quién aprueba los cambios si el cliente no responde?». Silencio. Nadie lo había pensado. El director sonrió: «Muy perspicaz, Carla. Eso nos habría retrasado un mes».',
   '¡Qué buena pregunta, qué lista!', 'Qué pregunta tan perspicaz.', 1),
  ('a0000000-0000-4000-8000-000000000001', 'social', 'emocional', 'Un café con Marta',
   'Sofía escuchaba a Marta hablar de su nuevo trabajo con entusiasmo, pero notó que nunca mencionaba a su jefe. «Oye, ¿todo bien con él?». Marta suspiró: «Eres muy perspicaz… la verdad, no».',
   'Te das cuenta de todo.', 'Eres muy perspicaz.', 2),
  ('a0000000-0000-4000-8000-000000000001', 'entrevista', 'social', 'La última pregunta',
   'Al final de la entrevista, Diego preguntó cómo medían el éxito en los primeros tres meses. La entrevistadora anotó algo y dijo: «Es una pregunta perspicaz; casi nadie la hace». Diego no tuvo que decir que era observador: se notó.',
   'Buena pregunta, ¿no?', 'Es una pregunta perspicaz.', 3);

-- ----------------------------------------------------------------------------
-- 2. plantear
-- ----------------------------------------------------------------------------

insert into public.words
  (id, slug, lemma, part_of_speech, syllables, stressed_syllable, ipa_latam, ipa_es, explanation,
   example_sentence, register, pedantry_risk, usage_tip, when_not_to_use, collocations, replaces, family,
   semantic_set_id, sort_order, published)
values (
  'a0000000-0000-4000-8000-000000000002',
  'plantear',
  'plantear',
  'verbo',
  array['plan', 'te', 'ar']::text[],
  3,
  '[plan.teˈar]',
  '[plan.teˈar]',
  'Poner sobre la mesa un tema, una duda o una propuesta para hablarlo con otros.',
  'En la reunión de mañana voy a plantear la posibilidad de trabajar desde casa los viernes.',
  'neutral',
  1,
  'Abre conversaciones delicadas con respeto: «Quiero plantearte algo» suena directo y amable a la vez.',
  'No la confundas con «plantar» (sembrar o dejar a alguien esperando) ni la uses para imponer una decisión: eso es «implantar».',
  array['plantear un tema', 'plantear una duda', 'plantear una propuesta', 'plantear un problema']::text[],
  '[{"before": "Quiero sacar un tema", "after": "Quiero plantear un tema"}, {"before": "Le dije lo de cambiar el horario", "after": "Le planteé cambiar el horario"}, {"before": "Esto trae un problema", "after": "Esto plantea un problema"}]'::jsonb,
  array['planteamiento', 'replantear']::text[],
  null,
  2,
  true
);

insert into public.word_confusions (word_id, confused_with, difference, memory_trick)
values
  ('a0000000-0000-4000-8000-000000000002', 'plantar', '«Plantar» es poner algo en la tierra o, en lenguaje coloquial, dejar a alguien esperando. «Plantear» es proponer un tema para hablarlo.', 'Plantas una semilla; planteas una idea.'),
  ('a0000000-0000-4000-8000-000000000002', 'implantar', '«Implantar» es establecer algo, a menudo sin consultarlo. «Plantear» abre la conversación antes de decidir.', 'Plantear pregunta; implantar impone.');

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000021',
    'a0000000-0000-4000-8000-000000000002',
    'Antes de firmar el contrato, Valeria le {{blank}} a su jefa una duda sobre las vacaciones, y juntas encontraron una solución.',
    'Busca el verbo para poner una duda sobre la mesa y hablarla con otra persona.',
    'Planteó: puso su duda sobre la mesa para hablarla. «Plantó» es sembrar o dejar a alguien esperando, e «implantó» sería imponer algo; aquí la duda se conversa y se resuelve entre las dos.',
    1
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('plantó', false, 'paronym', '«Plantar» es sembrar o dejar a alguien esperando. Valeria no dejó plantada a su jefa: le habló de su duda.', '«Plantar» se usa con semillas o con quien no llega a una cita. ¿Eso pasó aquí?', 1),
    ('implantó', false, 'paronym', '«Implantar» es imponer o establecer algo. Valeria no impuso nada: abrió una conversación y la resolvieron juntas.', '«Implantar» es establecer algo, casi siempre desde arriba. ¿Valeria impone o propone?', 2),
    ('planteó', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000022',
    'a0000000-0000-4000-8000-000000000002',
    'En el correo al comité, Raúl {{blank}} tres alternativas para reducir gastos y pidió que votaran la mejor.',
    'Busca el verbo que presenta opciones para que otros decidan.',
    'Planteó: presentó las alternativas para que el comité decidiera. «Soltó» es demasiado coloquial y suena improvisado para un correo formal, e «implantó» significaría imponerlas sin votación.',
    2
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('planteó', true, null, null, null, 1),
    ('soltó', false, 'register', '«Soltar» es coloquial y sugiere decir algo de golpe, sin pensarlo. Un correo al comité con tres alternativas es justo lo contrario.', '«Soltar» es decir algo de repente y en tono informal. ¿Así se escribe un correo al comité?', 2),
    ('implantó', false, 'paronym', '«Implantar» es establecer algo sin consultar. Raúl pide que voten: no impone nada.', 'Fíjate en el final: Raúl pide que voten. ¿Quien implanta algo pide opinión?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000023',
    'a0000000-0000-4000-8000-000000000002',
    'Si algo del plan no te convence, lo mejor es {{blank}} con calma en la reunión en vez de quejarte después por los pasillos.',
    'Busca el verbo para sacar un tema y hablarlo abiertamente con el grupo.',
    'Plantearlo: ponerlo sobre la mesa para hablarlo. «Plantarlo» es sembrar o dejar a alguien esperando, y «reclamarlo» es exigir algo que te corresponde, no conversar sobre una duda.',
    3
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('reclamarlo', false, 'near_synonym', '«Reclamar» es exigir algo que crees que te corresponde. Lo que no te convence no se exige: se pone sobre la mesa para hablarlo.', '«Reclamar» es pedir algo que te deben. ¿Quieres exigir lo que no te convence o conversarlo?', 1),
    ('plantearlo', true, null, null, null, 2),
    ('plantarlo', false, 'paronym', '«Plantar» es sembrar o dejar a alguien esperando. Un punto del plan no se planta: se comenta.', '«Plantar» va con semillas o con citas a las que no se llega. ¿Encaja con una duda sobre un plan?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

insert into public.readings (word_id, scene, conversation_type, title, body, before_phrase, after_phrase, position)
values
  ('a0000000-0000-4000-8000-000000000002', 'trabajo', 'practica', 'Los viernes en casa',
   'Ana llevaba semanas pensando que los viernes rendía más en casa. En la reunión mensual respiró hondo y dijo: «Quiero plantear algo: probar un mes con los viernes en remoto y medir los resultados». Su jefe asintió: «Me parece razonable; hagamos la prueba».',
   'Quería sacar el tema de los viernes.', 'Quiero plantear algo sobre los viernes.', 1),
  ('a0000000-0000-4000-8000-000000000002', 'familia', 'emocional', 'Una conversación pendiente',
   'Gabriel no sabía cómo decirle a su padre que ya no podía llevarlo al médico todos los martes. Esperó a que estuvieran tranquilos y le dijo: «Papá, quiero plantearte algo y me importa lo que pienses». Hablaron una hora y acordaron turnarse con su tía.',
   'Papá, te tengo que decir una cosa.', 'Papá, quiero plantearte algo.', 2),
  ('a0000000-0000-4000-8000-000000000002', 'social', 'social', 'El viaje del grupo',
   'En el chat de amigos todos opinaban a la vez sobre el viaje. Paula escribió: «Planteo dos opciones: playa en julio o montaña en septiembre. Votamos hasta el viernes». En media hora, el caos se convirtió en una decisión.',
   'Bueno, ¿qué hacemos al final?', 'Planteo dos opciones.', 3);

-- ----------------------------------------------------------------------------
-- 3. matizar
-- ----------------------------------------------------------------------------

insert into public.words
  (id, slug, lemma, part_of_speech, syllables, stressed_syllable, ipa_latam, ipa_es, explanation,
   example_sentence, register, pedantry_risk, usage_tip, when_not_to_use, collocations, replaces, family,
   semantic_set_id, sort_order, published)
values (
  'a0000000-0000-4000-8000-000000000003',
  'matizar',
  'matizar',
  'verbo',
  array['ma', 'ti', 'zar']::text[],
  3,
  '[ma.tiˈsar]',
  '[ma.tiˈθar]',
  'Precisar o suavizar algo que se dijo, añadiendo detalles o excepciones para que sea más justo.',
  'Estoy de acuerdo con la propuesta, pero quiero matizar un punto sobre los plazos.',
  'neutral',
  1,
  'Sirve para no estar ni del todo a favor ni del todo en contra: «Lo matizaría» abre espacio sin confrontar.',
  'No la uses para esconder un error o hacer que algo parezca mejor de lo que es: eso es «maquillar».',
  array['matizar una afirmación', 'matizar lo dicho', 'matizar una crítica', 'conviene matizar']::text[],
  '[{"before": "Sí, pero no es tan así", "after": "Sí, aunque conviene matizarlo"}, {"before": "Bueno, depende, o sea, no siempre", "after": "Lo matizo: no pasa siempre"}, {"before": "Aclarar un poquito lo que dije", "after": "Matizar lo que dije"}]'::jsonb,
  array['matiz', 'matización']::text[],
  null,
  3,
  true
);

insert into public.word_confusions (word_id, confused_with, difference, memory_trick)
values
  ('a0000000-0000-4000-8000-000000000003', 'atizar', '«Atizar» es avivar el fuego o, en sentido figurado, empeorar un conflicto. «Matizar» busca precisión y suele calmar la conversación.', 'Matizas para precisar; atizas para encender.'),
  ('a0000000-0000-4000-8000-000000000003', 'maquillar', '«Maquillar» es disimular algo para que parezca mejor. «Matizar» añade detalles verdaderos que hacen la idea más justa.', 'Matizar aclara; maquillar tapa.');

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000031',
    'a0000000-0000-4000-8000-000000000003',
    'Inés dijo que el proyecto había sido un fracaso, pero enseguida lo quiso {{blank}}: «Fallamos en los plazos, aunque el cliente quedó contento con el resultado».',
    'Inés añade un detalle verdadero que hace su opinión más justa.',
    'Matizar: Inés precisa su opinión con un dato que la hace más justa. «Atizar» sería avivar un conflicto, y «maquillar» sería esconder el fallo, pero ella lo reconoce.',
    1
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('atizar', false, 'paronym', '«Atizar» es avivar un fuego o un conflicto. Inés no enciende nada: suaviza lo que dijo con un dato.', '«Atizar» se usa con el fuego o con las peleas. ¿Inés empeora la situación o la precisa?', 1),
    ('matizar', true, null, null, null, 2),
    ('maquillar', false, 'near_synonym', '«Maquillar» es disimular algo para que parezca mejor. Inés reconoce el fallo en los plazos: no esconde nada.', 'Quien maquilla un resultado oculta lo malo. ¿Inés oculta el problema de los plazos?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000032',
    'a0000000-0000-4000-8000-000000000003',
    'Cuando su amiga dijo que en esa ciudad nadie es amable, Mateo prefirió {{blank}}: «A mí me costó al principio, pero conocí gente muy acogedora».',
    'Mateo no dice que su amiga se equivoque del todo: le da parte de razón y añade un detalle.',
    'Matizar: Mateo reconoce parte de lo que dice su amiga y añade un detalle. «Rebatir» sería contradecirla por completo, y «atizar» sería avivar la discusión, justo lo contrario de su tono.',
    2
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('rebatir', false, 'near_synonym', '«Rebatir» es contradecir por completo. Mateo le da parte de razón («me costó al principio») y solo añade un matiz.', '«Rebatir» es contradecir del todo. ¿Mateo le quita toda la razón a su amiga?', 1),
    ('atizar', false, 'paronym', '«Atizar» sería echar leña a la discusión. Mateo responde con calma y con su propia experiencia.', '«Atizar» es avivar una discusión. ¿La respuesta de Mateo busca pelea?', 2),
    ('matizar', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000033',
    'a0000000-0000-4000-8000-000000000003',
    'Mi hermana me pidió que {{blank}} mi crítica a su novio: «Di que no te gusta cómo habla de su ex, no que es mala persona».',
    'Tu hermana acepta la crítica, pero quiere que sea más precisa y más justa.',
    'Matizara: tu hermana pide precisar la crítica para que sea justa. «Maquillara» sería disimularla, y «retirara» sería dejar de decirla, pero ella acepta una parte.',
    3
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('matizara', true, null, null, null, 1),
    ('maquillara', false, 'near_synonym', '«Maquillar» una crítica es disfrazarla para que no se note. Tu hermana no pide ocultarla: pide que sea más precisa.', 'Quien maquilla algo lo disimula. ¿Tu hermana te pide que disimules o que precises?', 2),
    ('retirara', false, 'near_synonym', '«Retirar» una crítica es no decirla más. Tu hermana acepta que la hagas, pero con un límite claro.', 'Fíjate: tu hermana acepta una parte de la crítica. ¿Te pide que la quites entera?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

insert into public.readings (word_id, scene, conversation_type, title, body, before_phrase, after_phrase, position)
values
  ('a0000000-0000-4000-8000-000000000003', 'trabajo', 'practica', 'El dato que faltaba',
   'En la presentación, Tomás dijo que las ventas habían caído. Su compañera levantó la mano: «Quiero matizar eso: cayeron en tienda, pero en internet crecieron un 20 %». La conversación cambió por completo: ya no hablaban de un problema, sino de dónde invertir.',
   'Sí, pero no es tan así.', 'Quiero matizar eso.', 1),
  ('a0000000-0000-4000-8000-000000000003', 'social', 'social', 'Sobremesa',
   'Durante la sobremesa, alguien dijo que las redes sociales solo sirven para perder el tiempo. Lucía sonrió: «Lo matizaría: a mí me sirvieron para encontrar trabajo, aunque también pierdo horas ahí». Nadie se sintió atacado y la charla siguió con buen ambiente.',
   'Bueno, depende, o sea, no siempre.', 'Lo matizaría.', 2),
  ('a0000000-0000-4000-8000-000000000003', 'familia', 'emocional', 'Lo que quise decir',
   'Después de discutir, Raúl le escribió a su madre: «Ayer dije que nunca me escuchas. Quiero matizarlo: a veces siento que no me escuchas cuando hablo de mi trabajo». Su madre respondió con un corazón y, al rato, con una llamada.',
   'Perdón, no era tan así lo que dije.', 'Quiero matizar lo que dije.', 3);

-- ----------------------------------------------------------------------------
-- 4. sopesar
-- ----------------------------------------------------------------------------

insert into public.words
  (id, slug, lemma, part_of_speech, syllables, stressed_syllable, ipa_latam, ipa_es, explanation,
   example_sentence, register, pedantry_risk, usage_tip, when_not_to_use, collocations, replaces, family,
   semantic_set_id, sort_order, published)
values (
  'a0000000-0000-4000-8000-000000000004',
  'sopesar',
  'sopesar',
  'verbo',
  array['so', 'pe', 'sar']::text[],
  3,
  '[so.peˈsar]',
  '[so.peˈsar]',
  'Pensar con calma las ventajas y desventajas de algo antes de decidir.',
  'Antes de aceptar la oferta, quiero sopesar si el sueldo compensa las horas de viaje.',
  'neutral',
  1,
  'Transmite que tu decisión es pensada, no impulsiva: «Déjame sopesarlo» suena mejor que «lo pienso y te digo».',
  'No la uses para decir que algo supera un límite (eso es «sobrepasar») ni como excusa elegante para no decidir nunca.',
  array['sopesar las opciones', 'sopesar los pros y los contras', 'sopesar una decisión', 'sopesar los riesgos']::text[],
  '[{"before": "Lo voy a pensar bien", "after": "Voy a sopesarlo"}, {"before": "Ver lo bueno y lo malo", "after": "Sopesar los pros y los contras"}, {"before": "Pensar qué me conviene más", "after": "Sopesar las opciones"}]'::jsonb,
  array['peso', 'pesar']::text[],
  null,
  4,
  true
);

insert into public.word_confusions (word_id, confused_with, difference, memory_trick)
values
  ('a0000000-0000-4000-8000-000000000004', 'sobrepasar', '«Sobrepasar» es superar un límite o una cantidad. «Sopesar» es valorar con cuidado antes de decidir.', 'Sopesas antes de decidir; sobrepasas un límite.'),
  ('a0000000-0000-4000-8000-000000000004', 'posponer', '«Posponer» es dejar una decisión para más tarde. «Sopesar» es pensarla ahora, con cuidado.', 'Quien sopesa decide mejor; quien pospone decide después.');

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000041',
    'a0000000-0000-4000-8000-000000000004',
    'Camila tiene dos ofertas de trabajo; antes de responder, quiere {{blank}} el sueldo, el horario y la distancia de cada una.',
    'Busca el verbo para comparar con calma lo bueno y lo malo de cada opción.',
    'Sopesar: comparar con calma cada factor antes de decidir. «Sobrepasar» es superar un límite, y «posponer» es aplazar una decisión, no analizar el sueldo o la distancia.',
    1
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('sopesar', true, null, null, null, 1),
    ('sobrepasar', false, 'paronym', '«Sobrepasar» es superar un límite. Camila no quiere superar el sueldo ni la distancia: quiere compararlos.', '«Sobrepasar» es ir más allá de un límite. ¿Camila quiere superar algo o comparar?', 2),
    ('posponer', false, 'near_synonym', '«Posponer» es dejar una decisión para más tarde. La frase dice que Camila quiere analizar cada oferta antes de responder.', '«Posponer» es aplazar. ¿Se puede aplazar un sueldo o una distancia?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000042',
    'a0000000-0000-4000-8000-000000000004',
    'Mis padres {{blank}} durante semanas si vender la casa de la playa: les daba pena, pero mantenerla les costaba demasiado.',
    'Tus padres comparan dos cosas: lo que sienten por la casa y lo que les cuesta.',
    'Sopesaron: pusieron en la balanza la pena y el gasto antes de decidir. «Sobrepasaron» significa superar un límite, y «despacharon» sería resolverlo deprisa, no durante semanas.',
    2
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('despacharon', false, 'near_synonym', '«Despachar» un asunto es resolverlo rápido y sin más vueltas. Tus padres tardaron semanas en decidir.', '«Despachar» es resolver algo deprisa. ¿Encaja con «durante semanas»?', 1),
    ('sopesaron', true, null, null, null, 2),
    ('sobrepasaron', false, 'paronym', '«Sobrepasar» es superar un límite. Tus padres no superaron nada: comparaban la pena con el gasto.', '«Sobrepasar» es ir más allá de un límite. ¿Qué límite superaron tus padres?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000043',
    'a0000000-0000-4000-8000-000000000004',
    'Antes de reservar el viaje con sus amigos, Diego se tomó un día para {{blank}} los gastos frente a lo que tenía ahorrado.',
    'Diego pone en la balanza dos cosas antes de decidir: lo que costará y lo que tiene.',
    'Sopesar: comparar los gastos con lo ahorrado antes de decidir. «Sobrepasar» es superar un límite, y «saldar» es terminar de pagar una deuda, algo que Diego aún no está haciendo.',
    3
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('saldar', false, 'near_synonym', '«Saldar» es pagar por completo una deuda o una cuenta. Diego todavía no paga nada: compara los gastos con sus ahorros.', '«Saldar» es terminar de pagar. ¿Diego ya está pagando o todavía está comparando?', 1),
    ('sobrepasar', false, 'paronym', '«Sobrepasar» es superar un límite. Diego justo quiere evitar pasarse: por eso compara.', '«Sobrepasar» es ir más allá de un límite. ¿La frase habla de pasarse o de comparar?', 2),
    ('sopesar', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

insert into public.readings (word_id, scene, conversation_type, title, body, before_phrase, after_phrase, position)
values
  ('a0000000-0000-4000-8000-000000000004', 'trabajo', 'practica', 'La oferta',
   'A Elena le ofrecieron dirigir un equipo en otra ciudad. En lugar de responder en el momento, dijo: «Me entusiasma mucho. Déjame sopesarlo hasta el lunes: quiero hablarlo en casa». Su directora valoró la respuesta: demostraba que se tomaba la decisión en serio.',
   'Lo pienso y te digo.', 'Déjame sopesarlo hasta el lunes.', 1),
  ('a0000000-0000-4000-8000-000000000004', 'familia', 'emocional', '¿Nos mudamos?',
   'Carlos y Andrea llevaban meses dudando si mudarse cerca de los abuelos. Una noche hicieron dos columnas en un papel. «Vamos a sopesarlo en serio», dijo ella. Al terminar, la lista de ventajas era más larga, y por primera vez se sintieron tranquilos con la decisión.',
   'Vamos a pensarlo bien.', 'Vamos a sopesarlo en serio.', 2),
  ('a0000000-0000-4000-8000-000000000004', 'entrevista', 'practica', 'La pregunta difícil',
   'La entrevistadora le preguntó a Andrés por qué había dejado su empleo anterior. Él respondió: «Sopesé la estabilidad que tenía frente a la posibilidad de aprender algo nuevo, y elegí crecer». La respuesta sonó madura y honesta.',
   'Pues lo pensé y ya, me fui.', 'Sopesé la estabilidad frente a la posibilidad de crecer.', 3);

-- ----------------------------------------------------------------------------
-- 5. pertinente
-- ----------------------------------------------------------------------------

insert into public.words
  (id, slug, lemma, part_of_speech, syllables, stressed_syllable, ipa_latam, ipa_es, explanation,
   example_sentence, register, pedantry_risk, usage_tip, when_not_to_use, collocations, replaces, family,
   semantic_set_id, sort_order, published)
values (
  'a0000000-0000-4000-8000-000000000005',
  'pertinente',
  'pertinente',
  'adjetivo',
  array['per', 'ti', 'nen', 'te']::text[],
  3,
  '[per.tiˈnen.te]',
  '[per.tiˈnen.te]',
  'Que viene al caso: tiene relación directa con el tema o es oportuno en ese momento.',
  'Tu comentario es muy pertinente: justo estábamos hablando de ese riesgo.',
  'culto',
  2,
  'Valora un aporte sin exagerar: «Es un punto pertinente» reconoce la idea con elegancia. En una charla muy informal puede sonar formal.',
  'No la confundas con «pertinaz» (terco, que persiste) ni con «impertinente», que hoy significa sobre todo «insolente».',
  array['pregunta pertinente', 'comentario pertinente', 'datos pertinentes', 'en el momento pertinente']::text[],
  '[{"before": "Eso viene al caso", "after": "Eso es pertinente"}, {"before": "Esa pregunta tiene mucho que ver con esto", "after": "Es una pregunta pertinente"}, {"before": "No sé si es el momento de decirlo", "after": "No sé si es pertinente decirlo ahora"}]'::jsonb,
  array['pertinencia', 'pertinentemente']::text[],
  null,
  5,
  true
);

insert into public.word_confusions (word_id, confused_with, difference, memory_trick)
values
  ('a0000000-0000-4000-8000-000000000005', 'pertinaz', '«Pertinaz» describe algo que persiste o a alguien terco: una tos pertinaz, una lluvia pertinaz. «Pertinente» es lo que viene al caso.', 'Lo pertinente viene al caso; lo pertinaz no se va.'),
  ('a0000000-0000-4000-8000-000000000005', 'impertinente', '«Impertinente» se usa sobre todo para lo insolente o molesto. No funciona como simple contrario de «pertinente».', 'Una pregunta pertinente ayuda; una impertinente incomoda.');

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000051',
    'a0000000-0000-4000-8000-000000000005',
    'En la reunión sobre el presupuesto, Julián preguntó cuánto costaría el mantenimiento; era una pregunta muy {{blank}}, porque nadie lo había calculado.',
    'La pregunta de Julián tenía todo que ver con el tema de la reunión.',
    'Pertinente: la pregunta venía al caso y cubría un gasto olvidado. «Pertinaz» describe lo que persiste o a alguien terco, e «impertinente» es lo que molesta; ninguna describe una pregunta útil.',
    1
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('pertinaz', false, 'paronym', '«Pertinaz» describe lo que persiste o a alguien terco. Julián hizo una sola pregunta, y venía al caso.', '«Pertinaz» se dice de algo que no se va, como una tos. ¿La frase habla de insistencia?', 1),
    ('pertinente', true, null, null, null, 2),
    ('impertinente', false, 'paronym', '«Impertinente» es lo insolente o molesto. La pregunta de Julián ayudó: cubría algo que nadie había calculado.', 'Una pregunta impertinente incomoda. ¿La de Julián molestó o ayudó con el presupuesto?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000052',
    'a0000000-0000-4000-8000-000000000005',
    'Valeria revisó su currículum y dejó solo la experiencia {{blank}} para el puesto de ventas: quitó los trabajos de diseño, aunque eran del año pasado.',
    'Valeria se queda con lo que tiene relación directa con el puesto de ventas.',
    'Pertinente: Valeria dejó la experiencia relacionada con ventas. «Reciente» no encaja porque quitó trabajos del año pasado, y «pertinaz» describe algo que persiste, no algo que viene al caso.',
    2
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('reciente', false, 'near_synonym', '«Reciente» habla de tiempo. Valeria quitó trabajos del año pasado, así que no eligió por fecha, sino por relación con ventas.', 'Fíjate en el final: quitó trabajos del año pasado. ¿Eligió por fecha o por relación con el puesto?', 1),
    ('pertinaz', false, 'paronym', '«Pertinaz» es lo que persiste o quien es terco. La experiencia no insiste en nada: se elige por su relación con el puesto.', '«Pertinaz» se usa para algo obstinado, como una lluvia que no para. ¿Encaja con «experiencia»?', 2),
    ('pertinente', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000053',
    'a0000000-0000-4000-8000-000000000005',
    'Tu comentario sobre el tráfico fue muy {{blank}}: justo estábamos decidiendo a qué hora salir hacia la boda de tu primo.',
    'El comentario tenía relación directa con lo que se estaba decidiendo.',
    'Pertinente: el comentario venía justo al caso de la decisión. «Oportunista» critica a quien busca su propio beneficio, e «impertinente» describe lo que molesta; aquí el comentario solo ayudó.',
    3
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('pertinente', true, null, null, null, 1),
    ('oportunista', false, 'near_synonym', '«Oportunista» describe a quien aprovecha una situación en beneficio propio. Tu comentario no buscaba ventaja: ayudaba a decidir.', 'Ojo: «oportunista» es una crítica, no un elogio. ¿Tu comentario buscaba sacar provecho?', 2),
    ('impertinente', false, 'paronym', '«Impertinente» es lo que molesta o falta al respeto. Hablar del tráfico justo cuando se decide la hora ayuda.', 'Lo impertinente incomoda. ¿Hablar del tráfico en ese momento incomodaba o ayudaba?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

insert into public.readings (word_id, scene, conversation_type, title, body, before_phrase, after_phrase, position)
values
  ('a0000000-0000-4000-8000-000000000005', 'trabajo', 'practica', 'El punto clave',
   'El equipo llevaba una hora discutiendo colores para la campaña. Inés intervino: «Antes de elegir el diseño, ¿no sería pertinente revisar qué funcionó el año pasado?». La directora cerró la discusión: «Muy pertinente. Traigamos esos datos el jueves».',
   '¿Eso no tendría que ver con lo del año pasado?', '¿No sería pertinente revisar el año pasado?', 1),
  ('a0000000-0000-4000-8000-000000000005', 'entrevista', 'social', 'Preguntas al final',
   'Cuando le ofrecieron hacer preguntas, Gabriel no preguntó por las vacaciones. Dijo: «¿Qué retos tendrá esta persona en sus primeros seis meses?». El entrevistador sonrió: «Es una pregunta muy pertinente; te cuento».',
   'Eso tiene mucho que ver con el puesto.', 'Es una pregunta muy pertinente.', 2),
  ('a0000000-0000-4000-8000-000000000005', 'social', 'emocional', 'Ni el lugar ni el momento',
   'En plena fiesta, un amigo empezó a contarle a Sofía un problema serio con su pareja. Ella lo escuchó un momento y le dijo con cariño: «Esto me importa mucho, pero no creo que sea pertinente hablarlo aquí, con tanto ruido. ¿Nos vemos mañana para un café?».',
   'No sé si es el momento de hablar de esto.', 'No creo que sea pertinente hablarlo aquí.', 3);

-- ----------------------------------------------------------------------------
-- 6. concretar
-- ----------------------------------------------------------------------------

insert into public.words
  (id, slug, lemma, part_of_speech, syllables, stressed_syllable, ipa_latam, ipa_es, explanation,
   example_sentence, register, pedantry_risk, usage_tip, when_not_to_use, collocations, replaces, family,
   semantic_set_id, sort_order, published)
values (
  'a0000000-0000-4000-8000-000000000006',
  'concretar',
  'concretar',
  'verbo',
  array['con', 'cre', 'tar']::text[],
  3,
  '[koŋ.kreˈtar]',
  '[koŋ.kreˈtar]',
  'Pasar de una idea general a algo preciso: poner fecha, cifra, lugar o pasos claros.',
  'Me encanta la idea del taller; ahora hay que concretar la fecha y el presupuesto.',
  'neutral',
  1,
  'Es una forma amable de pedir claridad: «¿Puedes concretar?» suena mejor que «no entiendo qué quieres».',
  'No la confundas con «concertar» (acordar una cita o un precio con alguien). Y no la uses para exigir detalles cuando la conversación todavía está explorando ideas.',
  array['concretar una fecha', 'concretar un plan', 'concretar una propuesta', 'concretar los detalles']::text[],
  '[{"before": "Hay que aterrizar la idea", "after": "Hay que concretar la idea"}, {"before": "Quedamos en vernos un día de estos", "after": "Concretemos un día para vernos"}, {"before": "¿Qué quieres decir exactamente?", "after": "¿Puedes concretar?"}]'::jsonb,
  array['concreto', 'concreción', 'concretamente']::text[],
  null,
  6,
  true
);

insert into public.word_confusions (word_id, confused_with, difference, memory_trick)
values
  ('a0000000-0000-4000-8000-000000000006', 'concertar', '«Concertar» es acordar algo entre varias personas, como una cita o un precio. «Concretar» es precisar los detalles de algo.', 'Concertar une a las personas; concretar precisa los detalles.'),
  ('a0000000-0000-4000-8000-000000000006', 'completar', '«Completar» es terminar o añadir lo que falta. «Concretar» es convertir algo vago en algo preciso.', 'Completas lo que falta; concretas lo que era vago.');

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000061',
    'a0000000-0000-4000-8000-000000000006',
    'El proyecto suena bien, pero es muy general; antes de pedir dinero, tienes que {{blank}} cuántas personas participarán y qué harán cada semana.',
    'El proyecto es muy general: busca el verbo para pasar de la idea a los datos exactos.',
    'Concretar: pasar de la idea general a cifras y pasos claros. «Concertar» es acordar algo con otras personas, y «resumir» es acortar, pero al proyecto le faltan detalles, no le sobran.',
    1
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('resumir', false, 'near_synonym', '«Resumir» es decir algo en menos palabras. El proyecto ya es demasiado general: le faltan datos, no le sobran.', 'Resumir es acortar. ¿Al proyecto le sobran palabras o le faltan detalles?', 1),
    ('concretar', true, null, null, null, 2),
    ('concertar', false, 'paronym', '«Concertar» es acordar algo con otras personas, como una cita. Aquí no se trata de ponerse de acuerdo con nadie, sino de precisar el proyecto.', '«Concertar» es acordar algo con otras personas. ¿Con quién tendrías que ponerte de acuerdo aquí?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000062',
    'a0000000-0000-4000-8000-000000000006',
    'Nos pidieron {{blank}} la propuesta: en lugar de «mejorar la atención», quieren saber qué cambiará, quién lo hará y para cuándo.',
    'Piden pasar de una frase vaga a qué, quién y cuándo.',
    'Concretar: convertir una frase vaga en qué, quién y cuándo. «Ampliar» sería abarcar más, y «concertar» sería llegar a un acuerdo con alguien; ninguna de las dos pide precisión.',
    2
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('concretar', true, null, null, null, 1),
    ('ampliar', false, 'near_synonym', '«Ampliar» es hacer algo más grande o abarcar más. No piden más ideas, sino detalles exactos: qué, quién y cuándo.', 'Ampliar es hacer algo más grande. ¿Piden más contenido o más precisión?', 2),
    ('concertar', false, 'paronym', '«Concertar» es ponerse de acuerdo con alguien. Lo que piden aquí es precisión: qué cambiará, quién y para cuándo.', '«Concertar» es acordar algo entre partes. ¿La frase pide un acuerdo o detalles exactos?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000063',
    'a0000000-0000-4000-8000-000000000006',
    'Tu hermano dice que quiere «cambiar de vida». Antes de darle consejos, pídele que {{blank}}: ¿quiere otro trabajo, otra ciudad o más tiempo libre?',
    'La pregunta del final pide pasar de una idea vaga a algo preciso.',
    'Concrete: que pase de «cambiar de vida» a algo preciso. «Se explaye» sería hablar más, no mejor, y «recapacite» sugiere que se equivocó, cuando solo le falta precisión.',
    3
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('se explaye', false, 'near_synonym', '«Explayarse» es hablar largo y tendido. No hace falta que tu hermano hable más, sino que diga qué quiere exactamente.', 'Explayarse es extenderse al hablar. ¿Buscas más palabras o una respuesta precisa?', 1),
    ('recapacite', false, 'near_synonym', '«Recapacitar» es reconsiderar algo, como si fuera un error. Querer cambiar de vida no es un error: solo es una idea vaga.', 'Recapacitar es pensar si uno se equivocó. ¿Tu hermano hizo algo mal o solo habla en general?', 2),
    ('concrete', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

insert into public.readings (word_id, scene, conversation_type, title, body, before_phrase, after_phrase, position)
values
  ('a0000000-0000-4000-8000-000000000006', 'trabajo', 'practica', 'Del «ya veremos» al plan',
   'Al terminar la lluvia de ideas, Mateo dijo: «Muy buenas propuestas. Antes de irnos, concretemos: ¿quién hace qué y para cuándo?». En cinco minutos, cada idea tenía responsable y fecha, y la reunión por fin sirvió para algo.',
   'Bueno, ya vemos cómo lo hacemos.', 'Antes de irnos, concretemos.', 1),
  ('a0000000-0000-4000-8000-000000000006', 'social', 'social', 'El café pendiente',
   'Elena y su amiga llevaban un año diciendo «a ver cuándo nos vemos». Esta vez Elena escribió: «Concretemos: ¿el sábado a las once, en la cafetería de siempre?». La respuesta llegó en un minuto: «¡Hecho!».',
   'A ver cuándo nos vemos.', 'Concretemos: el sábado a las once.', 2),
  ('a0000000-0000-4000-8000-000000000006', 'entrevista', 'practica', 'Menos adjetivos, más ejemplos',
   'Cuando le preguntaron por sus logros, Paula empezó con «soy muy trabajadora». Se detuvo y concretó: «En mi último empleo reduje a la mitad el tiempo de respuesta a clientes en seis meses». La entrevistadora tomó nota.',
   'Soy muy trabajadora y todo eso.', 'Lo concreto: reduje a la mitad el tiempo de respuesta.', 3);

-- ----------------------------------------------------------------------------
-- 7. contundente
-- ----------------------------------------------------------------------------

insert into public.words
  (id, slug, lemma, part_of_speech, syllables, stressed_syllable, ipa_latam, ipa_es, explanation,
   example_sentence, register, pedantry_risk, usage_tip, when_not_to_use, collocations, replaces, family,
   semantic_set_id, sort_order, published)
values (
  'a0000000-0000-4000-8000-000000000007',
  'contundente',
  'contundente',
  'adjetivo',
  array['con', 'tun', 'den', 'te']::text[],
  3,
  '[kon.tunˈden.te]',
  '[kon.tunˈden.te]',
  'Tan claro y firme que convence o no deja lugar a dudas.',
  'Los datos del estudio son contundentes: la nueva ruta ahorra veinte minutos al día.',
  'neutral',
  1,
  'Brilla con pruebas, datos y respuestas. Con personas, cuidado: «fue muy contundente» puede sonar a duro.',
  'No la uses para una opinión que solo es agresiva o ruidosa: lo contundente convence por su claridad, no por el volumen.',
  array['argumento contundente', 'respuesta contundente', 'prueba contundente', 'resultados contundentes']::text[],
  '[{"before": "Un argumento muy bueno", "after": "Un argumento contundente"}, {"before": "Le respondió clarísimo, sin dar vueltas", "after": "Le dio una respuesta contundente"}, {"before": "Los resultados son súper claros", "after": "Los resultados son contundentes"}]'::jsonb,
  array['contundencia', 'contundentemente']::text[],
  null,
  7,
  true
);

insert into public.word_confusions (word_id, confused_with, difference, memory_trick)
values
  ('a0000000-0000-4000-8000-000000000007', 'condescendiente', '«Condescendiente» describe a quien trata a los demás con aire de superioridad. «Contundente» describe algo claro y firme.', 'Lo contundente convence; lo condescendiente ofende.'),
  ('a0000000-0000-4000-8000-000000000007', 'convincente', '«Convincente» es lo que logra convencer. «Contundente» añade firmeza: además de convencer, no deja lugar a dudas.', 'Lo convincente te persuade; lo contundente te deja sin réplica.');

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000071',
    'a0000000-0000-4000-8000-000000000007',
    'Cuando le preguntaron si el proyecto seguiría adelante, la directora dio una respuesta {{blank}}: «Sí, sin cambios y con el mismo equipo».',
    'La respuesta es tan firme y clara que no deja ninguna duda.',
    'Contundente: una respuesta firme que no deja dudas. «Condescendiente» sería hablar con superioridad, y «contenciosa» se refiere a disputas o juicios; la directora solo fue clara.',
    1
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('condescendiente', false, 'paronym', '«Condescendiente» es hablar con aire de superioridad. La respuesta de la directora es breve y clara, sin mirar a nadie por encima del hombro.', 'Lo condescendiente suena a superioridad. ¿La respuesta de la directora trata mal a alguien?', 1),
    ('contundente', true, null, null, null, 2),
    ('contenciosa', false, 'paronym', '«Contencioso» se usa para disputas, sobre todo legales. La directora no está peleando: responde con total claridad.', '«Contencioso» suena a pleito o juicio. ¿La respuesta abre una disputa o la cierra?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000072',
    'a0000000-0000-4000-8000-000000000007',
    'Lucía llevaba media hora discutiendo con su hermano sobre si su sobrino dormía lo suficiente, hasta que le mostró el registro de sueño de toda la semana: fue una prueba {{blank}}.',
    'La prueba fue tan clara que terminó la discusión.',
    'Contundente: la prueba no dejó lugar a dudas y cerró la discusión. «Llamativa» solo describe algo que atrae la atención, y «contingente» es lo que puede ocurrir o no.',
    2
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('llamativa', false, 'near_synonym', '«Llamativa» es lo que atrae la atención. Aquí importa que la prueba terminó la discusión, no que fuera vistosa.', 'Algo llamativo se nota mucho, pero ¿basta para terminar una discusión?', 1),
    ('contingente', false, 'paronym', '«Contingente» es lo que puede suceder o no. El registro de la semana ya existe y cerró la discusión.', '«Contingente» es lo que podría pasar o no. ¿El registro de la semana es una posibilidad o un hecho?', 2),
    ('contundente', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000073',
    'a0000000-0000-4000-8000-000000000007',
    'Cuando le pidieron un ejemplo de liderazgo, Raúl no dio rodeos: contó con cifras claras cómo sacó adelante un proyecto en crisis. Fue {{blank}} y convenció al comité.',
    'Raúl fue directo, con datos claros, y no dejó dudas.',
    'Contundente: directo, con cifras y sin dejar dudas. «Condescendiente» sería tratar al comité con superioridad, y «redundante» sería repetirse, justo lo contrario de ir al grano.',
    3
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('contundente', true, null, null, null, 1),
    ('condescendiente', false, 'paronym', '«Condescendiente» es tratar a otros con superioridad, y eso no convence a un comité. Raúl fue directo y aportó cifras.', 'Lo condescendiente molesta a quien escucha. ¿La frase dice que el comité se molestó?', 2),
    ('redundante', false, 'paronym', '«Redundante» es repetir lo que ya se dijo. Raúl no dio rodeos: fue al grano con cifras.', 'Lo redundante se repite. ¿Encaja con alguien que «no dio rodeos»?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

insert into public.readings (word_id, scene, conversation_type, title, body, before_phrase, after_phrase, position)
values
  ('a0000000-0000-4000-8000-000000000007', 'trabajo', 'practica', 'Los números hablan',
   'Nadie creía que el nuevo horario funcionara. Camila no discutió: presentó una tabla con tres meses de datos. Las quejas habían bajado un 40 %. Su jefe cerró el tema: «Los resultados son contundentes; lo mantenemos».',
   'Los resultados son súper claros.', 'Los resultados son contundentes.', 1),
  ('a0000000-0000-4000-8000-000000000007', 'familia', 'emocional', 'Un no con cariño',
   'Su hija adolescente insistía en volver a casa a las tres de la mañana. Andrea la escuchó hasta el final y respondió, tranquila y contundente: «Entiendo que quieras quedarte más. La respuesta es no: a la una paso a buscarte».',
   'Que no y punto, porque lo digo yo.', 'Fue una respuesta tranquila y contundente.', 2),
  ('a0000000-0000-4000-8000-000000000007', 'social', 'social', 'Fin del rumor',
   'En el grupo de amigos corría el rumor de que Diego se iba de la ciudad. Él escribió un mensaje breve y contundente: «No me mudo. Cambio de trabajo, pero sigo aquí». Nadie volvió a preguntar.',
   'Que no, que no es así, de verdad.', 'Un mensaje breve y contundente.', 3);

-- ----------------------------------------------------------------------------
-- 8. zanjar
-- ----------------------------------------------------------------------------

insert into public.words
  (id, slug, lemma, part_of_speech, syllables, stressed_syllable, ipa_latam, ipa_es, explanation,
   example_sentence, register, pedantry_risk, usage_tip, when_not_to_use, collocations, replaces, family,
   semantic_set_id, sort_order, published)
values (
  'a0000000-0000-4000-8000-000000000008',
  'zanjar',
  'zanjar',
  'verbo',
  array['zan', 'jar']::text[],
  2,
  '[sanˈxar]',
  '[θanˈxar]',
  'Terminar de forma definitiva una discusión, un problema o un asunto pendiente.',
  'Llamé a mi hermano para zanjar el malentendido antes de la cena familiar.',
  'neutral',
  1,
  'Sirve para cerrar con respeto: «Zanjemos el tema así» propone un final sin imponerlo.',
  'No la uses para cortar a alguien que todavía no ha podido opinar: zanjar antes de escuchar suena autoritario.',
  array['zanjar un tema', 'zanjar una discusión', 'zanjar un conflicto', 'zanjar la cuestión']::text[],
  '[{"before": "Cerremos el tema", "after": "Zanjemos el tema"}, {"before": "Ya, se acabó la discusión", "after": "Con esto zanjamos la discusión"}, {"before": "Dejarlo resuelto de una vez", "after": "Zanjarlo de una vez"}]'::jsonb,
  array['zanja']::text[],
  null,
  8,
  true
);

insert into public.word_confusions (word_id, confused_with, difference, memory_trick)
values
  ('a0000000-0000-4000-8000-000000000008', 'saldar', '«Saldar» se usa sobre todo con deudas y cuentas: es pagarlas por completo. «Zanjar» es poner fin a una discusión o a un asunto.', 'Saldas lo que debes; zanjas lo que discutes.'),
  ('a0000000-0000-4000-8000-000000000008', 'zafarse', '«Zafarse» es librarse de algo que molesta o de una obligación. «Zanjar» no es escapar del problema, sino resolverlo.', 'Quien se zafa huye; quien zanja resuelve.');

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000081',
    'a0000000-0000-4000-8000-000000000008',
    'Llevaban media hora discutiendo el orden de las diapositivas, hasta que Laura decidió {{blank}} el asunto: «Vamos por orden cronológico y seguimos con lo demás».',
    'Laura pone fin a la discusión con una decisión clara.',
    'Zanjar: Laura terminó la discusión con una decisión definitiva. «Esquivar» sería evitar el asunto y «aplazar» sería dejarlo para después; ella lo resolvió en el momento.',
    1
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('esquivar', false, 'near_synonym', '«Esquivar» un asunto es evitarlo. Laura hace lo contrario: lo enfrenta y lo resuelve.', 'Quien esquiva un tema no lo toca. ¿Laura evita el tema o toma una decisión?', 1),
    ('zanjar', true, null, null, null, 2),
    ('aplazar', false, 'near_synonym', '«Aplazar» es dejar algo para después. Laura no lo deja pendiente: decide en ese momento y cierra el tema.', 'Aplazar es dejar para más tarde. ¿Laura deja la decisión para otro día?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000082',
    'a0000000-0000-4000-8000-000000000008',
    'Después de años sin hablarse por la herencia, los dos hermanos se reunieron a comer para {{blank}} el conflicto de una vez.',
    'Los hermanos quieren que el problema quede terminado para siempre.',
    'Zanjar: poner fin definitivo al conflicto. «Finiquitar» significa algo parecido, pero suena a trámite de oficina, y «sobrellevar» es aguantar el problema, no terminarlo.',
    2
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('finiquitar', false, 'register', '«Finiquitar» suena a trámite de oficina, como cerrar un contrato. Para una comida entre hermanos resulta demasiado frío.', '«Finiquitar» es propio de contratos y cuentas. ¿Suena natural en una comida familiar?', 1),
    ('sobrellevar', false, 'near_synonym', '«Sobrellevar» es aguantar algo difícil con paciencia. Los hermanos no quieren aguantar más: quieren terminarlo de una vez.', 'Sobrellevar es soportar. ¿Encaja con «de una vez»?', 2),
    ('zanjar', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b0000000-0000-4000-8000-000000000083',
    'a0000000-0000-4000-8000-000000000008',
    'En el grupo de amigos, la discusión por el lugar de la cena ya duraba dos días, así que Marta la {{blank}} con una encuesta: el restaurante más votado ganaba.',
    'Marta termina de forma definitiva una discusión que se alargaba.',
    'Zanjó: Marta terminó la discusión de forma definitiva con la encuesta. «Aplazó» sería dejarla para después, y «dirimió» tiene un sentido cercano, pero suena a juzgado, no a un chat de amigos.',
    3
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('zanjó', true, null, null, null, 1),
    ('aplazó', false, 'near_synonym', '«Aplazar» es dejar algo para más tarde. Con la encuesta, Marta no pospone nada: la decisión queda tomada.', 'Fíjate en el final: el más votado ganaba. ¿Eso deja la decisión para después?', 2),
    ('dirimió', false, 'register', '«Dirimir» se parece en significado, pero suena a juzgado o a arbitraje. En un grupo de amigos resulta demasiado solemne.', '«Dirimir» es propio de jueces y árbitros. ¿Suena natural en el chat de tus amigos?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

insert into public.readings (word_id, scene, conversation_type, title, body, before_phrase, after_phrase, position)
values
  ('a0000000-0000-4000-8000-000000000008', 'trabajo', 'practica', 'Reunión sin fin',
   'La discusión sobre el logo nuevo ya iba por la tercera reunión. Gabriel propuso: «Hagamos una prueba con veinte clientes y que decidan ellos. Así lo zanjamos esta semana». Todos aceptaron, aliviados.',
   'Ya, cerremos el tema de una vez.', 'Así lo zanjamos esta semana.', 1),
  ('a0000000-0000-4000-8000-000000000008', 'familia', 'emocional', 'El malentendido',
   'Valeria y su hermano no se hablaban desde el cumpleaños de su madre. Ella lo llamó: «No quiero que esto siga creciendo. Te pido perdón por lo que dije y quiero zanjarlo hoy». Hubo un silencio, y luego una risa: «Yo también».',
   'Ya olvidémonos de eso, ¿sí?', 'Quiero zanjarlo hoy.', 2),
  ('a0000000-0000-4000-8000-000000000008', 'social', 'social', 'Quién paga',
   'Cada vez que salían, el grupo discutía cómo repartir la cuenta. Tomás zanjó el tema con humor: «Propuesta: cada uno paga lo suyo y quien llegue tarde invita el postre». Desde entonces, nadie llega tarde.',
   'Bueno, ya, se acabó la discusión.', 'Tomás zanjó el tema con humor.', 3);
