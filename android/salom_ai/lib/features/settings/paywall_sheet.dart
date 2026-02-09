import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/services/subscription_manager.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showPaywallSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (_) => const PaywallSheet(),
  );
}

class PaywallSheet extends ConsumerStatefulWidget {
  const PaywallSheet({super.key});

  @override
  ConsumerState<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<PaywallSheet> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(subscriptionManagerProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionManagerProvider);

    // Auto-dismiss when user becomes pro
    ref.listen<SubscriptionManagerState>(subscriptionManagerProvider,
        (prev, next) {
      if (next.isPro && !(prev?.isPro ?? false)) {
        Navigator.of(context).pop();
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0D2E), Color(0xFF050617)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Premium header image placeholder
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.accentPrimary.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: const Icon(Icons.workspace_premium,
                        size: 64, color: Colors.amber),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Salom AI Pro',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ref.tr('unlimited_conv'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Benefit rows
                  _BenefitRow(
                    icon: Icons.all_inclusive,
                    title: ref.tr('paywall_unlimited_messages'),
                    subtitle: ref.tr('paywall_unlimited_messages_desc'),
                  ),
                  const SizedBox(height: 12),
                  _BenefitRow(
                    icon: Icons.auto_awesome,
                    title: ref.tr('paywall_advanced_models'),
                    subtitle: ref.tr('paywall_advanced_models_desc'),
                  ),
                  const SizedBox(height: 12),
                  _BenefitRow(
                    icon: Icons.record_voice_over,
                    title: ref.tr('paywall_voice_chat'),
                    subtitle: ref.tr('paywall_voice_chat_desc'),
                  ),
                  const SizedBox(height: 12),
                  _BenefitRow(
                    icon: Icons.image,
                    title: ref.tr('paywall_image_gen'),
                    subtitle: ref.tr('paywall_image_gen_desc'),
                  ),

                  const SizedBox(height: 28),

                  // Plan selection / CTA
                  if (subState.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          color: AppTheme.accentPrimary),
                    )
                  else
                    ...subState.plans
                        .where((p) => p.priceUzs > 0)
                        .map((plan) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PlanCTA(
                                plan: plan,
                                isProcessing: _isProcessing,
                                onTap: () => _handleSubscribe(plan.code),
                              ),
                            )),

                  const SizedBox(height: 16),

                  // Dismiss button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      ref.tr('paywall_later'),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscribe(String planCode) async {
    setState(() => _isProcessing = true);
    final url =
        await ref.read(subscriptionManagerProvider.notifier).subscribe(planCode);
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    // Refresh status after returning from browser
    await Future.delayed(const Duration(seconds: 2));
    await ref.read(subscriptionManagerProvider.notifier).checkSubscriptionStatus();
    if (mounted) setState(() => _isProcessing = false);
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPrimary.withOpacity(0.3),
                  AppTheme.accentSecondary.withOpacity(0.1),
                ],
              ),
            ),
            child: Icon(icon, color: AppTheme.accentSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCTA extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isProcessing;
  final VoidCallback onTap;

  const _PlanCTA({
    required this.plan,
    required this.isProcessing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accentPrimary, Color(0xFF9333EA)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentPrimary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: isProcessing
            ? const Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${plan.name} - ${plan.priceUzs} UZS',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
