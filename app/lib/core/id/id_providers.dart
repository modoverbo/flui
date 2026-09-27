import 'package:flui/core/id/id_generator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'id_providers.g.dart';

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => const UuidV4Generator();
