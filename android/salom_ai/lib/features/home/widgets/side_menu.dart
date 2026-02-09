import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:salom_ai/core/services/subscription_manager.dart';
import 'package:salom_ai/features/auth/auth_service.dart';
import 'package:salom_ai/features/chat/chat_view_model.dart';
import 'package:salom_ai/features/home/widgets/conversation_row.dart';
import 'package:salom_ai/features/home/widgets/menu_item_row.dart';
import 'package:salom_ai/features/home/widgets/search_hit_row.dart';
import 'package:salom_ai/features/settings/paywall_sheet.dart';
import 'package:salom_ai/core/services/haptic_manager.dart';
import 'package:google_fonts/google_fonts.dart';

enum MenuSection { chat, voice, notifications, settings }

class SideMenu extends ConsumerStatefulWidget {
  final MenuSection selectedSection;
  final ValueChanged<MenuSection> onSectionChanged;
  final VoidCallback onNewChat;

  const SideMenu({
    super.key,
    required this.selectedSection,
    required this.onSectionChanged,
    required this.onNewChat,
  });

  @override
  ConsumerState<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends ConsumerState<SideMenu> {
  final _searchController = TextEditingController();
  List<MessageSearchHit>? _searchResults;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    // Debounce: just trigger search after a brief pause
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_searchController.text.trim() == query.trim() && mounted) {
        _performSearch(query.trim());
      }
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final response =
          await ref.read(chatViewModelProvider.notifier).searchMessages(query);
      if (mounted) {
        setState(() {
          _searchResults = response;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final user = auth.backendUser;
    final chatState = ref.watch(chatViewModelProvider);
    final subState = ref.watch(subscriptionManagerProvider);
    final initials =
        user?.displayName?.isNotEmpty == true ? user!.displayName!.substring(0, 1).toUpperCase() : 'U';

    return Drawer(
      backgroundColor: AppTheme.bgSecondary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App icon header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Image.asset('assets/images/app_icon_transparent.png',
                      width: 32, height: 32),
                  const SizedBox(width: 10),
                  Text(
                    'Salom AI',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: ref.tr('search'),
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                    prefixIcon: Icon(Icons.search,
                        color: Colors.white.withOpacity(0.4), size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // Section rows
            MenuItemRow(
              icon: Icons.chat_bubble_outline,
              label: ref.tr('chat'),
              isSelected: widget.selectedSection == MenuSection.chat,
              onTap: () {
                HapticManager.selection();
                widget.onSectionChanged(MenuSection.chat);
              },
            ),
            MenuItemRow(
              icon: Icons.mic_none,
              label: ref.tr('voice_chat'),
              isSelected: widget.selectedSection == MenuSection.voice,
              onTap: () {
                HapticManager.selection();
                widget.onSectionChanged(MenuSection.voice);
              },
            ),
            MenuItemRow(
              icon: Icons.notifications_none,
              label: ref.tr('notifications'),
              isSelected: widget.selectedSection == MenuSection.notifications,
              onTap: () {
                HapticManager.selection();
                widget.onSectionChanged(MenuSection.notifications);
              },
            ),
            MenuItemRow(
              icon: Icons.settings_outlined,
              label: ref.tr('settings'),
              isSelected: widget.selectedSection == MenuSection.settings,
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),

            const Divider(color: Colors.white10, height: 1),

            // Pro upgrade banner (if not pro)
            if (!subState.isPro)
              Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    showPaywallSheet(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentPrimary.withOpacity(0.2),
                          AppTheme.accentSecondary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.accentPrimary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium,
                            color: Colors.amber, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.tr('upgrade_to_pro'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                ref.tr('unlock_all_features'),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Colors.white54, size: 20),
                      ],
                    ),
                  ),
                ),
              ),

            // New Chat button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticManager.light();
                    Navigator.pop(context);
                    widget.onNewChat();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentPrimary,
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(ref.tr('new_chat')),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Conversation list or search results
            Expanded(
              child: _searchResults != null
                  ? _buildSearchResults()
                  : _buildConversationList(chatState),
            ),

            const Divider(color: Colors.white10, height: 1),

            // Profile section at bottom
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.accentPrimary,
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? ref.tr('profile_card_default_user'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout,
                        color: AppTheme.danger, size: 20),
                    onPressed: () {
                      ref.read(authServiceProvider).signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationList(ChatState chatState) {
    if (chatState.conversations.isEmpty) {
      return const Center(
        child: Text('',
            style: TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: chatState.conversations.length,
      itemBuilder: (context, index) {
        final conv = chatState.conversations[index];
        return ConversationRow(
          conversation: conv,
          onTap: () {
            Navigator.pop(context);
            context.go('/chat/${conv.id}');
          },
          onDelete: () {
            ref.read(chatViewModelProvider.notifier).deleteConversation(conv.id);
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentPrimary),
      );
    }
    if (_searchResults!.isEmpty) {
      return Center(
        child: Text(ref.tr('no_results'),
            style: const TextStyle(color: Colors.white38)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _searchResults!.length,
      itemBuilder: (context, index) {
        final hit = _searchResults![index];
        return SearchHitRow(
          hit: hit,
          onTap: () {
            Navigator.pop(context);
            context.go('/chat/${hit.conversationId}');
          },
        );
      },
    );
  }
}
