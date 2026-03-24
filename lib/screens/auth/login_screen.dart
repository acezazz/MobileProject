import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/navigation/interaction_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/validators.dart';
import '../../models/interaction_intent.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/common/brand_logo.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authNotifierProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    final authResult = ref.read(authNotifierProvider);
    if (authResult.hasError || !mounted) {
      return;
    }

    _navigateAfterAuth();
  }

  void _navigateAfterAuth() {
    final query = GoRouterState.of(context).uri.queryParameters;
    final intent = InteractionIntent.fromQueryMap(query);
    if (intent != null) {
      context.go(resolveIntentPath(intent));
      return;
    }

    final from = query['from'];
    if (from != null && from.isNotEmpty) {
      context.go(Uri.decodeComponent(from));
      return;
    }

    context.go('/');
  }

  String _getErrorMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect password';
        case 'invalid-email':
          return 'Invalid email address';
        case 'user-disabled':
          return 'This account has been disabled';
        case 'invalid-credential':
          return 'Invalid email or password';
        default:
          return error.message ?? 'Login failed';
      }
    }
    return 'Login failed: $error';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AsyncLoading;

    ref.listen(authNotifierProvider, (prev, next) {
      next.whenOrNull(
        error: (error, _) {
          AppSnackBar.error(context, _getErrorMessage(error));
        },
      );
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 28),
                          const BrandLogo(wordmarkSize: 70),
                          const SizedBox(height: 44),
                          const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 42,
                              height: 0.95,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Please Sign in to continue.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _emailController,
                            hintText: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            fillColor: AppColors.surfaceVariant,
                            prefixIcon: Icon(
                              PhosphorIcons.envelopeSimple(),
                              color: AppColors.textHint,
                              size: 20,
                            ),
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            controller: _passwordController,
                            hintText: 'Password',
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            fillColor: AppColors.surfaceVariant,
                            prefixIcon: Icon(
                              PhosphorIcons.lockKey(),
                              color: AppColors.textHint,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? PhosphorIcons.eyeClosed()
                                    : PhosphorIcons.eye(),
                                color: AppColors.textHint,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                            validator: Validators.password,
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'Login',
                            isLoading: isLoading,
                            compact: false,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have account? ",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  final query = GoRouterState.of(
                                    context,
                                  ).uri.queryParameters;
                                  context.go(
                                    Uri(
                                      path: '/register',
                                      queryParameters: query.isEmpty
                                          ? null
                                          : query,
                                    ).toString(),
                                  );
                                },
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: AppColors.secondaryAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset Password'),
        content: CustomTextField(
          controller: emailController,
          hintText: 'Enter your email',
          keyboardType: TextInputType.emailAddress,
          fillColor: AppColors.accentBeige,
          textColor: AppColors.inkDark,
          hintColor: AppColors.inkDark,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (emailController.text.trim().isNotEmpty) {
                try {
                  await ref
                      .read(authRepositoryProvider)
                      .resetPassword(emailController.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                    AppSnackBar.success(
                      context,
                      'Password reset email sent.',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppSnackBar.error(context, 'Error: $e');
                  }
                }
              }
            },
            child: const Text(
              'Send',
              style: TextStyle(color: AppColors.secondaryAccent),
            ),
          ),
        ],
      ),
    );
  }
}
