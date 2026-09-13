import 'package:content/src/model/yaml_map.dart';

const themeFamilies = <String>{
  'trabajo',
  'social',
  'publico',
  'precision',
  'emocion',
};

const themeContentTypes = <String>{
  'word_driven',
  'expression_driven',
  'mixed',
};

final class Theme {
  const Theme({
    required this.slug,
    required this.family,
    required this.name,
    required this.tagline,
    required this.jtbd,
    required this.contentType,
    required this.sortOrder,
  });

  factory Theme.fromMap(Map<String, Object?> map) => Theme(
    slug: map['slug']! as String,
    family: map['family']! as String,
    name: map['name']! as String,
    tagline: map['tagline']! as String,
    jtbd: map['jtbd']! as String,
    contentType: map['content_type']! as String,
    sortOrder: map['sort_order']! as int,
  );

  final String slug;
  final String family;
  final String name;
  final String tagline;
  final String jtbd;
  final String contentType;
  final int sortOrder;

  /// Every piece of user-facing copy, for the brand checks.
  Iterable<String> get copy => [name, tagline, jtbd];
}

final class ThemeTaxonomy {
  ThemeTaxonomy(this.themes)
    : _bySlug = {for (final theme in themes) theme.slug: theme};

  factory ThemeTaxonomy.parse(String yaml) {
    final root = loadYamlAsPlain(yaml)! as Map<String, Object?>;
    final raw = (root['themes']! as List<Object?>).cast<Map<String, Object?>>();
    return ThemeTaxonomy([for (final map in raw) Theme.fromMap(map)]);
  }

  final List<Theme> themes;
  final Map<String, Theme> _bySlug;

  Set<String> get slugs => _bySlug.keys.toSet();

  Theme? bySlug(String slug) => _bySlug[slug];
}
