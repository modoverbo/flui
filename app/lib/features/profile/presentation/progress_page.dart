import 'dart:async';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/audio/audio_providers.dart';
import 'package:flui/core/audio/speech_player.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/formatters.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/auth/presentation/controllers/sign_out_controller.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/domain/diagnosis_resume_policy.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/profile/domain/before_now_audio.dart';
import 'package:flui/features/profile/domain/progress_evidence.dart';
import 'package:flui/features/profile/domain/progress_stats.dart';
import 'package:flui/features/profile/domain/streak_calculator.dart';
import 'package:flui/features/profile/presentation/providers/account_deletion_controller.dart';
import 'package:flui/features/profile/presentation/providers/progress_evidence_overview.dart';
import 'package:flui/features/profile/presentation/providers/progress_overview.dart';
import 'package:flui/features/profile/presentation/subscription_summary.dart';
import 'package:flui/features/profile/presentation/widgets/achievement_tile.dart';
import 'package:flui/features/profile/presentation/widgets/week_dots.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/features/training/domain/retake_policy.dart';
import 'package:flui/features/training/presentation/behavior_code_copy.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/shared/widgets/editorial_stat.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flui/shared/widgets/page_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// "Tu progreso": training progress, not a spreadsheet. The week and the
/// streak leads, editorial numbers follow, then achievements as cards, the
/// plan and the way out — on the same paper surface as the rest of the app.
class ProgressPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = context.layout;
    final user = ref.watch(authUserProvider).value;
    final access = ref.watch(currentAccessProvider);
    final signingOut = ref.watch(signOutControllerProvider);
    final overview = ref.watch(progressOverviewProvider);
    final name = user?.displayName;

    return Scaffold(
      backgroundColor: FluiColors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: layout.blockGap),
                PageHeader(
                  title: l10n.progressTitle,
                  subtitle: name == null || name.trim().isEmpty
                      ? l10n.progressGreetingAnonymous
                      : l10n.progressGreeting(name),
                ),
                SizedBox(height: layout.blockGap),
                // The speaking-evidence view (trends, then-vs-now playback,
                // audio settings, retake) is PRIMARY content per spec
                // `progress`: it renders ABOVE the streak/stats/achievements
                // gamification block below, which stays exactly as-is and
                // becomes visually secondary. Only ever built while the
                // flag is on (production safety, U14c's established
                // pattern): flag-off never watches any of its dependent
                // providers.
                if (ref.watch(speakingGymEnabledProvider)) ...[
                  const _EvidenceSection(),
                  SizedBox(height: layout.sectionGap),
                ],
                switch (overview) {
                  AsyncValue(hasValue: true, :final value?) => _ProgressContent(
                    overview: value,
                  ),
                  AsyncError() => Text(
                    l10n.todayLoadError,
                    style: layout.type.bodyL.copyWith(color: FluiColors.gray),
                  ),
                  _ => Center(
                    child: LoadingWave(semanticLabel: l10n.commonLoading),
                  ),
                },
                SizedBox(height: layout.sectionGap),
                SectionHeader(
                  title: l10n.progressAccountTitle,
                  glyph: const FluiGlyphIcon(FluiGlyph.goal),
                ),
                FluiCard(
                  child: Text(
                    subscriptionSummary(l10n, access),
                    style: layout.type.bodyL.copyWith(color: FluiColors.ink),
                  ),
                ),
                // Only ever built while the flag is on: flag-off never
                // watches `speakingGymEnabledProvider`'s dependents, so
                // production (flag off) makes no new diagnosis queries and
                // shows no diagnosis entry here (U14c).
                if (ref.watch(speakingGymEnabledProvider)) ...[
                  SizedBox(height: layout.blockGap),
                  const _DiagnosisResumeEntry(),
                ],
                SizedBox(height: layout.blockGap),
                FluiButton.outline(
                  label: l10n.progressSignOut,
                  isLoading: signingOut,
                  onPressed: () => unawaited(
                    ref.read(signOutControllerProvider.notifier).signOut(),
                  ),
                ),
                SizedBox(height: layout.sectionGap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressContent extends ConsumerWidget {
  const new({required this.overview});

  final ProgressOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = context.layout;
    final type = layout.type;
    final streak = overview.streak;
    final repairable = streak.repairableDate;
    final repairAfter = streak.streakAfterRepair;
    final repairing = ref.watch(streakRepairControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressStreakBlock(streak: streak),
        SizedBox(height: layout.sectionGap),
        SectionHeader(
          title: l10n.progressStatsTitle,
          glyph: const FluiGlyphIcon(FluiGlyph.goal),
        ),
        _ProgressNumbers(stats: overview.stats),
        if (repairable != null && repairAfter != null) ...[
          SizedBox(height: layout.blockGap),
          FluiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.progressRepairOffer(
                    formatLongDate(repairable.toDateTime()),
                    repairAfter,
                  ),
                  style: type.body.copyWith(color: FluiColors.gray),
                ),
                const SizedBox(height: FluiSpacing.md),
                FluiButton.accent(
                  label: l10n.progressRepairAction,
                  isLoading: repairing,
                  onPressed: () => unawaited(
                    ref
                        .read(streakRepairControllerProvider.notifier)
                        .repair(repairable),
                  ),
                ),
              ],
            ),
          ),
        ] else if (streak.repairUsedThisWeek) ...[
          SizedBox(height: layout.blockGap),
          Text(
            l10n.progressRepairUsed,
            style: type.body.copyWith(color: FluiColors.gray),
          ),
        ],
        SizedBox(height: layout.sectionGap),
        SectionHeader(
          title: l10n.progressAchievementsTitle,
          glyph: const FluiGlyphIcon(FluiGlyph.achievement),
        ),
        for (final achievement in overview.achievements) ...[
          AchievementTile(achievement: achievement),
          const SizedBox(height: FluiSpacing.xs),
        ],
      ],
    );
  }
}

/// The week and the streak: the page's one editorial hero, not a cell in a
/// grid of identical stat boxes.
class _ProgressStreakBlock extends StatelessWidget {
  const new({required this.streak});

  final StreakSummary streak;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return FluiCard(
      color: FluiColors.aqua,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const FluiGlyphIcon(FluiGlyph.streak, color: FluiColors.ink),
              const SizedBox(width: FluiSpacing.xs),
              Expanded(child: FluiLabel(l10n.progressBentoTitle)),
            ],
          ),
          const SizedBox(height: FluiSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              // Has a zero case of its own: "Tu racha empieza con tu próxima
              // sesión".
              l10n.progressStreak(streak.currentStreak),
              style: type.displayL.copyWith(color: FluiColors.ink),
            ),
          ),
          const SizedBox(height: FluiSpacing.xs),
          Text(
            l10n.progressWeekDays(streak.activeDaysThisWeek),
            style: type.body.copyWith(color: FluiColors.ink),
          ),
          const SizedBox(height: FluiSpacing.md),
          Semantics(
            explicitChildNodes: true,
            child: WeekDots(activeDays: streak.weekDays, onDark: false),
          ),
        ],
      ),
    );
  }
}

/// Días activos, palabras tuyas, en práctica y precisión — editorial
/// numerals, not a KPI tile grid (`docs/redesign/01-design-system.md` §2).
///
/// `ProgressStats` has no notion of speaking-attempt counts (the speaking
/// feature records single attempts but nothing aggregates them into the
/// learning data this provider reads), so "intentos de habla" is not one of
/// the numbers here — see the implementation report.
class _ProgressNumbers extends StatelessWidget {
  const new({required this.stats});

  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final precision = stats.firstTryPrecisionPercent;
    return Wrap(
      spacing: FluiSpacing.xl,
      runSpacing: FluiSpacing.lg,
      children: [
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: '${stats.activeDays}',
            label: l10n.statActiveDays,
          ),
        ),
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: '${stats.tuya}',
            label: l10n.statOwnedWords,
          ),
        ),
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: '${stats.practica}',
            label: l10n.statPracticeWords,
          ),
        ),
        SizedBox(
          width: 150,
          child: EditorialStat(
            value: precision == null
                ? l10n.commonNoData
                : l10n.statPrecisionValue(precision),
            label: l10n.statPrecisionLabel,
            caption: l10n.statPrecisionWindow,
          ),
        ),
      ],
    );
  }
}

/// PROGRESO's paused-retake entry point (design §10, U14c): shown only
/// while an open (unanswered/unclosed) diagnosis session already exists —
/// only reachable here once the gate is `completed` (a retake in
/// progress), since a `required` baseline blocks navigation to this page
/// entirely. Starting a brand-new retake (when none is in progress) is a
/// later unit's entry point (U18b); this is resume-only.
class _DiagnosisResumeEntry extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final resume = ref.watch(diagnosisResumeProvider).value;
    if (resume is! DiagnosisResume) return const SizedBox.shrink();
    return FluiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.progressDiagnosisResumeTitle),
          const SizedBox(height: FluiSpacing.sm),
          FluiButton.outline(
            label: l10n.progressDiagnosisResumeAction,
            onPressed: () => context.go('${AppRoutes.diagnosisLive}?retake=1'),
          ),
        ],
      ),
    );
  }
}

/// PROGRESO's speaking-evidence view (U18b): per-skill before→now trends,
/// then-vs-now playback, audio settings and the retake entry — spec
/// `progress`'s primary content while the flag is on.
class _EvidenceSection extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = context.layout;
    final overview = ref.watch(progressEvidenceOverviewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.progressEvidenceTitle,
          glyph: const FluiGlyphIcon(FluiGlyph.goal),
        ),
        switch (overview) {
          AsyncValue(hasValue: true, :final value?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TrendsCard(beforeNow: value.evidence.beforeNow),
              SizedBox(height: layout.blockGap),
              _PlaybackCard(audio: value.audio),
              SizedBox(height: layout.blockGap),
              const _AudioSettingsCard(),
            ],
          ),
          AsyncError() => Text(
            l10n.todayLoadError,
            style: layout.type.bodyL.copyWith(color: FluiColors.gray),
          ),
          _ => Center(child: LoadingWave(semanticLabel: l10n.commonLoading)),
        },
        SizedBox(height: layout.blockGap),
        const _RetakeEntry(),
        SizedBox(height: layout.blockGap),
        const _AccountDeletionCard(),
      ],
    );
  }
}

/// Per-skill trend breakdown (spec `progress`: "per-skill trend
/// breakdowns", never a numeric confidence or aggregate score).
class _TrendsCard extends StatelessWidget {
  const new({required this.beforeNow});

  final BeforeNow beforeNow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    return switch (beforeNow) {
      BeforeNowInsufficientEvidence() => FluiCard(
        child: Text(
          l10n.progressBeforeNowInsufficientEvidence,
          style: layout.type.body.copyWith(color: FluiColors.gray),
        ),
      ),
      BeforeNowComparison(:final label, :final trends) => FluiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label == BeforeNowLabel.formal
                  ? l10n.progressBeforeNowLabelFormal
                  : l10n.progressBeforeNowLabelIndicative,
              style: layout.type.body.copyWith(color: FluiColors.gray),
            ),
            for (final trend in trends) ...[
              const SizedBox(height: FluiSpacing.md),
              _TrendTile(trend: trend),
            ],
          ],
        ),
      ),
    };
  }
}

class _TrendTile extends StatelessWidget {
  const new({required this.trend});

  final SkillTrend trend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          skillAreaLine(l10n, trend.area),
          style: layout.type.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: FluiSpacing.xs),
        switch (trend) {
          SkillTrendInsufficientEvidence() => Text(
            l10n.progressTrendInsufficientEvidence,
            style: layout.type.body.copyWith(color: FluiColors.gray),
          ),
          SkillTrendComputed(:final direction, :final evidence) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_directionLabel(l10n, direction)),
              for (final line in evidence)
                Text(
                  '• ${behaviorCodeLine(l10n, line.code)}',
                  style: layout.type.body.copyWith(color: FluiColors.gray),
                ),
            ],
          ),
        },
      ],
    );
  }

  String _directionLabel(AppLocalizations l10n, TrendDirection direction) =>
      switch (direction) {
        TrendDirection.improving => l10n.progressTrendImproving,
        TrendDirection.steady => l10n.progressTrendSteady,
        TrendDirection.needsWork => l10n.progressTrendNeedsWork,
      };
}

/// Then-vs-now playback (spec `audio-capture-playback`, `progress`): two
/// play buttons using signed URLs via `SpeechPlayer.playUrl`, or an
/// explicit "unavailable" statement — never a broken/stalled player.
class _PlaybackCard extends ConsumerStatefulWidget {
  const new({required this.audio});

  final BeforeNowAudio audio;

  @override
  ConsumerState<_PlaybackCard> createState() => _PlaybackCardState();
}

class _PlaybackCardState extends ConsumerState<_PlaybackCard> {
  late final SpeechPlayer _player;
  StreamSubscription<PlaybackStatus>? _subscription;
  PlaybackStatus _status = PlaybackStatus.idle;
  String? _activeAttemptId;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _player = ref.read(speechPlayerFactoryProvider)();
    _subscription = _player.status.listen((status) {
      if (!mounted) return;
      setState(() {
        _status = status;
        if (status == PlaybackStatus.failed) _showError = true;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle({
    required String attemptId,
    required String path,
  }) async {
    if (_activeAttemptId == attemptId &&
        (_status == PlaybackStatus.playing ||
            _status == PlaybackStatus.loading)) {
      await _player.stop();
      return;
    }
    setState(() {
      _activeAttemptId = attemptId;
      _showError = false;
    });
    final urlResult = await ref
        .read(attemptAudioStoreProvider)
        .signedUrlFor(path: path);
    if (!mounted) return;
    switch (urlResult) {
      case Ok(:final value):
        await _player.playUrl(value);
      case Err():
        setState(() => _showError = true);
    }
  }

  Future<void> _delete(String attemptId) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.audioSettingsDeleteOneConfirmTitle),
        content: Text(l10n.audioSettingsDeleteOneConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.audioSettingsCancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.audioSettingsConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref
        .read(audioDeletionControllerProvider.notifier)
        .deleteOne(attemptId);
    if (!mounted) return;
    if (result case Err()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.audioSettingsErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final audio = widget.audio;
    final deleting = ref.watch(audioDeletionControllerProvider);

    return FluiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.progressPlaybackTitle,
            style: layout.type.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: FluiSpacing.sm),
          switch (audio) {
            BeforeNowAudioUnavailable() => Text(
              l10n.progressPlaybackUnavailable,
              style: layout.type.body.copyWith(color: FluiColors.gray),
            ),
            BeforeNowAudioAvailable(
              :final beforeAttemptId,
              :final beforePath,
              :final nowAttemptId,
              :final nowPath,
            ) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PlaybackRow(
                    label: l10n.progressPlaybackBeforeAction,
                    stopLabel: l10n.progressPlaybackStop,
                    deleteLabel: l10n.audioSettingsDeleteOneAction,
                    isActive: _activeAttemptId == beforeAttemptId,
                    isBusy:
                        _activeAttemptId == beforeAttemptId &&
                        _status == PlaybackStatus.loading,
                    isDeleting: deleting,
                    onToggle: () => unawaited(
                      _toggle(attemptId: beforeAttemptId, path: beforePath),
                    ),
                    onDelete: () => unawaited(_delete(beforeAttemptId)),
                  ),
                  const SizedBox(height: FluiSpacing.sm),
                  _PlaybackRow(
                    label: l10n.progressPlaybackNowAction,
                    stopLabel: l10n.progressPlaybackStop,
                    deleteLabel: l10n.audioSettingsDeleteOneAction,
                    isActive: _activeAttemptId == nowAttemptId,
                    isBusy:
                        _activeAttemptId == nowAttemptId &&
                        _status == PlaybackStatus.loading,
                    isDeleting: deleting,
                    onToggle: () => unawaited(
                      _toggle(attemptId: nowAttemptId, path: nowPath),
                    ),
                    onDelete: () => unawaited(_delete(nowAttemptId)),
                  ),
                  if (_showError) ...[
                    const SizedBox(height: FluiSpacing.sm),
                    Text(
                      l10n.progressPlaybackError,
                      style: layout.type.body.copyWith(color: FluiColors.gray),
                    ),
                  ],
                ],
              ),
          },
        ],
      ),
    );
  }
}

class _PlaybackRow extends StatelessWidget {
  const new({
    required this.label,
    required this.stopLabel,
    required this.deleteLabel,
    required this.isActive,
    required this.isBusy,
    required this.isDeleting,
    required this.onToggle,
    required this.onDelete,
  });

  final String label;
  final String stopLabel;
  final String deleteLabel;
  final bool isActive;
  final bool isBusy;
  final bool isDeleting;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluiButton.outline(
          label: isActive ? stopLabel : label,
          isLoading: isBusy,
          onPressed: onToggle,
        ),
        FluiButton.text(
          label: deleteLabel,
          isLoading: isDeleting,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// Consent toggle + bulk deletion (spec `speaking-attempt-history`: consent
/// revocation only stops FUTURE retention; deletion is a separate,
/// explicit action).
class _AudioSettingsCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = context.layout;
    final consent = ref.watch(audioConsentProvider);
    final granted = consent.value ?? false;
    final saving = ref.watch(audioConsentControllerProvider);
    final deleting = ref.watch(audioDeletionControllerProvider);

    return FluiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.audioSettingsTitle,
            style: layout.type.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: FluiSpacing.sm),
          Text(
            granted
                ? l10n.audioSettingsConsentOnDescription
                : l10n.audioSettingsConsentOffDescription,
            style: layout.type.body.copyWith(color: FluiColors.gray),
          ),
          const SizedBox(height: FluiSpacing.sm),
          FluiButton.outline(
            label: granted
                ? l10n.audioSettingsConsentDisableAction
                : l10n.audioSettingsConsentEnableAction,
            isLoading: saving,
            onPressed: () =>
                unawaited(_toggleConsent(context, ref, granted: granted)),
          ),
          const SizedBox(height: FluiSpacing.sm),
          FluiButton.outline(
            label: l10n.audioSettingsDeleteAllAction,
            isLoading: deleting,
            onPressed: () => unawaited(_confirmDeleteAll(context, ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleConsent(
    BuildContext context,
    WidgetRef ref, {
    required bool granted,
  }) async {
    final result = await ref
        .read(audioConsentControllerProvider.notifier)
        .setConsent(granted: !granted);
    if (!context.mounted) return;
    if (result case Err()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.audioSettingsErrorMessage)),
      );
    }
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.audioSettingsDeleteAllConfirmTitle),
        content: Text(l10n.audioSettingsDeleteAllConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.audioSettingsCancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.audioSettingsConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref
        .read(audioDeletionControllerProvider.notifier)
        .deleteAll();
    if (!context.mounted) return;
    if (result case Err()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.audioSettingsErrorMessage)));
    }
  }
}

/// Starts a FRESH retake (decision spec `spoken-diagnosis`: every 30 days)
/// — disabled with the available date when too soon, per `RetakePolicy`.
/// Hidden while a retake is already paused/open: `_DiagnosisResumeEntry`
/// (U14c, in the account section below) owns that case, so the two never
/// render at once.
class _RetakeEntry extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = context.layout;
    final resume = ref.watch(diagnosisResumeProvider).value;
    if (resume is! DiagnosisFresh) return const SizedBox.shrink();
    final userId = ref.watch(currentUserIdProvider);
    final profile = userId == null
        ? null
        : ref.watch(latestSkillProfileProvider(userId)).value;
    if (profile == null) return const SizedBox.shrink();

    final today = ref.watch(clockProvider).localToday();
    final lastDiagnosedOn = LocalDate.fromDateTime(profile.diagnosedAt);
    const policy = RetakePolicy();
    final available = policy.isAvailable(
      lastDiagnosedOn: lastDiagnosedOn,
      today: today,
    );

    return FluiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.progressRetakeTitle,
            style: layout.type.body.copyWith(fontWeight: FontWeight.w600),
          ),
          if (!available) ...[
            const SizedBox(height: FluiSpacing.sm),
            Text(
              l10n.diagnosisRetakeTooSoonMessage(
                formatLongDate(
                  policy.nextAvailableOn(lastDiagnosedOn).toDateTime(),
                ),
              ),
              style: layout.type.body.copyWith(color: FluiColors.gray),
            ),
          ],
          const SizedBox(height: FluiSpacing.sm),
          FluiButton.outline(
            label: l10n.progressRetakeAction,
            onPressed: available
                ? () => context.go('${AppRoutes.diagnosisLive}?retake=1')
                : null,
          ),
        ],
      ),
    );
  }
}

/// "Eliminar mi cuenta" (U22e, decision #434): a deliberately confirmed,
/// irreversible action. A two-step confirmation — an explanatory dialog,
/// then a separate final destructive confirm — since the design does not
/// specify one and this deletes the account and cancels billing.
///
/// On success this signs the user out (the router then lands on the
/// signed-out screen, same as the plain "Cerrar sesión" button above). On
/// failure it never signs out: the account is still intact per
/// `account-delete`'s fail-closed contract, so a distinct, honest message is
/// shown and the action stays retryable.
class _AccountDeletionCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = context.layout;
    final deleting = ref.watch(accountDeletionControllerProvider);

    return FluiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.accountDeletionTitle,
            style: layout.type.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: FluiSpacing.sm),
          Text(
            l10n.accountDeletionDescription,
            style: layout.type.body.copyWith(color: FluiColors.gray),
          ),
          const SizedBox(height: FluiSpacing.sm),
          FluiButton.outline(
            label: l10n.accountDeletionAction,
            isLoading: deleting,
            onPressed: () => unawaited(_confirmAndDelete(context, ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;

    // Step 1: explain what gets deleted and the billing consequence.
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountDeletionConfirmTitle),
        content: Text(l10n.accountDeletionConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.audioSettingsCancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.accountDeletionContinueAction),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    // Step 2: the destructive action itself, styled distinctly.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountDeletionFinalConfirmTitle),
        content: Text(l10n.accountDeletionFinalConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.audioSettingsCancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: FluiColors.alert),
            child: Text(l10n.accountDeletionFinalConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(accountDeletionControllerProvider.notifier)
        .delete();
    // `null` means a second call landed while one was already in flight
    // (idempotent UI): nothing new happened, so nothing new is shown.
    if (result == null || !context.mounted) return;
    switch (result) {
      case Ok():
        await ref.read(signOutControllerProvider.notifier).signOut();
      case Err(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure))));
    }
  }
}
