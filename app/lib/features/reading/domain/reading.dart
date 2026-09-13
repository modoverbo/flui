import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading.freezed.dart';

/// Where a reading happens (`readings.scene`).
enum Scene { trabajo, social, entrevista, familia }

/// Duhigg's conversation type (`readings.conversation_type`).
enum ConversationType { practica, emocional, social }

/// A short scene that shows a word in context ("Mira").
@freezed
abstract class Reading with _$Reading {
  const factory({
    required String id,
    required String wordId,
    required Scene scene,
    required ConversationType conversationType,
    required String title,
    required String body,
    required String beforePhrase,
    required String afterPhrase,
    required int position,
  }) = _Reading;
}
