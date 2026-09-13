import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flui/features/vocabulary/domain/content_repository.dart';
import 'package:flui/features/vocabulary/domain/word.dart';

/// The words of `supabase/seed.sql`, in memory.
final class FakeContentRepository with FakeRemote implements ContentRepository {
  new({this.words = seedWords, this.latency = Duration.zero});

  final List<Word> words;

  @override
  final Duration latency;

  @override
  Future<Result<List<Word>>> fetchCatalog() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    return Result.ok(
      [...words]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }
}
