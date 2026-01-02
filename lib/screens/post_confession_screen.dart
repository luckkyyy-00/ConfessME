import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/confession.dart';
import '../providers/confession_provider.dart';
import '../theme/app_theme.dart';
import '../services/ad_service.dart';
import 'dart:math';
import '../services/profanity_service.dart';
import '../models/detection_result.dart';
import '../widgets/profanity_warning_dialog.dart';
import '../widgets/self_harm_dialog.dart';
import '../services/payment_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PostConfessionScreen extends StatefulWidget {
  const PostConfessionScreen({super.key});

  @override
  State<PostConfessionScreen> createState() => _PostConfessionScreenState();
}

class _PostConfessionScreenState extends State<PostConfessionScreen> {
  final TextEditingController _controller = TextEditingController();
  ConfessionCategory _selectedCategory = ConfessionCategory.secret;
  late String _hintText;
  bool _isProcessingPayment = false;
  late PaymentService _paymentService;

  final List<String> _prompts = [
    "Say what you never said...",
    "What's weighing on your heart?",
    "A secret you've kept for too long...",
    "Something you regret not doing...",
    "A fear you haven't shared...",
    "The truth about how you feel...",
  ];

  @override
  void initState() {
    super.initState();
    _hintText = _prompts[Random().nextInt(_prompts.length)];
    _paymentService = PaymentService(
      onPurchaseSuccess: _onPurchaseSuccess,
      onPurchaseError: _onPurchaseError,
    );
    _paymentService.init();
  }

  void _onPurchaseSuccess(String productId, String purchaseToken) async {
    if (productId == PaymentService.paidConfession10) {
      final provider = context.read<ConfessionProvider>();
      final content = _controller.text.trim();

      // 1. Update Credits: +1 (Verified via Cloud Function)
      await provider.addPaidCredit(productId, purchaseToken);

      // 2. Post Confession
      final postResult = await provider.addConfession(
        content,
        _selectedCategory,
        isPaid: true,
      );

      if (mounted) {
        if (postResult['success'] == true) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your paid confession is live! 🌟'),
              backgroundColor: AppTheme.goldColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Post failed: ${postResult['reason']}'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
    if (mounted) setState(() => _isProcessingPayment = false);
  }

  void _onPurchaseError(String error) {
    if (mounted) {
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $error'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _handlePaidSubmission,
          ),
        ),
      );
    }
  }

  Future<void> _handlePaidSubmission() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    // Run Profanity Filter BEFORE payment
    final result = ProfanityService().checkContent(content);
    if (result.hasViolation) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => const ProfanityWarningDialog(),
        );
      }
      return;
    }

    setState(() => _isProcessingPayment = true);

    // Find the product
    final int productIndex = _paymentService.products.indexWhere(
      (p) => p.id == PaymentService.paidConfession10,
    );

    // If product not found
    if (productIndex == -1) {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment unavailable. Please try later.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final product = _paymentService.products[productIndex];

    await _paymentService.buyProduct(product);
  }

  @override
  void dispose() {
    _paymentService.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    // 1. Run Profanity Filter
    final result = ProfanityService().checkContent(content);

    if (result.hasViolation) {
      if (mounted) {
        if (result.type == DetectionType.selfHarm) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const SelfHarmDialog(),
          );
          // We don't block submission of self-harm for now,
          // but we might want to flag it in Firestore.
          // For now, let's allow it so the community can help/respond if appropriate,
          // OR block if the user intended to block.
          // Re-reading: "Do NOT block silently. Detect & respond."
          // So we show the dialog and then continue with submission?
          // Usually, self-harm is something we want to detect and provide help for.
        } else {
          showDialog(
            context: context,
            builder: (context) => const ProfanityWarningDialog(),
          );
          return; // Block submission for other violations
        }
      }
    }

    // 2. Proceed with submission
    final provider = context.read<ConfessionProvider>();
    final postResult = await provider.addConfession(content, _selectedCategory);

    if (mounted) {
      if (postResult['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your secret is safe with us.'),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Show Interstitial Ad (Frequency capped internally)
        AdService().showInterstitialAd();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(postResult['reason']),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Speak freely.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w300, // Light weight for calmness
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No one knows it\'s you.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white38),
              ),
              const SizedBox(height: 40),

              // Writing Area
              TextField(
                controller: _controller,
                minLines: 8,
                maxLines: null,
                maxLength: 300,
                scrollPadding: const EdgeInsets.only(bottom: 120),
                keyboardType: TextInputType.multiline,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 20,
                  height: 1.6,
                  color: AppTheme.primaryColor,
                ),
                decoration: InputDecoration(
                  hintText: _hintText,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 20,
                    height: 1.6,
                  ),
                  border: InputBorder.none,
                  counterStyle: const TextStyle(color: Colors.white24),
                ),
                cursorColor: AppTheme.accentColor,
              ),

              // Category Selection (Minimal Chips)
              const SizedBox(height: 20),
              Text(
                'CHOOSE A CATEGORY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white38,
                  letterSpacing: 1.5,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ConfessionCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ChoiceChip(
                        label: Text(
                          category.toString().split('.').last.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = category);
                          }
                        },
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        selectedColor: AppTheme.accentColor.withValues(
                          alpha: 0.8,
                        ),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 30),

              // Post Normal Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessingPayment ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Post Anonymously',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Post Paid Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessingPayment
                      ? null
                      : _handlePaidSubmission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.goldColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shadowColor: AppTheme.goldColor.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ).copyWith(elevation: WidgetStateProperty.all(8)),
                  child: _isProcessingPayment
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Post Paid Confession (₹10)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                height: 100,
              ), // Extra space to scroll above keyboard
            ],
          ),
        ),
      ),
    );
  }
}
