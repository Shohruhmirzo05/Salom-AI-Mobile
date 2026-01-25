import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/features/chat/chat_screen.dart';
import 'package:salom_ai/features/chat/chat_view_model.dart';
import 'package:salom_ai/features/auth/auth_service.dart';
import 'package:salom_ai/core/constants/localization.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Widget? child;
  const HomeScreen({super.key, this.child});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Load conversations on init
    Future.delayed(Duration.zero, () {
       ref.read(chatViewModelProvider.notifier).loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Current conversation ID is managed by URL usually, but if we are at root /,
    // it can be new chat (0) or last active.
    // For simplicity, let's treat / as New Chat (Id 0).
    const currentId = 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bgMain,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),

          widget.child ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final auth = ref.watch(authServiceProvider);
    final user = auth.backendUser;
    final chatState = ref.watch(chatViewModelProvider);
    final initials = user?.displayName?.substring(0, 1).toUpperCase() ?? "U";
    
    return Drawer(
      backgroundColor: AppTheme.bgSecondary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.accentPrimary,
                    child: Text(initials, style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? ref.tr('profile_card_default_user'), 
                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(user?.email ?? ref.tr('phone_not_identified'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            const Divider(color: Colors.white10),
            
            // New Chat Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  context.pop(); // Close drawer
                  context.go('/chat/0');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentPrimary,
                  minimumSize: const Size(double.infinity, 44),
                ),
                icon: const Icon(Icons.add),
                label: const Text("Yangi suhbat"),
              ),
            ),
            
            // Conversation List
            Expanded(
              child: chatState.conversations.isNotEmpty 
              ? ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: chatState.conversations.length,
                itemBuilder: (context, index) {
                  final chat = chatState.conversations[index];
                  return ListTile(
                    title: Text(chat.title ?? "Suhbat", style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text("${chat.messageCount} messages", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    onTap: () {
                      context.pop();
                      context.go('/chat/${chat.id}');
                    },
                  );
                },
              )
              : const Center(child: CircularProgressIndicator()),
            ),
            
            const Divider(color: Colors.white10),
            
             ListTile(
              leading: const Icon(Icons.settings, color: Colors.white70),
              title: Text(ref.tr('settings'), style: const TextStyle(color: Colors.white)),
              onTap: () {
                context.pop();
                context.push('/settings');
              },
            ),

            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text(ref.tr('subscription'), style: const TextStyle(color: Colors.white)),
              onTap: () {
                context.pop();
                context.push('/settings/subscription');
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: Text(ref.tr('logout'), style: const TextStyle(color: AppTheme.danger)),
              onTap: () {
                ref.read(authServiceProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
