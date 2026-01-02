import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/confession.dart';
import '../theme/app_theme.dart';
import '../services/payment_service.dart';
import '../services/database_service.dart';
import '../widgets/confession_card.dart';

class HighlightPaymentScreen extends StatefulWidget {
  final Confession confession;

  const HighlightPaymentScreen({super.key, required this.confession});

  @override
  State<HighlightPaymentScreen> createState() => _HighlightPaymentScreenState();
}

class _HighlightPaymentScreenState extends State<HighlightPaymentScreen> {
  late PaymentService _paymentService;
  bool _isLoading = true;
  String? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService(
      onPurchaseSuccess: _handleSuccess,
      onPurchaseError: _handleError,
    );
    _initPayment();
  }

  Future<void> _initPayment() async {
    await _paymentService.init();
    if (mounted) {
      setState(() {
        _isLoading = false;
        // Default to 24h option if available
        if (_paymentService.products.isNotEmpty) {
          _selectedProductId = _paymentService.products.first.id;
        }
      });
    }
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  void _handleSuccess(String productId, String purchaseToken) async {
    final dbService = DatabaseService();
    try {
      await dbService.verifyAndHighlight(
        widget.confession.id,
        productId,
        purchaseToken,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confession Highlighted Successfully! 🌟'),
            backgroundColor: AppTheme.goldColor,
          ),
        );
      }
    } catch (e) {
      _handleError('Verification failed: $e');
    }
  }

  void _handleError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Purchase Failed: $error'),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  List<ProductDetails> get _currentProducts {
    return _paymentService.products.isEmpty
        ? [
            ProductDetails(
              id: PaymentService.highlight24h,
              title: '24 Hours Highlight',
              description: 'Boost for 24 hours',
              price: '₹10',
              rawPrice: 10,
              currencyCode: 'INR',
            ),
            ProductDetails(
              id: PaymentService.highlight48h,
              title: '48 Hours Highlight',
              description: 'Boost for 48 hours',
              price: '₹29',
              rawPrice: 29,
              currencyCode: 'INR',
            ),
          ]
        : _paymentService.products;
  }

  void _buy() {
    if (_selectedProductId == null) return;

    final product = _currentProducts.firstWhere(
      (p) => p.id == _selectedProductId,
      orElse: () => _currentProducts.first,
    );

    _paymentService.buyProduct(product);
  }

  @override
  Widget build(BuildContext context) {
    final products = _currentProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Highlight Confession'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PREVIEW',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            // Preview Card (forced highlight style)
            ConfessionCard(
              confession: Confession(
                id: widget.confession.id,
                content: widget.confession.content,
                category: widget.confession.category,
                createdAt: widget.confession.createdAt,
                reactionCounts: widget.confession.reactionCounts,
                isTop: true, // Force top style for preview
                isHighlighted: true,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'SELECT DURATION',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ...products.map((product) => _buildPriceOption(product)),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _buy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'PAY SECURELY',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Secured by Google Play',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceOption(ProductDetails product) {
    final isSelected = _selectedProductId == product.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedProductId = product.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.goldColor.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.goldColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.goldColor : Colors.white24,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.goldColor,
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title
                        .replaceAll('(Confess App)', '')
                        .trim(), // Clean title
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    product.description,
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
            Text(
              product.price,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.goldColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
