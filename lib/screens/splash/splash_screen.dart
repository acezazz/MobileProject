import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/common/brand_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _logoScale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _logoScale = Tween<double>(
      begin: 0.95,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      _continueAfterSplash();
    });
  }

  void _continueAfterSplash() {
    if (!mounted) return;

    final auth = ref.read(authStateProvider);
    if (auth.isLoading) {
      _timer = Timer(const Duration(milliseconds: 300), _continueAfterSplash);
      return;
    }

    final target = '/';
    context.go(target);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _logoScale,
            child: const BrandLogo(wordmarkSize: 68),
          ),
        ),
      ),
    );
  }
}
