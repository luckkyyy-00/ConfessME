import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../theme/app_theme.dart';

class FocusModeOnboarding extends StatefulWidget {
  final VoidCallback onComplete;

  const FocusModeOnboarding({super.key, required this.onComplete});

  @override
  State<FocusModeOnboarding> createState() => _FocusModeOnboardingState();
}

class _FocusModeOnboardingState extends State<FocusModeOnboarding> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'This is a quiet space.',
      subtitle: 'One confession at a time.\nNo noise. No judgment.',
      icon: Icons.nightlight_round,
    ),
    OnboardingData(
      title: 'Read slowly.',
      subtitle: 'Swipe when you’re ready.\nThere’s no rush.',
      icon: Icons.swipe_left_rounded,
    ),
    OnboardingData(
      title: 'Leave anytime.',
      subtitle: 'Swipe down to return.\nYour peace comes first.',
      icon: Icons.keyboard_arrow_down_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentPage < _pages.length - 1) {
        _controller.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        timer.cancel();
        // Give the user a moment to see the last page before entering
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) widget.onComplete();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final data = _pages[index];
              return Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.scale(
                            scale: 0.8 + (0.2 * value),
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        data.icon,
                        size: 100,
                        color: AppTheme.accentColor.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 60),
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      data.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SmoothPageIndicator(
                  controller: _controller,
                  count: _pages.length,
                  effect: const ExpandingDotsEffect(
                    activeDotColor: AppTheme.accentColor,
                    dotColor: Colors.white10,
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3,
                  ),
                ),
                const SizedBox(height: 40),
                AnimatedOpacity(
                  opacity: _currentPage == _pages.length - 1 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    'Entering Focus Mode...',
                    style: TextStyle(
                      color: AppTheme.accentColor.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final IconData icon;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
