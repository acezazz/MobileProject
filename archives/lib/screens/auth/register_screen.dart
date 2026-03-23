import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/navigation/interaction_gate.dart';
import '../../core/errors/exceptions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../models/interaction_intent.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/common/brand_logo.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

enum _RegisterStep { credentials, profile, review }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  _RegisterStep _step = _RegisterStep.credentials;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .register(
            name: _nameController.text.trim(),
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      final authResult = ref.read(authNotifierProvider);
      if (authResult.hasError) {
        final error = authResult.asError?.error;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getErrorMessage(error)),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      _navigateAfterAuth();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _validateCurrentStep() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();

    switch (_step) {
      case _RegisterStep.credentials:
        return Validators.email(email) == null &&
            Validators.password(password) == null &&
            Validators.confirmPassword(confirmPassword, password) == null;
      case _RegisterStep.profile:
        return Validators.name(name) == null &&
            Validators.username(username) == null;
      case _RegisterStep.review:
        return true;
    }
  }

  void _nextStep() {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || !_validateCurrentStep()) {
      return;
    }

    setState(() {
      if (_step == _RegisterStep.credentials) {
        _step = _RegisterStep.profile;
      } else if (_step == _RegisterStep.profile) {
        _step = _RegisterStep.review;
      }
    });
  }

  void _previousStep() {
    setState(() {
      if (_step == _RegisterStep.profile) {
        _step = _RegisterStep.credentials;
      } else if (_step == _RegisterStep.review) {
        _step = _RegisterStep.profile;
      }
    });
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
        case 'email-already-in-use':
          return 'An account already exists with this email';
        case 'weak-password':
          return 'Password is too weak';
        case 'invalid-email':
          return 'Invalid email address';
        default:
          return error.message ?? 'Registration failed';
      }
    }
    if (error is AuthException) {
      return error.message;
    }
    return 'Registration failed: $error';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isSubmitting;

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
                          const SizedBox(height: 40),
                          const BrandLogo(wordmarkSize: 64),
                          const SizedBox(height: 42),
                          const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 40,
                              height: 0.95,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Please register to login.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_step == _RegisterStep.credentials) ...[
                            CustomTextField(
                              controller: _emailController,
                              hintText: 'Email',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              fillColor: AppColors.accentBeige,
                              textColor: AppColors.inkDark,
                              hintColor: AppColors.inkDark,
                              prefixIcon: const Icon(
                                Icons.mail_outline,
                                color: AppColors.inkDark,
                                size: 18,
                              ),
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 10),
                            CustomTextField(
                              controller: _passwordController,
                              hintText: 'Password',
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              fillColor: AppColors.accentBeige,
                              textColor: AppColors.inkDark,
                              hintColor: AppColors.inkDark,
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: AppColors.inkDark,
                                size: 18,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppColors.inkDark,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                              validator: Validators.password,
                            ),
                            const SizedBox(height: 10),
                            CustomTextField(
                              controller: _confirmPasswordController,
                              hintText: 'Confirm Password',
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              fillColor: AppColors.accentBeige,
                              textColor: AppColors.inkDark,
                              hintColor: AppColors.inkDark,
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: AppColors.inkDark,
                                size: 18,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppColors.inkDark,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  );
                                },
                              ),
                              validator: (value) => Validators.confirmPassword(
                                value,
                                _passwordController.text,
                              ),
                            ),
                          ] else if (_step == _RegisterStep.profile) ...[
                            CustomTextField(
                              controller: _nameController,
                              hintText: 'Full Name',
                              textInputAction: TextInputAction.next,
                              fillColor: AppColors.accentBeige,
                              textColor: AppColors.inkDark,
                              hintColor: AppColors.inkDark,
                              prefixIcon: const Icon(
                                Icons.person,
                                color: AppColors.inkDark,
                                size: 18,
                              ),
                              validator: Validators.name,
                            ),
                            const SizedBox(height: 10),
                            CustomTextField(
                              controller: _usernameController,
                              hintText: 'Username',
                              textInputAction: TextInputAction.done,
                              fillColor: AppColors.accentBeige,
                              textColor: AppColors.inkDark,
                              hintColor: AppColors.inkDark,
                              prefixIcon: const Icon(
                                Icons.alternate_email,
                                color: AppColors.inkDark,
                                size: 18,
                              ),
                              validator: Validators.username,
                            ),
                          ] else ...[
                            const Text(
                              'Review',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Email'),
                              subtitle: Text(_emailController.text.trim()),
                            ),
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Name'),
                              subtitle: Text(_nameController.text.trim()),
                            ),
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Username'),
                              subtitle: Text(_usernameController.text.trim()),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (_step == _RegisterStep.credentials)
                            CustomButton(
                              text: 'Next',
                              compact: true,
                              onPressed: _nextStep,
                              backgroundColor: AppColors.accentBeigeMuted,
                              foregroundColor: AppColors.inkDark,
                            )
                          else if (_step == _RegisterStep.profile)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _previousStep,
                                    child: const Text('Back'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: CustomButton(
                                    text: 'Next',
                                    compact: true,
                                    onPressed: _nextStep,
                                    backgroundColor: AppColors.accentBeigeMuted,
                                    foregroundColor: AppColors.inkDark,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isLoading ? null : _previousStep,
                                    child: const Text('Back'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: CustomButton(
                                    text: 'Create account',
                                    isLoading: isLoading,
                                    compact: true,
                                    onPressed: _handleRegister,
                                    backgroundColor: AppColors.accentBeigeMuted,
                                    foregroundColor: AppColors.inkDark,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Already have account? ',
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
                                      path: '/login',
                                      queryParameters: query.isEmpty
                                          ? null
                                          : query,
                                    ).toString(),
                                  );
                                },
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: AppColors.secondaryAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
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
}
