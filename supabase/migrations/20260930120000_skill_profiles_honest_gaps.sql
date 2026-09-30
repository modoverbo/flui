-- Aligns public.skill_profiles' constraints with the domain's honest
-- "no fabrication" rule (DiagnosisProfiler / SkillProfile):
--
--   * strengths come only from areas other than top/second (design part-3
--     §7) — an all-opportunity diagnosis legitimately has none, so an empty
--     array must be accepted, not just a non-empty one.
--   * top_behavior/second_behavior are null whenever their ranked area had
--     zero opportunities across all 3 attempts — legitimate, not a bug.
--
-- Before this migration, both were over-constrained (strengths required at
-- least 1 entry, top_behavior/second_behavior were NOT NULL), so a real
-- diagnosis session matching either shape could never close: every insert
-- failed the same way, trapping the user on a "no pudimos guardar"/retry
-- loop with no way to recover (production bug, see fix/diagnosis-profile-save).

alter table public.skill_profiles
  alter column top_behavior drop not null,
  alter column second_behavior drop not null;

alter table public.skill_profiles
  drop constraint skill_profiles_top_behavior_check,
  add constraint skill_profiles_top_behavior_check
    check (top_behavior is null or btrim(top_behavior) <> '');

alter table public.skill_profiles
  drop constraint skill_profiles_second_behavior_check,
  add constraint skill_profiles_second_behavior_check
    check (second_behavior is null or btrim(second_behavior) <> '');

alter table public.skill_profiles
  drop constraint skill_profiles_strengths_check,
  add constraint skill_profiles_strengths_check
    check (jsonb_typeof(strengths) = 'array');

comment on column public.skill_profiles.top_behavior is 'BehaviorCode wire code, or null when the top area had zero observed opportunities; free text, catalog parity is enforced outside the database.';
comment on column public.skill_profiles.second_behavior is 'BehaviorCode wire code, or null when the second area had zero observed opportunities; free text, catalog parity is enforced outside the database.';
comment on column public.skill_profiles.strengths is 'BehaviorCode wire codes from areas other than top/second; may be empty when every observation was an opportunity.';
