import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/api/api_client.dart';
import 'package:salom_ai/core/api/api_models.dart';

final subscriptionManagerProvider =
    StateNotifierProvider<SubscriptionManager, SubscriptionManagerState>((ref) {
  return SubscriptionManager(ref.watch(apiClientProvider));
});

class SubscriptionManagerState {
  final bool isPro;
  final String? currentPlan;
  final List<SubscriptionPlan> plans;
  final CurrentSubscriptionResponse? subscription;
  final bool isLoading;

  SubscriptionManagerState({
    this.isPro = false,
    this.currentPlan,
    this.plans = const [],
    this.subscription,
    this.isLoading = false,
  });

  SubscriptionManagerState copyWith({
    bool? isPro,
    String? currentPlan,
    List<SubscriptionPlan>? plans,
    CurrentSubscriptionResponse? subscription,
    bool? isLoading,
  }) {
    return SubscriptionManagerState(
      isPro: isPro ?? this.isPro,
      currentPlan: currentPlan ?? this.currentPlan,
      plans: plans ?? this.plans,
      subscription: subscription ?? this.subscription,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SubscriptionManager extends StateNotifier<SubscriptionManagerState> {
  final ApiClient _client;

  SubscriptionManager(this._client) : super(SubscriptionManagerState());

  Future<void> checkSubscriptionStatus() async {
    try {
      final sub = await _client.currentSubscription();
      final isPro = sub.active && sub.plan != null && sub.plan != 'free';
      state = state.copyWith(
        isPro: isPro,
        currentPlan: sub.plan,
        subscription: sub,
      );
    } catch (e) {
      debugPrint('Failed to check subscription: $e');
      state = state.copyWith(isPro: false, currentPlan: 'free');
    }
  }

  Future<void> fetchPlans() async {
    try {
      final plans = await _client.listPlans();
      state = state.copyWith(plans: plans);
    } catch (e) {
      debugPrint('Failed to fetch plans: $e');
    }
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([checkSubscriptionStatus(), fetchPlans()]);
    state = state.copyWith(isLoading: false);
  }

  Future<String?> subscribe(String planCode) async {
    try {
      final response = await _client.subscribe(planCode, 'click');
      return response.checkoutUrl;
    } catch (e) {
      debugPrint('Subscribe failed: $e');
      return null;
    }
  }
}
