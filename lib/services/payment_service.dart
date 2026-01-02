import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PaymentService {
  final InAppPurchase _iap = InAppPurchase.instance;

  // Product IDs
  static const String highlight24h = 'highlight_24h';
  static const String highlight48h = 'highlight_48h';
  static const String paidConfession10 = 'paid_confession_10';

  final Set<String> _productIds = {
    highlight24h,
    highlight48h,
    paidConfession10,
  };

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final Function(String productId, String purchaseToken) onPurchaseSuccess;
  final Function(String error) onPurchaseError;

  PaymentService({
    required this.onPurchaseSuccess,
    required this.onPurchaseError,
  });

  Future<void> init() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('IAP not available');
      return;
    }

    // Listen to purchase updates
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdated,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('IAP Error: $error'),
    );

    // Load products
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = await _iap.queryProductDetails(
      _productIds,
    );

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }

    // debugPrint("Billing: Loaded products: ${response.productDetails}");
    _products = response.productDetails;
  }

  Future<void> buyProduct(ProductDetails product) async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      onPurchaseError(
        'Store not available. Please check your internet or Play Store account.',
      );
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show loading UI if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          onPurchaseError(purchaseDetails.error?.message ?? 'Unknown error');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // Verify purchase here (server-side verification recommended)
          _verifyPurchase(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // In a real app, verify with backend using purchaseDetails.verificationData
    onPurchaseSuccess(
      purchaseDetails.productID,
      purchaseDetails.verificationData.serverVerificationData,
    );
  }

  void dispose() {
    _subscription?.cancel();
  }
}
