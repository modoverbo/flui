import 'package:flui/core/error/failure.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/diagnosis/data/fake_skill_profile_repository.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/diagnosis/presentation/diagnosis_gate.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_container.dart';

const _user = AppUser(id: 'u1', email: 'a@flui.dev', displayName: 'Ana');

const _profile = SkillProfile(
  topArea: SkillArea.thinking,
  secondArea: SkillArea.language,
  strengths: <BehaviorCode>[],
  evidence: <DiagnosisEvidence>[],
);

void main() {
  late FakeAuthRepository auth;
  late FakeSkillProfileRepository profiles;
  late ProviderContainer container;

  ProviderContainer buildContainer({AppUser? initialUser}) {
    auth = FakeAuthRepository(initialUser: initialUser);
    profiles = FakeSkillProfileRepository(currentUserId: () => initialUser?.id);
    container = createTestContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        skillProfileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  void keepAlive(ProviderListenable<Object?> provider) =>
      container.listen(provider, (_, _) {}, fireImmediately: true);

  test('unknown while the signed-in user id is not known yet', () {
    buildContainer();
    keepAlive(diagnosisGateProvider);

    expect(container.read(diagnosisGateProvider), DiagnosisGate.unknown);
  });

  test('required once signed in with no profile yet', () async {
    buildContainer(initialUser: _user);
    keepAlive(diagnosisGateProvider);
    await container.read(authUserProvider.future);

    await container.read(latestSkillProfileProvider(_user.id).future);

    expect(container.read(diagnosisGateProvider), DiagnosisGate.required);
  });

  test('completed once a profile exists', () async {
    buildContainer(initialUser: _user);
    await profiles.save(sessionId: 's1', profile: _profile);
    keepAlive(diagnosisGateProvider);
    await container.read(authUserProvider.future);

    await container.read(latestSkillProfileProvider(_user.id).future);

    expect(container.read(diagnosisGateProvider), DiagnosisGate.completed);
  });

  test('error when the profile lookup fails', () async {
    buildContainer(initialUser: _user);
    profiles.nextFailure = const NetworkFailure();
    keepAlive(diagnosisGateProvider);
    await container.read(authUserProvider.future);

    await expectLater(
      container.read(latestSkillProfileProvider(_user.id).future),
      throwsA(const NetworkFailure()),
    );

    expect(container.read(diagnosisGateProvider), DiagnosisGate.error);
  });

  test(
    'publish flips the gate to completed without a network round-trip',
    () async {
      buildContainer(initialUser: _user);
      keepAlive(diagnosisGateProvider);
      await container.read(authUserProvider.future);
      await container.read(latestSkillProfileProvider(_user.id).future);
      expect(container.read(diagnosisGateProvider), DiagnosisGate.required);

      container
          .read(latestSkillProfileProvider(_user.id).notifier)
          .publish(
            SkillProfileRecord(
              id: 's1',
              kind: SkillProfileKind.baseline,
              diagnosedAt: DateTime(2026, 9, 28),
              profile: _profile,
            ),
          );

      expect(container.read(diagnosisGateProvider), DiagnosisGate.completed);
    },
  );
}
