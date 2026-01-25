import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/api/api_client.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:url_launcher/url_launcher.dart';

final subscriptionViewModelProvider = StateNotifierProvider.autoDispose<SubscriptionViewModel, SubscriptionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SubscriptionViewModel(apiClient);
});

class SubscriptionState {
  final List<SubscriptionPlan> plans;
  final CurrentSubscriptionResponse? currentSubscription;
  final bool isLoading;
  final String? isProcessing; // plan code

  SubscriptionState({
    this.plans = const [],
    this.currentSubscription,
    this.isLoading = false,
    this.isProcessing,
  });

  SubscriptionState copyWith({
    List<SubscriptionPlan>? plans,
    CurrentSubscriptionResponse? currentSubscription,
    bool? isLoading,
    String? isProcessing,
  }) {
    return SubscriptionState(
      plans: plans ?? this.plans,
      currentSubscription: currentSubscription ?? this.currentSubscription,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing, // intentionally allow null
    );
  }
}

class SubscriptionViewModel extends StateNotifier<SubscriptionState> {
  final ApiClient _apiClient;

  SubscriptionViewModel(this._apiClient) : super(SubscriptionState());

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      fetchPlans(),
      fetchCurrentSubscription(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> fetchPlans() async {
    try {
      final plans = await _apiClient.listPlans();
      state = state.copyWith(plans: plans);
    } catch (e) {
      debugPrint("Failed to fetch plans: $e");
    }
  }

  Future<void> fetchCurrentSubscription() async {
    try {
      final sub = await _apiClient.currentSubscription();
      state = state.copyWith(currentSubscription: sub);
    } catch (e) {
      debugPrint("Failed to fetch subscription: $e");
    }
  }

  Future<String?> subscribe(String planCode) async {
    state = state.copyWith(isProcessing: planCode);
    try {
      final response = await _apiClient.subscribe(planCode, "click");
      state = state.copyWith(isProcessing: null);
      return response.checkoutUrl;
    } catch (e) {
      debugPrint("Subscribe failed: $e");
      state = state.copyWith(isProcessing: null);
      return null;
    }
  }
}

class SubscriptionView extends ConsumerStatefulWidget {
  const SubscriptionView({super.key});

  @override
  ConsumerState<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends ConsumerState<SubscriptionView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(subscriptionViewModelProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionViewModelProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        title: Text(ref.tr('subscriptions')),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentPrimary))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                   _HeaderSection(ref: ref),
                   const SizedBox(height: 24),
                   if (state.currentSubscription?.active == true) ...[
                     _CurrentPlanSection(sub: state.currentSubscription!, ref: ref),
                     const SizedBox(height: 24),
                   ],
                   ...state.plans.map((plan) => Padding(
                     padding: const EdgeInsets.only(bottom: 16),
                     child: _PlanCard(plan: plan, state: state, ref: ref, locale: locale),
                   )),
                ],
              ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final WidgetRef ref;
  const _HeaderSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(ref.tr('pro_features'), style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 8),
        Text(ref.tr('unlimited_conv'), 
             textAlign: TextAlign.center,
             style: const TextStyle(color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _CurrentPlanSection extends StatelessWidget {
  final CurrentSubscriptionResponse sub;
  final WidgetRef ref;
  const _CurrentPlanSection({required this.sub, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ref.tr('current_plan'), style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCardDecoration.copyWith(
            border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.plan?.toUpperCase() ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  if (sub.expiresAt != null)
                    Text("${ref.tr('valid_until')}: ${sub.expiresAt!.day}.${sub.expiresAt!.month}.${sub.expiresAt!.year}", 
                         style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.verified, color: AppTheme.accentPrimary, size: 28),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final SubscriptionState state;
  final WidgetRef ref;
  final String locale;
  const _PlanCard({required this.plan, required this.state, required this.ref, required this.locale});

  @override
  Widget build(BuildContext context) {
    final isCurrent = state.currentSubscription?.plan == plan.code && state.currentSubscription?.active == true;
    final isProcessing = state.isProcessing == plan.code;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              if (plan.code == 'pro') const Icon(Icons.workspace_premium, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 16),
          Text("${plan.priceUzs} UZS", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(ref.tr('month_count'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          
          const SizedBox(height: 16),
          if (plan.benefits != null)
            ...plan.benefits!.map((benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, color: AppTheme.accentPrimary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(benefit[locale] ?? benefit['uz'] ?? "", 
                                     style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
                ],
              ),
            )),
          
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (isCurrent || plan.priceUzs == 0 || state.isProcessing != null) 
                  ? null 
                  : () async {
                      final url = await ref.read(subscriptionViewModelProvider.notifier).subscribe(plan.code);
                      if (url != null) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: (isCurrent || plan.priceUzs == 0) ? Colors.white.withOpacity(0.1) : AppTheme.accentPrimary,
                disabledBackgroundColor: Colors.white.withOpacity(0.05),
              ),
              child: isProcessing 
                 ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                 : Text(isCurrent ? ref.tr('active') : (plan.priceUzs == 0 ? ref.tr('free') : ref.tr('choose'))),
            ),
          ),
        ],
      ),
    );
  }
}
