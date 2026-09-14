import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/themes/data/fake/seed_themes.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/domain/theme_repository.dart';

/// The taxonomy of `supabase/seed_themes.sql`, in memory.
final class FakeThemeRepository with FakeRemote implements ThemeRepository {
  new({this.themes = seedThemes, this.latency = Duration.zero});

  final List<Theme> themes;

  @override
  final Duration latency;

  @override
  Future<Result<List<Theme>>> fetchThemes() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    return Result.ok(
      [...themes]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }
}
