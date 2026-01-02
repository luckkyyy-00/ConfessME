import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/confession.dart';
import '../theme/app_theme.dart';
import '../providers/confession_provider.dart';
import '../screens/highlight_payment_screen.dart';
import '../screens/focus_mode_screen.dart';

class ConfessionCard extends StatefulWidget {
  final Confession confession;
  final VoidCallback? onReact;

  const ConfessionCard({super.key, required this.confession, this.onReact});

  @override
  State<ConfessionCard> createState() => _ConfessionCardState();
}

class _ConfessionCardState extends State<ConfessionCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.confession.isHighlighted) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(ConfessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.confession.isHighlighted &&
        !oldWidget.confession.isHighlighted) {
      _startTimer();
    } else if (!widget.confession.isHighlighted &&
        oldWidget.confession.isHighlighted) {
      _stopTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Color _getCategoryColor() {
    switch (widget.confession.category) {
      case ConfessionCategory.love:
        return AppTheme.loveColor;
      case ConfessionCategory.regret:
        return AppTheme.regretColor;
      case ConfessionCategory.secret:
        return AppTheme.secretColor;
      case ConfessionCategory.fear:
        return AppTheme.fearColor;
    }
  }

  int _getReactionCount(String reaction) {
    return widget.confession.reactionCounts[reaction] ?? 0;
  }

  String _getRemainingTime() {
    if (widget.confession.highlightEndTime == null) return '';
    final remaining = widget.confession.highlightEndTime!.difference(
      DateTime.now(),
    );
    if (remaining.isNegative) return 'Expired';

    if (remaining.inHours > 0) {
      return '${remaining.inHours}h left';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m left';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.confession.isHighlighted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted ? null : AppTheme.surfaceColor,
        gradient: isHighlighted ? AppTheme.primaryGradient : null,
        borderRadius: BorderRadius.circular(20), // 20px rounded corners
        border: isHighlighted
            ? Border.all(
                color: AppTheme.goldColor.withValues(alpha: 0.5),
                width: 1.5,
              )
            : Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
          if (isHighlighted)
            BoxShadow(
              color: AppTheme.goldColor.withValues(
                alpha: 0.085,
              ), // Reduced opacity by 15%
              blurRadius: 25,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                final provider = context.read<ConfessionProvider>();
                final index = provider.confessions.indexWhere(
                  (c) => c.id == widget.confession.id,
                );
                if (index == -1) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FocusModeScreen(
                      confessions: provider.confessions,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0), // 20px padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Category + Time (No Avatar/Username)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getCategoryColor().withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.confession.categoryString.toUpperCase(),
                            style: TextStyle(
                              color: _getCategoryColor(),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        if (isHighlighted)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.goldColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'FEATURED',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getRemainingTime(),
                                style: const TextStyle(
                                  color: AppTheme.goldColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            DateFormat(
                              'jm',
                            ).format(widget.confession.createdAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Content: Serif Font, 17-18sp, 1.6-1.8 line height
                    // Reduced width for reading comfort and large screen support
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Text(
                          widget.confession.content,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontSize: 18,
                                height: 1.6,
                                color: AppTheme.primaryColor,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Footer: Reactions (Muted, No Text)
                    Row(
                      children: [
                        _buildReactionChip(
                          context,
                          '❤️',
                          _getReactionCount('❤️'),
                        ),
                        _buildReactionChip(
                          context,
                          '😢',
                          _getReactionCount('😢'),
                        ),
                        _buildReactionChip(
                          context,
                          '😮',
                          _getReactionCount('😮'),
                        ),
                        _buildReactionChip(
                          context,
                          '🔥',
                          _getReactionCount('🔥'),
                        ),
                        const Spacer(),
                        if (!isHighlighted)
                          IconButton(
                            onPressed: () => _showHighlightScreen(context),
                            icon: const Icon(
                              Icons.auto_awesome_outlined,
                              color: AppTheme.goldColor,
                              size: 20,
                            ),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Highlight',
                          ),
                        IconButton(
                          onPressed: () => _showReportDialog(context),
                          icon: const Icon(
                            Icons
                                .flag_outlined, // Changed to Flag for cleaner look
                            color: Colors.white24,
                            size: 20,
                          ),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Report',
                        ),
                        IconButton(
                          onPressed: () => _showReactionPicker(context),
                          icon: const Icon(
                            Icons.add_reaction_outlined,
                            color: Colors.white38,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHighlightScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HighlightPaymentScreen(confession: widget.confession),
      ),
    );
  }

  void _showReactionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How does this make you feel?',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildReactionOption(context, '❤️', 'Relatable'),
                  _buildReactionOption(context, '😢', 'Sad'),
                  _buildReactionOption(context, '😮', 'Shock'),
                  _buildReactionOption(context, '🔥', 'Brave'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReactionOption(
    BuildContext context,
    String emoji,
    String label,
  ) {
    return GestureDetector(
      onTap: () {
        if (FirebaseAuth.instance.currentUser == null) return;
        HapticFeedback.lightImpact(); // Subtle haptic
        context.read<ConfessionProvider>().react(widget.confession.id, emoji);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Report Content'),
        content: const Text(
          'Is this content harmful or abusive? We want to keep this a safe space for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              if (FirebaseAuth.instance.currentUser == null) return;
              context.read<ConfessionProvider>().reportConfession(
                widget.confession.id,
                'Inappropriate',
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for helping keep this space safe.'),
                  backgroundColor: AppTheme.accentColor,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              'Report',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionChip(BuildContext context, String emoji, int count) {
    if (count == 0) return const SizedBox.shrink();
    final provider = context.watch<ConfessionProvider>();
    final userReaction = provider.userReactions[widget.confession.id];
    final isActive = userReaction == emoji;

    return GestureDetector(
      onTap: () {
        if (FirebaseAuth.instance.currentUser == null) return;
        HapticFeedback.lightImpact();
        context.read<ConfessionProvider>().react(widget.confession.id, emoji);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.goldColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.goldColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppTheme.goldColor : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
