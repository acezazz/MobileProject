import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/exceptions.dart';
import '../../core/navigation/interaction_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../models/interaction_intent.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/common/brand_logo.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

enum _RegisterStep { profile, credentials }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _selectedBirthDate;
  String? _selectedGender;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  _RegisterStep _step = _RegisterStep.profile;

  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];

  @override
  void dispose() {
    _usernameController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _formatBirthDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final latestAllowedDate = DateTime(today.year - 13, today.month, today.day);

    final initialDate =
        _selectedBirthDate == null ||
            _selectedBirthDate!.isAfter(latestAllowedDate)
        ? latestAllowedDate
        : _selectedBirthDate!;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: latestAllowedDate,
      helpText: 'Select birthdate',
    );

    if (selectedDate == null) return;

    setState(() {
      _selectedBirthDate = selectedDate;
      _birthDateController.text = _formatBirthDate(selectedDate);
    });
  }

  bool _validateCurrentStep() {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    switch (_step) {
      case _RegisterStep.profile:
        return Validators.username(username) == null &&
            Validators.birthDate(_selectedBirthDate) == null &&
            Validators.gender(_selectedGender) == null;
      case _RegisterStep.credentials:
        return Validators.email(email) == null &&
            Validators.password(password) == null &&
            Validators.confirmPassword(confirmPassword, password) == null;
    }
  }

  void _nextStep() {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || !_validateCurrentStep()) {
      return;
    }

    setState(() {
      if (_step == _RegisterStep.profile) {
        _step = _RegisterStep.credentials;
      }
    });
  }

  void _previousStep() {
    setState(() {
      if (_step == _RegisterStep.credentials) {
        _step = _RegisterStep.profile;
      }
    });
  }

  Future<void> _handleRegister() async {
    if (_isSubmitting) return;

    final birthDate = _selectedBirthDate;
    final gender = _selectedGender;

    if (birthDate == null || gender == null) {
      _formKey.currentState?.validate();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .register(
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            birthDate: birthDate,
            gender: gender,
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
                          Text(
                            _step == _RegisterStep.profile
                                ? 'Step 1 of 2: profile details'
                                : 'Step 2 of 2: login credentials',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_step == _RegisterStep.profile) ...[
                            CustomTextField(
                              controller: _usernameController,
                              hintText: 'Username',
                              textInputAction: TextInputAction.next,
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
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _birthDateController,
                              readOnly: true,
                              onTap: _pickBirthDate,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: AppColors.inkDark),
                              decoration: const InputDecoration(
                                hintText: 'Birthdate',
                                fillColor: AppColors.accentBeige,
                                hintStyle: TextStyle(color: AppColors.inkDark),
                                prefixIcon: Icon(
                                  Icons.cake_outlined,
                                  color: AppColors.inkDark,
                                  size: 18,
                                ),
                                suffixIcon: Icon(
                                  Icons.calendar_today,
                                  color: AppColors.inkDark,
                                  size: 18,
                                ),
                              ),
                              validator: (_) =>
                                  Validators.birthDate(_selectedBirthDate),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedGender,
                              isExpanded: true,
                              style: const TextStyle(color: AppColors.inkDark),
                              dropdownColor: AppColors.accentBeige,
                              decoration: const InputDecoration(
                                hintText: 'Gender',
                                fillColor: AppColors.accentBeige,
                                hintStyle: TextStyle(color: AppColors.inkDark),
                                prefixIcon: Icon(
                                  Icons.wc_outlined,
                                  color: AppColors.inkDark,
                                  size: 18,
                                ),
                              ),
                              items: _genderOptions
                                  .map(
                                    (gender) => DropdownMenuItem<String>(
                                      value: gender,
                                      child: Text(
                                        gender,
                                        style: const TextStyle(
                                          color: AppColors.inkDark,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                              validator: Validators.gender,
                            ),
                          ] else ...[
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
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              validator: (value) => Validators.confirmPassword(
                                value,
                                _passwordController.text,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (_step == _RegisterStep.profile)
                            CustomButton(
                              text: 'Next',
                              compact: true,
                              onPressed: _nextStep,
                              backgroundColor: AppColors.accentBeigeMuted,
                              foregroundColor: AppColors.inkDark,
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
