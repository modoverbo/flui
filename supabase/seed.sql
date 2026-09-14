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

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'bd7f2986-3012-4193-9692-d2bf5c7dcb8d',
    'a0000000-0000-4000-8000-000000000001',
    'En la entrevista, Renata hizo una pregunta tan {{blank}} que el jurado se miró entre sí antes de contestar.',
    'La pregunta apuntó justo a un punto que nadie había mirado todavía.',
    'Perspicaz: la pregunta apuntó a lo que nadie había mirado. «Veraz» solo dice que algo se ajusta a la verdad, y «curiosa» habla de interés, no de agudeza.',
    4
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('veraz', false, 'paronym', '«Veraz» dice que algo se ajusta a la verdad; una pregunta no se juzga por eso.', '«Veraz» habla de decir la verdad. ¿Es eso lo que deja pensando al jurado?', 1),
    ('perspicaz', true, null, null, null, 2),
    ('curiosa', false, 'near_synonym', '«Curiosa» dice que alguien quiere saber; no dice que haya visto algo que los demás pasaron por alto.', '«Curiosa» habla de interés. ¿El jurado se calla por el interés o por lo certero?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'f4a023c1-0781-49dd-ba54-652653beb55d',
    'a0000000-0000-4000-8000-000000000001',
    'Cuando su hijo empezó a contestar con monosílabos, Elisa fue {{blank}} y supo que algo le estaba pasando.',
    'Entendió el problema por una señal mínima, sin que nadie se lo dijera.',
    'Perspicaz: leyó una señal mínima y acertó. «Metiche» es coloquial y suena a entrometido, y «locuaz» describe a quien habla mucho.',
    5
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('perspicaz', true, null, null, null, 1),
    ('metiche', false, 'register', '«Metiche» es muy coloquial y acusa de entrometerse; aquí una madre lee a su hijo, no se entromete.', '«Metiche» suena a reproche coloquial. ¿La frase acusa a alguien o lo elogia?', 2),
    ('locuaz', false, 'paronym', '«Locuaz» es quien habla mucho; en esta escena el que habla poco es el hijo.', '«Locuaz» va de hablar mucho. ¿Quién habla poco en esta escena?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'd00771f3-5981-4cc1-8c10-3a8ed57316ee',
    'a0000000-0000-4000-8000-000000000001',
    'Rafael leyó el correo dos veces y, {{blank}} como siempre, vio que faltaba la firma del responsable.',
    'Se trata de darse cuenta de un detalle que pasa desapercibido.',
    'Perspicaz: vio un detalle que pasaba desapercibido. «Pertinaz» describe lo que no cesa, y «sagaz» subraya la astucia para sacar ventaja.',
    6
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('pertinaz', false, 'paronym', '«Pertinaz» describe lo que no cesa, como una lluvia; no dice nada sobre notar detalles.', '«Pertinaz» se dice de algo que no para. ¿La frase habla de insistir?', 1),
    ('sagaz', false, 'near_synonym', '«Sagaz» subraya la astucia para sacar ventaja; aquí solo se nota un fallo en un correo.', '«Sagaz» sugiere astucia con un fin. ¿Alguien busca ventaja en esta escena?', 2),
    ('perspicaz', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '6195dfc5-b723-4dde-adae-e8feabba9c83',
    'a0000000-0000-4000-8000-000000000001',
    'Durante la cena, Nuria prefirió callar, aunque su mirada {{blank}} ya había leído la tensión entre sus primos.',
    'La mirada capta algo que nadie dice en voz alta.',
    'Perspicaz: la mirada leyó la tensión sin palabras. «Voraz» habla de un apetito enorme, y «chismosa» es coloquial y acusa de curiosear.',
    7
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('perspicaz', true, null, null, null, 1),
    ('voraz', false, 'paronym', '«Voraz» describe un apetito enorme o un consumo desmedido; una mirada que lee tensiones no es eso.', '«Voraz» va de comer o devorar. ¿Encaja con leer una tensión familiar?', 2),
    ('chismosa', false, 'register', '«Chismosa» es coloquial y acusa de contar lo ajeno; en la frase esa persona calla.', '«Chismosa» acusa de contar lo ajeno. ¿Quién guarda silencio durante la cena?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '2a21b221-854b-401b-91b7-a34b5869c929',
    'a0000000-0000-4000-8000-000000000001',
    'Marcos apenas habló en la reunión, pero su comentario final fue tan {{blank}} que cambió la decisión del grupo.',
    'El comentario mostró algo que el grupo no había visto hasta entonces.',
    'Perspicaz: el comentario mostró lo que el grupo no había visto. «Falaz» califica de engañoso un argumento, e «insistente» solo dice que alguien repite.',
    8
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('falaz', false, 'paronym', '«Falaz» dice que un argumento engaña; aquí el comentario convence porque es certero.', '«Falaz» acusa de engañar. ¿El grupo cambia de idea por un engaño?', 1),
    ('perspicaz', true, null, null, null, 2),
    ('insistente', false, 'near_synonym', '«Insistente» dice que alguien repite lo mismo, y en la frase esa persona apenas habla.', '«Insistente» va de repetir. ¿Cuánto habló esa persona en la reunión?', 3)
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

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'c7493b38-a568-4047-b3f7-20552ccc8a49',
    'a0000000-0000-4000-8000-000000000002',
    'Cristina llevaba días dándole vueltas al reparto de la limpieza en casa, hasta que decidió {{blank}} el tema durante la cena.',
    'Busca el verbo para poner el asunto sobre la mesa y hablarlo en familia.',
    'Plantear: poner el tema sobre la mesa para hablarlo. «Plantar» es sembrar o dejar a alguien esperando, y «exigir» sería reclamar con firmeza, cuando ella solo quiere conversar.',
    4
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('plantar', false, 'paronym', '«Plantar» es sembrar o dejar a alguien esperando; un reparto de la limpieza no se siembra.', '«Plantar» se usa con semillas o con quien no llega a una cita. ¿Es eso lo que pasa en la cena?', 1),
    ('plantear', true, null, null, null, 2),
    ('exigir', false, 'near_synonym', '«Exigir» es reclamar algo con firmeza, y ella quiere abrir una conversación, no imponer un reparto.', '«Exigir» no deja espacio para responder. ¿Ella busca imponer o conversar?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'df4da2f6-044d-4ddb-8c7a-939b94c86320',
    'a0000000-0000-4000-8000-000000000002',
    'Durante la comida familiar, Ignacio quiso {{blank}} un cambio en los turnos de los domingos, pero esperó al café para hacerlo con calma.',
    'Busca el verbo para abrir un asunto y hablarlo con calma con los demás.',
    'Plantear: abrir el asunto con calma para hablarlo en familia. «Implantar» sería imponer el cambio, y «soltar» es coloquial y sugiere decirlo de golpe, justo lo que él evita.',
    5
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('plantear', true, null, null, null, 1),
    ('implantar', false, 'paronym', '«Implantar» es establecer algo sin consultarlo, y él espera al café para hablarlo con todos.', '«Implantar» impone desde arriba. ¿Quien espera al café busca imponer o conversar?', 2),
    ('soltar', false, 'register', '«Soltar» es coloquial y sugiere decir algo de golpe; él hace lo contrario y espera el momento con calma.', '«Soltar» suena a decirlo de repente. ¿Encaja con esperar al café?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'ff066810-5a58-4d18-a6cc-906c20f5d837',
    'a0000000-0000-4000-8000-000000000002',
    'Sandra abrió el mensaje con una línea clara: quería {{blank}} dos fechas posibles para la mudanza y que su hermana eligiera una.',
    'Pone dos opciones sobre la mesa para que la otra persona decida.',
    'Plantear: pone las dos fechas sobre la mesa para que su hermana elija. «Plantar» es sembrar o dejar a alguien esperando, e «imponer» sería decidir por ella.',
    6
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('imponer', false, 'near_synonym', '«Imponer» es decidir por la otra persona, y aquí su hermana es quien elige la fecha.', 'Fíjate en el final: su hermana elige. ¿Eso es imponer?', 1),
    ('plantar', false, 'paronym', '«Plantar» es sembrar o dejar a alguien esperando; dos fechas en un mensaje no se siembran.', '«Plantar» va con semillas o con citas a las que nadie llega. ¿Es eso lo que hace Sandra?', 2),
    ('plantear', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'cd3d93b1-e34e-41f7-8354-9102e52dc799',
    'a0000000-0000-4000-8000-000000000002',
    'El nuevo horario de la biblioteca {{blank}} un problema que nadie había previsto: los vecinos se quedaban sin sala los sábados.',
    'El horario hace aparecer un asunto que habrá que hablar y resolver.',
    'Plantea: el horario hace aparecer un problema que habrá que hablar. «Implanta» sería establecer el horario, y «resuelve» diría lo contrario, porque aquí el problema empieza.',
    7
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('implanta', false, 'paronym', '«Implantar» es establecer algo, y lo que el horario establece no es el problema, sino el horario mismo.', '«Implantar» es establecer algo nuevo. ¿Qué se establece aquí, el horario o el problema?', 1),
    ('plantea', true, null, null, null, 2),
    ('resuelve', false, 'near_synonym', '«Resolver» sería dejar el asunto terminado, y aquí los vecinos se quedan sin sala: el problema empieza.', 'Relee el final: los vecinos se quedan sin sala. ¿Eso suena a problema resuelto?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '935e979d-bdeb-48a9-9cb7-7c4a08d32b33',
    'a0000000-0000-4000-8000-000000000002',
    'Nosotros {{blank}} la idea del taller sin saber si habría presupuesto, y al final la dirección la aprobó.',
    'Pusimos la idea sobre la mesa a la espera de una respuesta.',
    'Planteamos: pusimos la idea sobre la mesa a la espera de una respuesta. «Plantamos» es sembrar o dejar a alguien esperando, e «impusimos» diría que ya estaba decidido.',
    8
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('planteamos', true, null, null, null, 1),
    ('plantamos', false, 'paronym', '«Plantar» es sembrar o dejar a alguien esperando; una idea para un taller no se siembra.', '«Plantar» va con semillas o con citas fallidas. ¿Es eso lo que se hace con una idea?', 2),
    ('impusimos', false, 'near_synonym', '«Imponer» diría que la decisión ya estaba tomada, y aquí la dirección todavía tenía que aprobarla.', 'Fíjate en el final: la dirección aprueba. ¿Se aprueba lo que ya se impuso?', 3)
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
  'Precisar algo que se dijo, añadiendo detalles o excepciones para que sea más justo.',
  'Estoy de acuerdo con la propuesta, pero quiero matizar un punto sobre los plazos.',
  'neutral',
  1,
  'Sirve para no estar ni del todo a favor ni del todo en contra: «Lo matizaría» abre espacio sin confrontar.',
  'No la uses para esconder un error o hacer que algo parezca mejor de lo que es: eso es «maquillar».',
  array['matizar una afirmación', 'matizar lo dicho', 'matizar una crítica', 'conviene matizar']::text[],
  '[{"before": "Sí, pero no es tan así", "after": "Sí, aunque conviene matizarlo"}, {"before": "Bueno, depende, o sea, no siempre", "after": "Lo matizo: no pasa siempre"}, {"before": "Aclarar un poquito lo que dije", "after": "Matizar lo que dije"}]'::jsonb,
  array['matiz', 'matización']::text[],
  'fuerza-de-la-afirmacion',
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

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '9c815da0-a33b-4bdf-a9b8-e2559fbb09cf',
    'a0000000-0000-4000-8000-000000000003',
    'En la presentación, Fernanda {{blank}} el dato de ventas: cayeron en tienda, pero en internet crecieron un 20 %.',
    'Corrige el dato con una precisión verdadera que cambia su sentido.',
    'Matizó: precisó el dato y cambió su sentido. «Atizó» sería avivar una discusión, e «infló» es coloquial y sugiere exagerar la cifra.',
    4
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('atizó', false, 'paronym', '«Atizar» es avivar un conflicto, y en la sala nadie discute: se completa una cifra.', '«Atizar» va de encender peleas. ¿Hay pelea en esa sala?', 1),
    ('infló', false, 'register', '«Inflar» una cifra es coloquial y acusa de exagerarla, y la corrección aquí es honesta y comprobable.', '«Inflar» suena a exagerar a propósito. ¿Alguien exagera o alguien precisa?', 2),
    ('matizó', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'f9967efa-63c5-4c98-a875-0d3f9736f922',
    'a0000000-0000-4000-8000-000000000003',
    'En el chat del equipo, Emilio quiso {{blank}} su comentario sobre el retraso antes de que alguien lo tomara a mal.',
    'Quiere precisar lo dicho para que no se entienda como un reproche.',
    'Matizar: precisar lo dicho para que no suene a reproche. «Endulzar» es coloquial y sugiere falsear el tono, y «atizar» sería echar leña al retraso.',
    5
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('matizar', true, null, null, null, 1),
    ('endulzar', false, 'register', '«Endulzar» es coloquial y sugiere falsear el tono para caer bien, y él solo quiere ser preciso.', '«Endulzar» suena a maquillar el tono. ¿Quiere gustar o quiere ser preciso?', 2),
    ('atizar', false, 'paronym', '«Atizar» sería echar leña al retraso, justo lo que intenta evitar antes de que alguien se moleste.', '«Atizar» empeora las cosas. ¿Quiere calmar el chat o encenderlo?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '2b77bc04-a4c5-4db5-bef6-e3f6973fddcc',
    'a0000000-0000-4000-8000-000000000003',
    'Patricia aceptó la propuesta, aunque pidió {{blank}} un punto sobre los plazos antes de firmar.',
    'Pide precisar un punto antes de comprometerse del todo.',
    'Matizar: precisar un punto antes de comprometerse. «Pulir» habla de mejorar la forma, y «finiquitar» suena a trámite de oficina y cerraría el tema.',
    6
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('pulir', false, 'near_synonym', '«Pulir» habla de mejorar la forma de algo, y lo que ella pide es precisar el contenido de un punto.', '«Pulir» va de acabado y de forma. ¿Pide otra forma o más precisión?', 1),
    ('matizar', true, null, null, null, 2),
    ('finiquitar', false, 'register', '«Finiquitar» suena a trámite de oficina y cerraría el punto, cuando ella todavía quiere hablarlo.', '«Finiquitar» es propio de contratos. ¿Quiere cerrar el punto o afinarlo?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'fefa03e4-83c5-4998-b874-501ee627b18a',
    'a0000000-0000-4000-8000-000000000003',
    'Clara escuchó la queja hasta el final y luego {{blank}} su respuesta con dos ejemplos exactos.',
    'Precisa su respuesta con datos en lugar de hablar en general.',
    'Matizó: precisó su respuesta con datos exactos. «Atizó» sería avivar la queja, y «adornó» es coloquial y sugiere embellecer lo dicho.',
    7
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('matizó', true, null, null, null, 1),
    ('atizó', false, 'paronym', '«Atizar» sería avivar la queja, y ella responde con ejemplos para bajar la tensión.', '«Atizar» aviva. ¿Su respuesta calienta la queja o la aterriza?', 2),
    ('adornó', false, 'register', '«Adornar» una respuesta es coloquial y sugiere embellecerla, no aportar dos datos comprobables.', '«Adornar» suena a añadir floritura. ¿Aporta floritura o aporta datos?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '190f702d-1311-4e8d-b417-6cb1ecdf8294',
    'a0000000-0000-4000-8000-000000000003',
    'Hugo siempre {{blank}} antes que discutir: añade un detalle cierto en vez de llevar la contraria.',
    'Busca el verbo para precisar sin convertir la charla en una pelea.',
    'Matiza: precisa sin convertir la charla en pelea. «Rebate» sería contradecir del todo, y «atiza» sería avivar la discusión.',
    8
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('rebate', false, 'near_synonym', '«Rebatir» es contradecir del todo, y la frase dice que él evita llevar la contraria.', '«Rebatir» contradice entero. ¿Eso encaja con quien evita la contraria?', 1),
    ('matiza', true, null, null, null, 2),
    ('atiza', false, 'paronym', '«Atizar» es avivar una discusión, y él hace justo lo contrario para evitarla.', '«Atizar» enciende. ¿Quien evita discutir enciende la charla?', 3)
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
  'Pensar con calma lo bueno y lo malo de algo antes de decidir.',
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

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'bc15c802-f342-482c-83bd-6d7c8dad7e71',
    'a0000000-0000-4000-8000-000000000004',
    'Cuando le ofrecieron coordinar el equipo, Mariana pidió dos días para {{blank}} lo que ganaba y lo que perdía con el cambio.',
    'Busca el verbo para comparar con calma lo que se gana y lo que se pierde.',
    'Sopesar: comparar con calma lo que gana y lo que pierde. «Sobrepasar» es superar un límite, y «rumiar» es coloquial y sugiere dar vueltas sin llegar a nada.',
    4
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('sopesar', true, null, null, null, 1),
    ('sobrepasar', false, 'paronym', '«Sobrepasar» es superar un límite, y Mariana no supera nada: compara lo que gana con lo que pierde.', '«Sobrepasar» es ir más allá de un límite. ¿Qué límite superaría Mariana aquí?', 2),
    ('rumiar', false, 'register', '«Rumiar» es coloquial y sugiere dar vueltas a algo sin llegar a nada; ella pide dos días justamente para decidir.', '«Rumiar» suena a darle vueltas sin salida. ¿Ella se queda atascada o va a decidir?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '6a635cdf-0073-4e81-a84b-ff74a6eb1ba6',
    'a0000000-0000-4000-8000-000000000004',
    'Nosotros {{blank}} tres proveedores antes de firmar, y el más barato no era el que mejor cumplía los plazos.',
    'Comparamos las tres opciones con cuidado antes de elegir una.',
    'Sopesamos: comparamos los tres antes de decidir. «Sobrepasamos» es superar un límite, y «descartamos» diría que los quitamos de la lista sin compararlos.',
    5
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('sobrepasamos', false, 'paronym', '«Sobrepasar» es superar un límite, y aquí nadie supera nada: se comparan tres ofertas.', '«Sobrepasar» es ir más allá de un límite. ¿Se supera algo o se compara?', 1),
    ('sopesamos', true, null, null, null, 2),
    ('descartamos', false, 'near_synonym', '«Descartar» es quitar una opción de la lista, y la frase cuenta que las tres se compararon una por una.', '«Descartar» deja fuera. ¿Los tres quedaron fuera o se compararon entre sí?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '300e780a-e870-45a3-9e4f-c80efc4dd76d',
    'a0000000-0000-4000-8000-000000000004',
    'En la entrevista, Rodrigo explicó que {{blank}} durante un mes el sueldo fijo frente a la libertad de trabajar por su cuenta.',
    'Puso las dos opciones en la balanza durante un mes antes de elegir.',
    'Sopesó: comparó las dos opciones con calma antes de elegir. «Sobrepasó» es superar un límite, y «pospuso» sería dejar la decisión para más adelante.',
    6
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('pospuso', false, 'near_synonym', '«Posponer» es dejar la decisión para más adelante, y él la tomó después de compararlo todo durante un mes.', '«Posponer» aplaza. ¿Ese mes lo usó para aplazar o para comparar?', 1),
    ('sopesó', true, null, null, null, 2),
    ('sobrepasó', false, 'paronym', '«Sobrepasar» es superar un límite, y aquí se comparan un sueldo fijo y una libertad, no se supera ninguno.', '«Sobrepasar» es ir más allá de un límite. ¿Hay algún límite en esta frase?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'd17d08da-7499-4a9c-a5e5-d7abef5495d9',
    'a0000000-0000-4000-8000-000000000004',
    'Antes de darle una respuesta a su equipo, Teresa se tomó el fin de semana para {{blank}} lo que costaría trabajar los sábados.',
    'Mide con calma el precio real de una decisión antes de responder.',
    'Sopesar: medir con calma lo que costaría antes de responder. «Sobrepasar» es superar un límite, y «asumir» sería aceptarlo sin más, cuando aún no ha decidido.',
    7
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('asumir', false, 'near_synonym', '«Asumir» sería aceptar ese coste sin discutirlo, y ella todavía no le ha dado una respuesta a su equipo.', '«Asumir» ya acepta. ¿Teresa ha aceptado algo o sigue pensándolo?', 1),
    ('sobrepasar', false, 'paronym', '«Sobrepasar» es superar un límite, y lo que hace Teresa es calcular el coste de una opción.', '«Sobrepasar» es ir más allá de un límite. ¿Se supera algo durante ese fin de semana?', 2),
    ('sopesar', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '3cd996e8-afae-4426-98ce-4876dc659adf',
    'a0000000-0000-4000-8000-000000000004',
    'Si dudas entre dos caminos, {{blank}} en voz alta con alguien de confianza ayuda más que decidir a las tres de la mañana.',
    'Se trata de comparar las dos opciones con calma, y hacerlo acompañado.',
    'Sopesarlo: pensarlo con calma junto a alguien. «Sobrepasarlo» es superar un límite, y «soltarlo» es coloquial y sugiere decirlo de golpe, sin pensar.',
    8
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('sopesarlo', true, null, null, null, 1),
    ('sobrepasarlo', false, 'paronym', '«Sobrepasar» es superar un límite, y aquí se comparan dos caminos con alguien de confianza.', '«Sobrepasar» es ir más allá de un límite. ¿Qué límite se superaría hablando con un amigo?', 2),
    ('soltarlo', false, 'register', '«Soltar» es coloquial y sugiere decir algo de golpe; la frase propone lo contrario, pensarlo con otra persona.', '«Soltar» es decirlo de repente. ¿La frase invita a decidir rápido o a pensarlo?', 3)
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

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'dbcb96b2-6569-4743-ba0a-5314291ea34a',
    'a0000000-0000-4000-8000-000000000005',
    'Durante la llamada con el cliente, Álvaro guardó los chistes para el final y solo hizo preguntas {{blank}} sobre el plazo de entrega.',
    'Sus preguntas tenían relación directa con lo que se estaba tratando.',
    'Pertinentes: las preguntas venían al caso del plazo. «Pertinaces» describe lo que no cesa, e «impertinentes» sería justo lo contrario: preguntas que incomodan.',
    4
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('pertinaces', false, 'paronym', '«Pertinaz» describe lo que no cesa, como una lluvia; unas preguntas sobre un plazo no insisten, encajan.', '«Pertinaz» se dice de algo que no para. ¿La frase habla de insistir o de venir al caso?', 1),
    ('pertinentes', true, null, null, null, 2),
    ('impertinentes', false, 'paronym', '«Impertinente» es lo que incomoda o falta al respeto, y Álvaro justamente dejó los chistes para el final.', 'Lo impertinente molesta. ¿Álvaro molesta al cliente o le facilita la llamada?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '634899e1-5d85-4db8-afa0-1b1afa356d26',
    'a0000000-0000-4000-8000-000000000005',
    'En la sobremesa, Lorena preguntó si era {{blank}} hablar del reparto de la herencia con los niños delante.',
    'Se pregunta si el tema viene al caso justo en ese momento.',
    'Pertinente: la duda es si el tema viene al caso en ese momento. «Procedente» suena a escrito legal en plena sobremesa, e «impertinente» diría que el tema incomoda de por sí.',
    5
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('pertinente', true, null, null, null, 1),
    ('procedente', false, 'register', '«Procedente» dice casi lo mismo, pero suena a escrito legal y en una sobremesa en familia resulta frío.', '«Procedente» es propio de documentos y trámites. ¿Suena natural en una sobremesa?', 2),
    ('impertinente', false, 'paronym', '«Impertinente» ya juzga el tema como molesto, y Lorena solo pregunta si es buen momento.', 'Lo impertinente incomoda siempre. ¿Ella juzga el tema o duda del momento?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '0c87b620-271d-42ff-9581-29d4d1f5ac45',
    'a0000000-0000-4000-8000-000000000005',
    'El informe de Guillermo tenía ochenta páginas, pero solo veinte con información {{blank}} para la decisión de mañana.',
    'Solo esas veinte páginas tienen relación directa con lo que hay que decidir.',
    'Pertinente: solo esas veinte páginas tienen que ver con la decisión. «Pertinaz» describe lo que no cesa, y «abundante» habla de cantidad, que aquí sobra.',
    6
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('abundante', false, 'near_synonym', '«Abundante» habla de cantidad, y el problema del informe es justo que le sobran páginas.', '«Abundante» mide cuánto hay. ¿Al informe le falta cantidad o le falta relación con el tema?', 1),
    ('pertinaz', false, 'paronym', '«Pertinaz» es lo que no cesa o quien es terco, y una información no insiste: encaja o no encaja.', '«Pertinaz» se usa para algo que no para, como una tos. ¿Encaja con «información»?', 2),
    ('pertinente', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '1f91734b-c42b-4acd-92ae-0cb2f2b9e890',
    'a0000000-0000-4000-8000-000000000005',
    'Nadie esperaba esa observación de Cecilia sobre el coste del envío, y resultó ser la más {{blank}} de la mañana.',
    'La observación tocó justo el punto que faltaba por tratar.',
    'Pertinente: la observación tocaba justo el punto que faltaba. «Impertinente» diría que incomoda, y «vistosa» habla del aspecto, no del contenido.',
    7
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('impertinente', false, 'paronym', '«Impertinente» es lo que incomoda o falta al respeto, y esta observación resultó ser la mejor de la mañana.', 'Lo impertinente molesta. ¿La frase celebra la observación o la critica?', 1),
    ('pertinente', true, null, null, null, 2),
    ('vistosa', false, 'near_synonym', '«Vistosa» habla de lo que llama la atención por su aspecto, y un comentario sobre costes no se juzga así.', '«Vistosa» va del aspecto. ¿Lo que sorprende es cómo se ve o adónde apunta?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '71279947-f255-44a7-8877-3acbf4d4f8d5',
    'a0000000-0000-4000-8000-000000000005',
    'Antes de enviar la propuesta, Simón borró todo lo que no fuera {{blank}} y la dejó en una sola página.',
    'Se queda solo con lo que tiene relación directa con la propuesta.',
    'Pertinente: dejó solo lo que viene al caso. «Prescindible» diría lo contrario, que borró lo importante, e «impertinente» habla de lo que incomoda.',
    8
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('prescindible', false, 'near_synonym', '«Prescindible» es lo que se puede quitar, así que la frase diría que Simón borró justo lo importante.', 'Lee la frase con «prescindible» dentro: ¿qué se queda en esa página y qué se va?', 1),
    ('impertinente', false, 'paronym', '«Impertinente» es lo que incomoda, y en una propuesta lo que sobra no incomoda: simplemente no viene al caso.', 'Lo impertinente molesta a alguien. ¿Lo que borra Simón molesta o solo sobra?', 2),
    ('pertinente', true, null, null, null, 3)
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

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'c4a68a88-8e3c-498a-af61-7cab242056a5',
    'a0000000-0000-4000-8000-000000000006',
    'Después de media hora de ideas sueltas, Beatriz pidió {{blank}} tres acuerdos con nombre y fecha antes de cerrar la reunión.',
    'Pide convertir las ideas sueltas en acuerdos con responsable y día.',
    'Concretar: convertir las ideas en acuerdos con nombre y fecha. «Concertar» es ponerse de acuerdo con alguien, y «despachar» suena a salir del paso deprisa.',
    4
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('concretar', true, null, null, null, 1),
    ('concertar', false, 'paronym', '«Concertar» es acordar algo con otra parte, como una cita; aquí el grupo ya está de acuerdo y lo que falta son datos.', '«Concertar» es ponerse de acuerdo con alguien. ¿Falta acuerdo o faltan nombre y fecha?', 2),
    ('despachar', false, 'register', '«Despachar» es coloquial y suena a resolver deprisa y de cualquier manera; Beatriz pide precisión, no velocidad.', '«Despachar» suena a quitarse algo de encima. ¿Ella quiere rapidez o quiere detalle?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'aa137fd4-e781-4d9c-a874-6dfd38faad9f',
    'a0000000-0000-4000-8000-000000000006',
    'Mi tío lleva un año diciendo que quiere montar un negocio, pero todavía no ha {{blank}} ni el producto ni el local.',
    'Sigue hablando en general: no ha fijado ningún dato exacto.',
    'Concretado: sigue sin fijar el producto ni el local. «Concertado» sería acordarlos con alguien, y «descartado» diría que ya los ha eliminado.',
    5
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('concertado', false, 'paronym', '«Concertar» es acordar algo con otra persona, y aquí no hay nadie con quien acordar: falta decidir qué vender y dónde.', '«Concertar» necesita otra parte. ¿Con quién se pondría de acuerdo tu tío?', 1),
    ('concretado', true, null, null, null, 2),
    ('descartado', false, 'near_synonym', '«Descartar» es dejar algo fuera, y tu tío no ha eliminado nada: todavía no ha elegido.', '«Descartar» quita opciones. ¿Tu tío ha quitado alguna o aún no ha elegido?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'a223302d-f1be-428b-b29c-fe03ebf731b0',
    'a0000000-0000-4000-8000-000000000006',
    'En la negociación, Víctor aceptó el precio y pasó a {{blank}} la fecha de entrega, la cantidad exacta y quién asumía el transporte.',
    'Pasa del acuerdo general a la fecha, la cantidad y el responsable.',
    'Concretar: fijar la fecha, la cantidad y el responsable. «Concertar» es ponerse de acuerdo con alguien, cosa que ya hicieron, y «estimar» sería calcular algo aproximado.',
    6
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('estimar', false, 'near_synonym', '«Estimar» es calcular una cifra aproximada, y aquí se cierran una fecha exacta y un responsable con nombre.', '«Estimar» deja margen. ¿La frase busca aproximarse o dejarlo cerrado?', 1),
    ('concertar', false, 'paronym', '«Concertar» es llegar a un acuerdo, y eso ya pasó al aceptar el precio; además nadie «concierta» quién asume el transporte.', '«Concertar» es cerrar un acuerdo entre partes. Relee: ¿qué acordaron ya?', 2),
    ('concretar', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '7f2f8609-5e91-4683-8678-b57c6891236e',
    'a0000000-0000-4000-8000-000000000006',
    'La convocatoria decía «nos vemos pronto», así que Ramiro escribió al grupo para {{blank}} la hora y el lugar exactos.',
    'Pasa de un «pronto» vago a una hora y un lugar exactos.',
    'Concretar: poner hora y lugar donde solo había un «pronto». «Concertar» es acordar algo con alguien, y «confirmar» supone una hora que todavía no existe.',
    7
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('confirmar', false, 'near_synonym', '«Confirmar» es dar por segura una hora que ya existe, y la convocatoria solo decía «pronto».', 'Para confirmar algo tiene que haber algo antes. ¿Qué hora daba la convocatoria?', 1),
    ('concretar', true, null, null, null, 2),
    ('concertar', false, 'paronym', '«Concertar» es acordar algo con otra parte, y Ramiro no negocia con nadie: escribe los datos que faltaban.', '«Concertar» supone una negociación. ¿Ramiro negocia o rellena los huecos?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '2a9f44ce-536d-415d-a2cf-ae4969e8f388',
    'a0000000-0000-4000-8000-000000000006',
    'Entre los tres {{blank}} el plan en una hora: quién llama, quién escribe y qué día se revisa todo.',
    'Convierten el plan en pasos con responsable y día.',
    'Concretamos: repartimos el plan en pasos con responsable y día. «Concertamos» sería acordarlo con otra parte, y «ampliamos» sería añadir más, no precisar.',
    8
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('ampliamos', false, 'near_synonym', '«Ampliar» es añadir más contenido, y aquí el plan no crece: se reparte en pasos exactos.', '«Ampliar» hace algo más grande. ¿El plan crece o se vuelve más preciso?', 1),
    ('concretamos', true, null, null, null, 2),
    ('concertamos', false, 'paronym', '«Concertar» es acordar algo con otra parte, y los tres ya están de acuerdo: lo que reparten son los pasos.', '«Concertar» necesita a alguien enfrente. ¿Con quién se acuerda algo en esta escena?', 3)
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
  'fuerza-de-la-afirmacion',
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

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'ae48c5e6-570a-4eb5-aabd-4a5b5e341916',
    'a0000000-0000-4000-8000-000000000007',
    'El cierre de la charla de Adriana fue tan {{blank}} que el público se quedó en silencio unos segundos antes de aplaudir.',
    'El final fue tan claro y firme que dejó a la sala sin nada que añadir.',
    'Contundente: el cierre no dejó lugar a dudas. «Brutal» es coloquial y suena a exageración entre amigos, y «contingente» describe lo que puede pasar o no.',
    4
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('brutal', false, 'register', '«Brutal» es un elogio coloquial y exagerado; en el cierre de una charla ante público suena fuera de lugar.', '«Brutal» es lenguaje de sobremesa entre amigos. ¿Encaja con una sala que escucha una charla?', 1),
    ('contundente', true, null, null, null, 2),
    ('contingente', false, 'paronym', '«Contingente» es lo que puede suceder o no, y ese cierre ya sucedió y dejó a la sala en silencio.', '«Contingente» habla de lo que quizá pase. ¿El cierre es una posibilidad o un hecho?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'd5bc7c32-8edd-4f39-b784-cdb087b01bd1',
    'a0000000-0000-4000-8000-000000000007',
    'Antes de aceptar la rebaja, Fernando puso sobre la mesa un informe con tres años de pedidos: un dato {{blank}} que cerró la negociación.',
    'El dato fue tan claro que nadie tuvo nada que responder.',
    'Contundente: el dato cerró la negociación sin réplica. «Contencioso» se usa para pleitos, y «convincente» se queda corto, porque persuade pero no cierra.',
    5
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('contencioso', false, 'paronym', '«Contencioso» se usa para disputas y pleitos, y este dato hace lo contrario: termina la discusión.', '«Contencioso» suena a pleito. ¿El informe abre una disputa o la cierra?', 1),
    ('convincente', false, 'near_synonym', '«Convincente» dice que el dato persuade, y la frase va más lejos: cierra la negociación sin réplica.', '«Convincente» persuade poco a poco. ¿Aquí queda margen para seguir discutiendo?', 2),
    ('contundente', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'c733f4cd-6f08-405b-ac21-8bbc7afaa6d2',
    'a0000000-0000-4000-8000-000000000007',
    'Mi abuela respondió con una frase {{blank}} cuando le preguntaron por qué seguía viviendo sola: «Porque puedo».',
    'Una frase corta y firme que no deja nada por responder.',
    'Contundente: la frase corta y firme no deja réplica. «Condescendiente» sería mirar por encima del hombro, y «escueta» solo habla de lo breve.',
    6
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('contundente', true, null, null, null, 1),
    ('condescendiente', false, 'paronym', '«Condescendiente» es tratar a alguien con aire de superioridad, y ella responde a una pregunta, no mira por encima del hombro.', 'Lo condescendiente ofende a quien escucha. ¿La abuela ofende o zanja la duda?', 2),
    ('escueta', false, 'near_synonym', '«Escueta» solo dice que la frase es corta, y lo que impresiona es que no deje nada por responder.', '«Escueta» mide el largo. ¿Lo que sorprende es que sea corta o que cierre el tema?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '1cb0470d-6842-411e-a4bf-5cf362c1ff84',
    'a0000000-0000-4000-8000-000000000007',
    'La prueba con veinte clientes dio un resultado {{blank}}: dieciocho eligieron el envase nuevo sin dudar.',
    'Dieciocho de veinte no deja lugar a dudas.',
    'Contundente: dieciocho de veinte no deja lugar a dudas. «Contingente» describe lo que puede pasar o no, y «discutible» diría justo lo contrario.',
    7
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('contingente', false, 'paronym', '«Contingente» es lo que puede suceder o no, y este resultado ya está medido con veinte clientes.', '«Contingente» habla de lo que quizá ocurra. ¿La prueba ya se hizo o está por hacerse?', 1),
    ('discutible', false, 'near_synonym', '«Discutible» diría que el resultado admite dudas, y dieciocho de veinte no las deja.', '«Discutible» abre debate. ¿Dieciocho de veinte deja mucho que debatir?', 2),
    ('contundente', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'c3632323-511b-47db-a1e0-0860005826e3',
    'a0000000-0000-4000-8000-000000000007',
    'Nadie volvió a insistir después de la respuesta {{blank}} que dio Olga en la reunión de vecinos.',
    'La respuesta fue tan firme que nadie quiso volver sobre el tema.',
    'Contundente: la respuesta fue tan firme que nadie insistió. «Condescendiente» sería tratar al grupo con superioridad, y «extensa» solo habla de longitud.',
    8
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('condescendiente', false, 'paronym', '«Condescendiente» es tratar a los demás con aire de superioridad, y eso suele provocar más réplicas, no menos.', 'Lo condescendiente molesta a quien escucha. ¿Los vecinos se molestaron o dejaron el tema?', 1),
    ('contundente', true, null, null, null, 2),
    ('extensa', false, 'near_synonym', '«Extensa» habla de longitud, y lo que acabó con la insistencia fue la firmeza, no el tamaño.', '«Extensa» mide cuánto dura. ¿Los vecinos callan por lo largo o por lo claro?', 3)
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

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '1302b585-9c26-4be8-99d0-ada4bceeecea',
    'a0000000-0000-4000-8000-000000000008',
    'Rosa escuchó a las dos partes y luego {{blank}} la discusión con una propuesta que las dos aceptaron.',
    'Puso fin a la discusión con una salida que convenció a todos.',
    'Zanjó: terminó la discusión con una propuesta aceptada. «Canjeó» es cambiar una cosa por otra, y «esquivó» sería evitar el tema en vez de resolverlo.',
    4
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('canjeó', false, 'paronym', '«Canjear» es cambiar una cosa por otra, como un vale por un producto; una discusión no se cambia, se termina.', '«Canjear» se usa con vales y entradas. ¿Se cambia aquí una cosa por otra?', 1),
    ('zanjó', true, null, null, null, 2),
    ('esquivó', false, 'near_synonym', '«Esquivar» es evitar un asunto, y Rosa hace lo contrario: escucha a las dos partes y propone una salida.', 'Quien esquiva un tema no lo toca. ¿Rosa lo evita o lo resuelve?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b98f1aa0-331a-4dcc-8746-eca5927ba4e4',
    'a0000000-0000-4000-8000-000000000008',
    'Tras dos correos y una llamada, Manuel decidió {{blank}} el asunto del alquiler con una sola reunión de quince minutos.',
    'Quiere dejar el asunto terminado de una vez, sin más idas y venidas.',
    'Zanjar: terminar el asunto de una vez en una reunión corta. «Canjear» es cambiar una cosa por otra, y «dilatar» sería alargarlo todavía más.',
    5
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('zanjar', true, null, null, null, 1),
    ('canjear', false, 'paronym', '«Canjear» es cambiar una cosa por otra, y aquí nadie intercambia nada: se cierra un asunto pendiente.', '«Canjear» se usa con vales y billetes. ¿Qué se cambiaría por qué en esta escena?', 2),
    ('dilatar', false, 'near_synonym', '«Dilatar» es alargar algo en el tiempo, y Manuel quiere terminarlo en quince minutos.', '«Dilatar» estira los plazos. ¿Quince minutos suenan a estirar o a cerrar?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'b3f2d467-2533-463b-8dd9-35423ed28c3b',
    'a0000000-0000-4000-8000-000000000008',
    'En casa {{blank}} el tema del reparto de gastos con una hoja compartida, y desde entonces nadie discute a fin de mes.',
    'Dejaron el tema terminado con una solución que sigue funcionando.',
    'Zanjamos: cerramos el tema con un acuerdo que dura. «Canjeamos» es cambiar una cosa por otra, y «despachamos» suena a resolverlo deprisa y sin ganas.',
    6
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('canjeamos', false, 'paronym', '«Canjear» es cambiar una cosa por otra, y una hoja compartida no se intercambia por nada: cierra una discusión.', '«Canjear» se usa con vales y entradas. ¿Qué se cambiaría aquí por qué?', 1),
    ('zanjamos', true, null, null, null, 2),
    ('despachamos', false, 'register', '«Despachar» es coloquial y suena a resolver algo deprisa y sin ganas; aquí el acuerdo aguanta mes tras mes.', '«Despachar» es quitarse algo de encima. ¿Encaja con una solución que dura?', 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    'bbf315cc-93c8-4975-bfaa-dab252854337',
    'a0000000-0000-4000-8000-000000000008',
    'Cuando la charla se repetía por tercera vez, Susana propuso {{blank}}: «Decidimos hoy y no lo volvemos a abrir».',
    'Propone cerrar el asunto hoy y no volver sobre él.',
    'Zanjarlo: decidir hoy y no volver a abrirlo. «Canjearlo» es cambiar una cosa por otra, y «aplazarlo» sería dejarlo para otro día.',
    7
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('aplazarlo', false, 'near_synonym', '«Aplazar» es dejar algo para más tarde, y su propuesta dice justo lo contrario: decidir hoy.', 'Relee la propuesta: «Decidimos hoy». ¿Eso deja algo para otro día?', 1),
    ('canjearlo', false, 'paronym', '«Canjear» es cambiar una cosa por otra, y un asunto que se repite no se cambia: se termina.', '«Canjear» se usa con vales y entradas. ¿Hay algo que cambiar en esta charla?', 2),
    ('zanjarlo', true, null, null, null, 3)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);

with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values (
    '5e8e844c-76ef-4d72-8f72-a299bb2a566c',
    'a0000000-0000-4000-8000-000000000008',
    'El acuerdo firmado por las dos empresas {{blank}} una disputa que llevaba tres años abierta.',
    'El acuerdo puso final a algo que llevaba años sin resolverse.',
    'Zanjó: el acuerdo puso fin a la disputa. «Canjeó» es cambiar una cosa por otra, y «prolongó» diría que la alargó todavía más.',
    8
  )
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('canjeó', false, 'paronym', '«Canjear» es cambiar una cosa por otra, y una disputa de tres años no se intercambia: se termina.', '«Canjear» se usa con vales y entradas. ¿Se cambia algo por otra cosa en esta frase?', 1),
    ('prolongó', false, 'near_synonym', '«Prolongar» es alargar algo, y el acuerdo hace lo contrario: le pone final a tres años de disputa.', '«Prolongar» estira. ¿Un acuerdo firmado alarga la disputa o la acaba?', 2),
    ('zanjó', true, null, null, null, 3)
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

-- ----------------------------------------------------------------------------
-- Word themes (content/words/<slug>.yml)
-- ----------------------------------------------------------------------------

insert into public.word_themes (word_id, theme_id, relevance, sort_order)
select w.id, t.id, v.relevance, w.sort_order
from (values
  ('perspicaz', 'elogio-reconocimiento', 3),
  ('perspicaz', 'reuniones', 2),
  ('perspicaz', 'matices-precision', 1),
  ('plantear', 'reuniones', 3),
  ('plantear', 'conversaciones-dificiles', 2),
  ('plantear', 'correos-mensajes', 2),
  ('matizar', 'matices-precision', 3),
  ('matizar', 'conflicto-desacuerdo', 2),
  ('matizar', 'reuniones', 2),
  ('sopesar', 'negociacion', 3),
  ('sopesar', 'entrevistas', 2),
  ('sopesar', 'liderazgo-feedback', 1),
  ('pertinente', 'entrevistas', 3),
  ('pertinente', 'reuniones', 2),
  ('pertinente', 'redaccion-ejecutiva', 2),
  ('concretar', 'reuniones', 3),
  ('concretar', 'redaccion-ejecutiva', 2),
  ('concretar', 'negociacion', 2),
  ('contundente', 'persuasion-storytelling', 3),
  ('contundente', 'presentaciones-oratoria', 2),
  ('contundente', 'negociacion', 2),
  ('zanjar', 'conflicto-desacuerdo', 3),
  ('zanjar', 'negociacion', 2),
  ('zanjar', 'reuniones', 1)
) as v (word_slug, theme_slug, relevance)
join public.words w on w.slug = v.word_slug
join public.themes t on t.slug = v.theme_slug
on conflict (word_id, theme_id) do update
  set relevance = excluded.relevance,
      sort_order = excluded.sort_order;
