import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_progress_repository.dart';

/// In-memory `word_progress`, one table per user.
final class FakeWordProgressRepository
    with FakeRemote
    implements WordProgressRepository {
  new({required this.currentUserId, this.latency = Duration.zero});

  final String? Function() currentUserId;

  @override
  final Duration latency;

  final _rows = <String, Map<String, WordProgress>>{};

  @override
  Future<Result<List<WordProgress>>> fetchProgress() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    return Result.ok([...?_rows[userId]?.values]);
  }

  @override
  Future<Result<void>> saveProgress(WordProgress progress) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    _rows.putIfAbsent(userId, () => {})[progress.wordId] = progress;
    return const Result.ok(null);
  }
}
