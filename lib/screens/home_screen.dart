import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:provider/provider.dart';
import '../providers/confession_provider.dart';
import '../models/confession.dart';
import '../widgets/confession_card.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_header.dart';
import '../widgets/premium_bottom_nav.dart';
import '../widgets/native_ad_card.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'post_confession_screen.dart';
import 'focus_mode_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    // Defer non-critical services until after the UI is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
  }

  Future<void> _initServices() async {
    try {
      // 1. Initialize Ads in background
      Future.microtask(() => AdService().init());

      // 2. Initialize Notifications with UID
      final authService = AuthService();
      final userId = await authService.getUserId();
      if (userId != null) {
        NotificationService().initialize(userId: userId);
      }
    } catch (e) {
      debugPrint('Service initialization deferred error: $e');
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.nightlight_round, size: 48, color: Colors.white10),
            const SizedBox(height: 24),
            const Text(
              'No confessions yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to speak.',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryCTA(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PostConfessionScreen(),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accentColor.withValues(alpha: 0.8),
                AppTheme.accentColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Write a confession',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No one knows it\'s you.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHighlights(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Center(
        child: Text(
          'No highlights near you right now.',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ),
    );
  }

  String _getHighlightLabel(
    List<Confession> highlights,
    ConfessionProvider provider,
  ) {
    if (highlights.isEmpty) return 'HIGHLIGHTED';

    final first = highlights.first;
    if (provider.city != null && first.city == provider.city) {
      return 'HIGHLIGHTED NEAR YOU';
    } else if (provider.state != null && first.state == provider.state) {
      return 'HIGHLIGHTED NEARBY';
    } else if (provider.country != null && first.country == provider.country) {
      return 'POPULAR IN ${provider.country!.toUpperCase()}';
    }
    return 'POPULAR CONFESSIONS';
  }

  String? _getHighlightLocation(
    List<Confession> highlights,
    ConfessionProvider provider,
  ) {
    if (highlights.isEmpty) return null;
    final first = highlights.first;
    if (provider.city != null && first.city == provider.city) {
      return provider.city;
    }
    if (provider.state != null && first.state == provider.state) {
      return provider.state;
    }
    if (provider.country != null && first.country == provider.country) {
      return provider.country;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConfessionProvider>();

    // Split confessions into Highlights (max 3) and Recent
    final highlights = provider.confessions
        .where((c) => c.isHighlighted)
        .take(3)
        .toList();
    final recent = provider.confessions.where((c) => !c.isHighlighted).toList();

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
              const SliverToBoxAdapter(child: PremiumHeader()),
              SliverToBoxAdapter(child: _buildPrimaryCTA(context)),

              // 1. Highlights Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getHighlightLabel(highlights, provider),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 2,
                          color: AppTheme.goldColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (highlights.isNotEmpty &&
                          _getHighlightLocation(highlights, provider) != null)
                        Text(
                          '📍 ${_getHighlightLocation(highlights, provider)}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (highlights.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyHighlights(context))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        ConfessionCard(confession: highlights[index]),
                    childCount: highlights.length,
                  ),
                ),

              // 2. Recent Confessions Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Text(
                    'RECENT CONFESSIONS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 2,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ),
              ),

              // Content Area
              if (provider.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(50.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (recent.isEmpty && highlights.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState(context))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Skip ads on Web
                      if (kIsWeb) {
                        if (index >= recent.length) return null;
                        return ConfessionCard(confession: recent[index]);
                      }

                      // Mobile Ad Logic
                      final int adCount = index ~/ 8;
                      final int confessionIndex = index - adCount;

                      if ((index + 1) % 8 == 0) {
                        return const NativeAdCard();
                      }

                      if (confessionIndex >= recent.length) {
                        return null;
                      }

                      final confession = recent[confessionIndex];
                      return ConfessionCard(confession: confession);
                    },
                    childCount: kIsWeb
                        ? recent.length
                        : recent.length + (recent.length ~/ 7),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: PremiumBottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (index == 1) {
                  // Focus Mode
                  if (provider.confessions.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FocusModeScreen(
                          confessions: provider.confessions.take(10).toList(),
                        ),
                      ),
                    );
                  }
                } else {
                  setState(() => _currentIndex = index);
                }
              },
              onCenterTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PostConfessionScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
