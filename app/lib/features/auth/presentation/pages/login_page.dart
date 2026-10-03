import 'dart:async';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/auth/presentation/auth_copy.dart';
import 'package:flui/features/auth/presentation/controllers/sign_in_controller.dart';
import 'package:flui/features/auth/presentation/widgets/auth_layout.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Sign in. On success the router moves on when the session changes.
class LoginPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    unawaited(
      ref
          .read(signInControllerProvider.notifier)
          .submit(email: _email.text, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(signInControllerProvider);
    final failure = state.failure;

    return AuthLayout(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      children: [
        FluiTextField(
          label: l10n.fieldEmailLabel,
          hint: l10n.fieldEmailHint,
          controller: _email,
          errorText: emailErrorText(l10n, state.emailError),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: FluiSpacing.md),
        FluiTextField(
          label: l10n.fieldPasswordLabel,
          controller: _password,
          errorText: passwordErrorText(l10n, state.passwordError),
          isPassword: true,
          showPasswordLabel: l10n.passwordShow,
          hidePasswordLabel: l10n.passwordHide,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FluiButton.text(
            label: l10n.loginForgotPassword,
            // Push (not go) so back returns to login instead of exiting.
            onPressed: () => context.push(AppRoutes.resetPassword),
          ),
        ),
        if (failure != null) ...[
          FluiNotice(message: failureMessage(l10n, failure)),
          const SizedBox(height: FluiSpacing.md),
        ],
        const SizedBox(height: FluiSpacing.xs),
        FluiButton.primary(
          label: l10n.loginSubmit,
          isLoading: state.isSubmitting || state.isDone,
          onPressed: _submit,
        ),
        const SizedBox(height: FluiSpacing.md),
        Center(
          child: FluiButton.text(
            label: l10n.loginNoAccount,
            // Push (not go) so back returns to login instead of exiting.
            onPressed: () => context.push(AppRoutes.register),
          ),
        ),
      ],
    );
  }
}
