import 'package:yaml/yaml.dart';

/// Parses YAML and returns the raw document value (still `YamlMap`/`YamlList`).
Object? loadYamlDocumentValue(String source) => loadYaml(source);

/// Converts the `yaml` package's views into plain `Map<String, Object?>` and
/// `List<Object?>`, so the rest of the toolkit never depends on `YamlMap`.
Object? deepConvertYaml(Object? node) {
  if (node is YamlMap) {
    return <String, Object?>{
      for (final entry in node.nodes.entries)
        entry.key.toString(): deepConvertYaml(entry.value.value),
    };
  }
  if (node is Map) {
    return <String, Object?>{
      for (final entry in node.entries)
        entry.key.toString(): deepConvertYaml(entry.value),
    };
  }
  if (node is YamlList) {
    return <Object?>[for (final item in node) deepConvertYaml(item)];
  }
  if (node is List) {
    return <Object?>[for (final item in node) deepConvertYaml(item)];
  }
  return node;
}

/// Loads a YAML document into plain Dart collections in one step.
Object? loadYamlAsPlain(String source) =>
    deepConvertYaml(loadYamlDocumentValue(source));
