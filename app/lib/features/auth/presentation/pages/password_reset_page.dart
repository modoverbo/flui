import 'dart:async';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/auth/presentation/auth_copy.dart';
import 'package:flui/features/auth/presentation/controllers/password_reset_controller.dart';
import 'package:flui/features/auth/presentation/widgets/auth_layout.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class PasswordResetPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends ConsumerState<PasswordResetPage> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    unawaited(
      ref
          .read(passwordResetControllerProvider.notifier)
          .submit(email: _email.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(passwordResetControllerProvider);
    final failure = state.failure;

    return AuthLayout(
      title: l10n.resetTitle,
      subtitle: l10n.resetBody,
      children: [
        if (state.isDone)
          FluiNotice(
            message: l10n.resetSent(_email.text.trim()),
            tone: FluiNoticeTone.info,
            icon: LucideIcons.mail,
          )
        else ...[
          FluiTextField(
            label: l10n.fieldEmailLabel,
            hint: l10n.fieldEmailHint,
            controller: _email,
            errorText: emailErrorText(l10n, state.emailError),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: FluiSpacing.lg),
          if (failure != null) ...[
            FluiNotice(message: failureMessage(l10n, failure)),
            const SizedBox(height: FluiSpacing.md),
          ],
          FluiButton.primary(
            label: l10n.resetSubmit,
            isLoading: state.isSubmitting,
            onPressed: _submit,
          ),
        ],
        const SizedBox(height: FluiSpacing.md),
        Center(
          child: FluiButton.text(
            label: l10n.resetBackToLogin,
            // If login pushed us here, pop keeps that same instance
            // instead of replacing the stack with a fresh one.
            // Deep-linked straight to /reset-password (no login
            // underneath), go() is the only way back.
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.login),
          ),
        ),
      ],
    );
  }
}
