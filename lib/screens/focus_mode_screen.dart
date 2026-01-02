import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/confession.dart';
import '../theme/app_theme.dart';
import '../widgets/focus_mode_onboarding.dart';

class FocusModeScreen extends StatefulWidget {
  final List<Confession> confessions;
  final int initialIndex;

  const FocusModeScreen({
    super.key,
    required this.confessions,
    this.initialIndex = 0,
  });

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> {
  late PageController _pageController;
  bool _showOnboarding = false;
  bool _isLoading = true;
  bool _showReactions = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seenFocusOnboarding') ?? false;
    setState(() {
      _showOnboarding = !seen;
      _isLoading = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenFocusOnboarding', true);
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF0F1115));

    if (_showOnboarding) {
      return FocusModeOnboarding(onComplete: _completeOnboarding);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! > 20) {
            Navigator.pop(context);
          }
        },
        onTap: () => setState(() => _showReactions = !_showReactions),
        child: Stack(
          children: [
            // Subtle Vignette
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                  stops: const [0.6, 1.0],
                  radius: 1.2,
                ),
              ),
            ),

            // Main Content
            PageView.builder(
              controller: _pageController,
              itemCount: widget.confessions.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _showReactions = false;
                });
              },
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final confession = widget.confessions[index];
                return _buildConfessionPage(confession);
              },
            ),

            // Progress Indicator
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.confessions.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == index
                            ? AppTheme.accentColor
                            : Colors.white10,
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Exit Hint (Subtle)
            const Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white10,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfessionPage(Confession confession) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(confession.id),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  confession.content,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.merriweather(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 22,
                    height: 1.8,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              AnimatedOpacity(
                opacity: _showReactions ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: AnimatedScale(
                  scale: _showReactions ? 1.0 : 0.95,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: _buildReactions(confession),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactions(Confession confession) {
    final reactions = ['❤️', '😢', '😮', '🔥'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: reactions.map((r) {
        final count = confession.reactionCounts[r] ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Text(r, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
