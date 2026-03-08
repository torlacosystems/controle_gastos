import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';

class SubscriptionService extends ChangeNotifier {
  static const String _firstLaunchKey = 'first_launch_date';

  // IMPORTANTE: configure este ID exatamente igual ao criado no Google Play Console
  static const String productId = 'premium_mensal';

  static const int _trialDays = 7;

  static final SubscriptionService instance = SubscriptionService._internal();
  SubscriptionService._internal();

  bool _subscriptionActive = false;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  DateTime? _firstLaunchDate;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isTrialActive {
    if (_firstLaunchDate == null) return false;
    final diff = DateTime.now().difference(_firstLaunchDate!).inDays;
    return diff < _trialDays;
  }

  int get trialDaysRemaining {
    if (_firstLaunchDate == null) return 0;
    final diff = DateTime.now().difference(_firstLaunchDate!).inDays;
    return (_trialDays - diff).clamp(0, _trialDays);
  }

  bool get isPremium => isTrialActive || _subscriptionActive;

  bool get isSubscriptionActive => _subscriptionActive;

  // ── Inicialização ──────────────────────────────────────────────────────────

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunchStr = prefs.getString(_firstLaunchKey);

    if (firstLaunchStr == null) {
      await prefs.setString(_firstLaunchKey, DateTime.now().toIso8601String());
      _firstLaunchDate = DateTime.now();
    } else {
      _firstLaunchDate = DateTime.parse(firstLaunchStr);
    }

    // Escuta atualizações de compras do Google Play
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdate,
      onError: (e) => debugPrint('Erro no purchaseStream: $e'),
    );

    // Restaura compras anteriores ao iniciar
    await InAppPurchase.instance.restorePurchases();

    notifyListeners();
  }

  // ── Compras ────────────────────────────────────────────────────────────────

  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID == productId) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          _subscriptionActive = true;
          if (purchase.pendingCompletePurchase) {
            InAppPurchase.instance.completePurchase(purchase);
          }
        }
      }
    }
    notifyListeners();
  }

  Future<bool> subscribe() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return false;

    final response = await InAppPurchase.instance.queryProductDetails(
      {productId},
    );

    if (response.productDetails.isEmpty) return false;

    final param = PurchaseParam(
      productDetails: response.productDetails.first,
    );

    try {
      return await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: param,
      );
    } catch (e) {
      debugPrint('Erro ao assinar: $e');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
