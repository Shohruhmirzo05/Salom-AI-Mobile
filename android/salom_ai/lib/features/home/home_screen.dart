import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/features/auth/auth_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salom AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, color: Colors.amber),
            onPressed: () {
              // Open Plan/Settings
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Create new chat
              context.go('/chat/0'); 
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.card,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.background),
              accountName: Text('${ref.read(authServiceProvider).currentUser?.email ?? "User"}'),
              accountEmail: const Text('Premium Plan'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: AppTheme.primary,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white70),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.error),
              title: const Text('Log Out', style: TextStyle(color: AppTheme.error)),
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Recent Conversations
          Text('Recent Chats', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _buildConversationItem(context, 'Creative Writing', 'Last seen 2m ago', 1),
          _buildConversationItem(context, 'Python Help', 'Last seen 1h ago', 2),
          _buildConversationItem(context, 'Recipe Project', 'Last seen 1d ago', 3),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/chat/0'),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('New Chat'),
      ),
    );
  }

  Widget _buildConversationItem(BuildContext context, String title, String subtitle, int id) {
    return Card(
      color: AppTheme.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => context.go('/chat/\$id'),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.chat, color: AppTheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      ),
    );
  }
}
