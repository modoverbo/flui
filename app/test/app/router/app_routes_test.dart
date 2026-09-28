import 'dart:io';

import 'package:flui/app/router/app_redirect.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/auth/domain/auth_status.dart';
import 'package:flui/features/daily/domain/daily_gate.dart';
import 'package:flui/features/subscription/domain/access_gate.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('retired speaking-challenge deep links redirect to train (U16)', () {
    test('retiredRoutes maps both old paths to train, never dropping them', () {
      expect(
        AppRoutes.retiredRoutes[AppRoutes.speakingChallenge],
        AppRoutes.train,
      );
      expect(
        AppRoutes.retiredRoutes[AppRoutes.speakingChallengeLive],
        AppRoutes.train,
      );
    });

    test(
      'a granted, signed-in visit to either old path redirects, never 404s',
      () {
        for (final oldPath in [
          AppRoutes.speakingChallenge,
          AppRoutes.speakingChallengeLive,
        ]) {
          final result = appRedirect(
            auth: AuthStatus.signedIn,
            access: AccessGate.granted,
            daily: DailyGate.planned,
            location: Uri.parse(oldPath),
          );

          expect(result, AppRoutes.train, reason: 'redirecting $oldPath');
        }
      },
    );
  });

  group('training-lab mode routes', () {
    test('trainMode builds one path per mode, nested under train', () {
      for (final mode in TrainingMode.values) {
        expect(AppRoutes.trainMode(mode), '${AppRoutes.train}/${mode.name}');
      }
    });

    test(
      'the /train/:mode loop route is a branch child (no root-navigator '
      'take-over), unlike the retired speakingChallengeLive (design D30)',
      () {
        final source = File('lib/app/router/app_router.dart')
            .readAsStringSync();
        final trainBranchStart = source.indexOf('path: AppRoutes.train,');
        final trainBranchEnd = source.indexOf(
          'StatefulShellBranch',
          trainBranchStart,
        );
        expect(trainBranchStart, greaterThan(-1));
        final trainBranchSource = source.substring(
          trainBranchStart,
          trainBranchEnd == -1 ? source.length : trainBranchEnd,
        );

        expect(
          trainBranchSource.contains('parentNavigatorKey'),
          isFalse,
          reason:
              'the ENTRENAR branch (its /train landing and /train/:mode '
              'loop) must have no parentNavigatorKey — both stay on the '
              'branch navigator, never a root-navigator take-over',
        );
      },
    );
  });
}
