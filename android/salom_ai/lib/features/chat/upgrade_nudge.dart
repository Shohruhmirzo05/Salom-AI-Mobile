// A non-blocking floating chip that nudges free-tier users toward Pro
// when they've burned through ≥70% of a resource. Tap → opens the
// paywall sheet. Dismissable for the rest of the session.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salom_ai/core/api/api_client.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/services/subscription_manager.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/features/settings/paywall_sheet.dart';

class UpgradeNudge extends ConsumerStatefulWidget {
  const UpgradeNudge({super.key});

  @override
  ConsumerState<UpgradeNudge> createState() => _UpgradeNudgeState();
}

class _UpgradeNudgeState extends ConsumerState<UpgradeNudge> {
  UsageStatsResponse? _usage;
  bool _dismissedThisSession = false;
  bool _loading = false;

  static const double _threshold = 0.7;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final stats = await api.getUsageStats();
      if (!mounted) return;
      setState(() => _usage = stats);
    } catch (_) {
      // best-effort, no nudge if API fails
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _NudgePayload? _computeNudge() {
    if (_dismissedThisSession) return null;
    final subState = ref.read(subscriptionManagerProvider);
    final isFree = !subState.isPro;
    if (!isFree) return null;
    if (_usage == null) return null;

    final limits = _usage!.limits;
    final usage = _usage!.usage;
    if (limits == null || usage == null) return null;

    final slots = <_Slot>[
      _Slot('Xabarlar', usage.messagesUsed ?? 0, limits.messages ?? 0),
      _Slot('Rasm yaratishlar', usage.imagesUsed ?? 0, limits.images ?? 0),
      _Slot('Fayllar', usage.filesUsed ?? 0, limits.files ?? 0),
      _Slot("Ovozli daqiqalar", usage.voiceMinutesUsed ?? 0,
          limits.voiceMinutes ?? 0),
    ].where((s) => s.limit > 0 && s.used >= s.limit * _threshold).toList();

    if (slots.isEmpty) return null;
    slots.sort((a, b) => (b.used / b.limit).compareTo(a.used / a.limit));
    final top = slots.first;
    final remaining = (top.limit - top.used).clamp(0, top.limit);
    final text = remaining <= 0
        ? "${top.label}: limit tugadi. Pro rejaga o'tib davom eting."
        : "${top.label}: $remaining qoldi. Pro rejaga o'ting.";
    return _NudgePayload(text);
  }

  @override
  Widget build(BuildContext context) {
    final payload = _computeNudge();
    if (payload == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showPaywallSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPrimary.withOpacity(0.18),
                  AppTheme.accentPrimary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accentPrimary.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPrimary.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppTheme.accentPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payload.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "Rejani ko'rish →",
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.accentPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () {
                    setState(() => _dismissedThisSession = true);
                  },
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Slot {
  final String label;
  final int used;
  final int limit;
  _Slot(this.label, this.used, this.limit);
}

class _NudgePayload {
  final String text;
  _NudgePayload(this.text);
}
