import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/api/api_client.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showUsageInfoSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const UsageInfoView(),
  );
}

class UsageInfoView extends ConsumerStatefulWidget {
  const UsageInfoView({super.key});

  @override
  ConsumerState<UsageInfoView> createState() => _UsageInfoViewState();
}

class _UsageInfoViewState extends ConsumerState<UsageInfoView> {
  UsageStatsResponse? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await ref.read(apiClientProvider).getUsageStats();
      if (mounted) setState(() { _stats = stats; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            ref.tr('usage_stats'),
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppTheme.accentPrimary),
            ))
          else if (_stats == null)
            Center(child: Text(ref.tr('error'), style: const TextStyle(color: Colors.white54)))
          else ...[
            // Plan info
            if (_stats!.plan != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _stats!.plan!.isPro ? Icons.workspace_premium : Icons.auto_awesome,
                      color: _stats!.plan!.isPro ? Colors.amber : Colors.white54,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_stats!.plan!.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(ref.tr('current_plan'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Usage bars
            if (_stats!.usage != null && _stats!.limits != null) ...[
              _UsageBar(
                label: ref.tr('messages'),
                used: _stats!.usage!.messagesUsed ?? 0,
                limit: _stats!.limits!.messages,
                color: AppTheme.accentPrimary,
              ),
              const SizedBox(height: 12),
              _UsageBar(
                label: ref.tr('images'),
                used: _stats!.usage!.imagesUsed ?? 0,
                limit: _stats!.limits!.images,
                color: AppTheme.accentSecondary,
              ),
              const SizedBox(height: 12),
              _UsageBar(
                label: ref.tr('files'),
                used: _stats!.usage!.filesUsed ?? 0,
                limit: _stats!.limits!.files,
                color: AppTheme.accentTertiary,
              ),
              const SizedBox(height: 12),
              _UsageBar(
                label: ref.tr('voice_minutes'),
                used: _stats!.usage!.voiceMinutesUsed ?? 0,
                limit: _stats!.limits!.voiceMinutes,
                color: Colors.amber,
              ),
            ],

            // Per-model usage
            if (_stats!.usage?.perModel != null && _stats!.usage!.perModel!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(ref.tr('per_model_usage'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._stats!.usage!.perModel!.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                    Text('${entry.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              )),
            ],
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final int used;
  final int? limit;
  final Color color;

  const _UsageBar({required this.label, required this.used, this.limit, required this.color});

  @override
  Widget build(BuildContext context) {
    final progress = limit != null && limit! > 0 ? (used / limit!).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const Spacer(),
            Text(
              limit != null ? '$used / $limit' : '$used',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
