import 'dart:async';

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/l10n/failure_messages.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/auth/presentation/auth_copy.dart';
import 'package:flui/features/auth/presentation/controllers/sign_up_controller.dart';
import 'package:flui/features/auth/presentation/widgets/auth_layout.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_notice.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    unawaited(
      ref
          .read(signUpControllerProvider.notifier)
          .submit(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(signUpControllerProvider);
    final failure = state.failure;
    final confirmationEmail = state.confirmationEmail;

    if (confirmationEmail != null) {
      return AuthLayout(
        title: l10n.registerConfirmEmailTitle,
        children: [
          FluiNotice(
            message: l10n.registerConfirmEmailBody(confirmationEmail),
            tone: FluiNoticeTone.info,
            icon: LucideIcons.mail,
          ),
          const SizedBox(height: FluiSpacing.lg),
          FluiButton.primary(
            label: l10n.registerGoToLogin,
            onPressed: () => context.go(AppRoutes.login),
          ),
        ],
      );
    }

    return AuthLayout(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      children: [
        FluiTextField(
          label: l10n.fieldNameLabel,
          hint: l10n.fieldNameHint,
          controller: _name,
          errorText: nameErrorText(l10n, state.nameError),
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.givenName],
        ),
        const SizedBox(height: FluiSpacing.md),
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
          hint: l10n.fieldPasswordHint,
          controller: _password,
          errorText: passwordErrorText(l10n, state.passwordError),
          isPassword: true,
          showPasswordLabel: l10n.passwordShow,
          hidePasswordLabel: l10n.passwordHide,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: FluiSpacing.lg),
        if (failure != null) ...[
          FluiNotice(message: failureMessage(l10n, failure)),
          const SizedBox(height: FluiSpacing.md),
        ],
        FluiButton.primary(
          label: l10n.registerSubmit,
          isLoading: state.isSubmitting || state.isDone,
          onPressed: _submit,
        ),
        const SizedBox(height: FluiSpacing.md),
        // TODO(auth): enable Google sign-in after Phase A (Supabase provider
        // plus the web SDK button); kept visible and disabled on purpose.
        FluiButton.outline(label: l10n.registerGoogleSoon, onPressed: null),
        const SizedBox(height: FluiSpacing.md),
        Center(
          child: FluiButton.text(
            label: l10n.registerHaveAccount,
            onPressed: () => context.go(AppRoutes.login),
          ),
        ),
      ],
    );
  }
}
