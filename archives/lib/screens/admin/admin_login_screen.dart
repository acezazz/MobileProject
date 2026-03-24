import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/role_utils.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      final authResult = ref.read(authNotifierProvider);
      if (authResult.hasError) {
        final error = authResult.asError?.error;
        if (mounted && error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getErrorMessage(error)),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final profile = await ref.read(currentUserProfileProvider.future);
      final role = profile?.role;
      final isAdmin = isAdminOrHigher(role);

      if (!mounted) return;

      if (!isAdmin) {
        await ref.read(authNotifierProvider.notifier).logout();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This account does not have admin access.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      context.go('/admin');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Administrator Access',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in with an admin account to open the monitoring dashboard.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'Admin email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    fillColor: AppColors.accentBeige,
                    textColor: AppColors.inkDark,
                    hintColor: AppColors.inkDark,
                    prefixIcon: const Icon(
                      Icons.admin_panel_settings_outlined,
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
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.inkDark,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Open Admin Dashboard',
                    isLoading: _isSubmitting,
                    compact: true,
                    onPressed: _handleAdminLogin,
                    backgroundColor: AppColors.accentBeigeMuted,
                    foregroundColor: AppColors.inkDark,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Back to user login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
