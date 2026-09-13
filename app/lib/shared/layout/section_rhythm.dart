/// The tone of a full-bleed page section.
enum SectionTone { cream, green }

/// The rhythm of a long page: cream, then a full-bleed green plate, then
/// cream again. Three cream sections in a row read as a form, not a page,
/// so the pattern never allows more than [maxCreamRun] of them.
const int maxCreamRun = 2;

/// The tone of section [index].
SectionTone sectionToneAt(int index) {
  assert(index >= 0, 'sections are indexed from zero');
  return index % 3 == 1 ? SectionTone.green : SectionTone.cream;
}

/// Tones for a page of [count] sections.
List<SectionTone> sectionRhythm(int count) => [
  for (var index = 0; index < count; index++) sectionToneAt(index),
];
