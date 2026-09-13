import 'package:flui/features/profile/data/fake_streak_repair_repository.dart';
import 'package:flui/features/profile/data/supabase_streak_repair_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';
import '../../../helpers/supabase_recorder.dart';

void main() {
  test('FakeStreakRepairRepository stores distinct dates per user', () async {
    final repository = FakeStreakRepairRepository(currentUserId: () => 'a');
    await repository.repairDay(day(15));
    await repository.repairDay(day(15));
    await repository.repairDay(day(3));

    expect((await repository.fetchRepairs()).valueOrNull, [day(3), day(15)]);
  });

  test('SupabaseStreakRepairRepository reads and inserts dates', () async {
    final recorder = SupabaseRecorder(
      respond: (request) => request.method == 'GET'
          ? [
              {'repaired_date': '2026-09-15'},
            ]
          : null,
    );
    addTearDown(recorder.dispose);
    final repository = SupabaseStreakRepairRepository(
      recorder.client,
      currentUserId: () => 'u1',
    );

    expect((await repository.fetchRepairs()).valueOrNull, [day(15)]);
    await repository.repairDay(day(16));

    expect(recorder.last.url.path, '/rest/v1/streak_repairs');
    expect(recorder.bodyOf(recorder.last), {
      'user_id': 'u1',
      'repaired_date': '2026-09-16',
    });
  });
}
