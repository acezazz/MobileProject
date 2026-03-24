import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GuestLandingScreen extends StatelessWidget {
  const GuestLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Text('Welcome to Archives'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Login'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go('/register'),
              child: const Text('Register'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Continue as guest'),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
