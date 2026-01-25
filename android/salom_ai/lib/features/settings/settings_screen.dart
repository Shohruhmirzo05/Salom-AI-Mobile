import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salom_ai/core/api/api_client.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/features/auth/auth_service.dart';
import 'package:salom_ai/core/constants/localization.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _currentPlanName = "Yuklanmoqda...";
  bool _isPremium = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionStatus();
  }

  Future<void> _fetchSubscriptionStatus() async {
    try {
      final sub = await ref.read(apiClientProvider).currentSubscription();
      if (mounted) {
        setState(() {
          if (sub.active && sub.plan != null) {
            _currentPlanName = sub.plan!.toUpperCase();
            _isPremium = true;
          } else {
            _currentPlanName = ref.tr('free');
            _isPremium = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentPlanName = ref.tr('free');
          _isPremium = false;
        });
      }
    }
  }

  Future<void> _updateLanguage(String code) async {
    try {
      await ref.read(apiClientProvider).updateProfile(language: code);
      ref.read(localeProvider.notifier).setLocale(code);
    } catch (e) {
      debugPrint("Failed to update language: $e");
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);
    try {
      await ref.read(apiClientProvider).deleteAccount();
      await ref.read(authServiceProvider).signOut();
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${ref.tr('error')}: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final user = auth.backendUser;
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        title: Text(ref.tr('settings')),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            _buildProfileCard(user),
            const SizedBox(height: 20),
            _buildSubscriptionSection(),
            const SizedBox(height: 20),
            _buildSupportSection(),
            const SizedBox(height: 20),
            _buildLanguageSection(locale),
            const SizedBox(height: 20),
            _buildDangerZone(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(OAuthUser? user) {
    final initials = user?.displayName?.substring(0, 1).toUpperCase() ?? "U";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: AppTheme.accentPrimary,
            child: Text(initials, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.displayName ?? ref.tr('profile_card_default_user'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(user?.email ?? ref.tr('phone_not_identified'),
                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ref.tr('subscription').toUpperCase(),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => context.push('/settings/subscription'),
            leading: Icon(
              _isPremium ? Icons.workspace_premium : Icons.auto_awesome,
              color: _isPremium ? Colors.amber : Colors.grey,
            ),
            title: Text(_currentPlanName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ref.tr('help').toUpperCase(),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => context.push('/settings/feedback'),
            leading: const Icon(Icons.forum, color: Colors.blue),
            title: Text(ref.tr('send_feedback'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection(String currentLocale) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ref.tr('language').toUpperCase(),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'uz', label: Text(ref.tr('uzbek'))),
              ButtonSegment(value: 'ru', label: Text(ref.tr('russian'))),
              ButtonSegment(value: 'en', label: Text(ref.tr('english'))),
            ],
            selected: {currentLocale},
            onSelectionChanged: (val) => _updateLanguage(val.first),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              selectedBackgroundColor: AppTheme.accentPrimary,
              foregroundColor: Colors.white,
              selectedForegroundColor: Colors.white,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ref.tr('login_info').toUpperCase(),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => ref.read(authServiceProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: Text(ref.tr('logout')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                foregroundColor: Colors.red,
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _isDeleting ? null : _showDeleteDialog,
              child: _isDeleting 
                ? const CircularProgressIndicator(color: Colors.red)
                : Text(ref.tr('delete_account'), style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ref.tr('delete_account_title')),
        content: Text(ref.tr('delete_account_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ref.tr('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: Text(ref.tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
