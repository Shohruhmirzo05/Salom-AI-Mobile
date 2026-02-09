import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/services/subscription_manager.dart';
import 'package:salom_ai/features/chat/chat_screen.dart';
import 'package:salom_ai/features/chat/chat_view_model.dart';
import 'package:salom_ai/features/voice/realtime_voice_view.dart';
import 'package:salom_ai/features/notifications/notification_history_view.dart';
import 'package:salom_ai/features/home/widgets/side_menu.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Widget? child;
  const HomeScreen({super.key, this.child});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  MenuSection _selectedSection = MenuSection.chat;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      ref.read(chatViewModelProvider.notifier).loadConversations();
      ref.read(subscriptionManagerProvider.notifier).loadAll();
    });
  }

  void _onSectionChanged(MenuSection section) {
    if (section == MenuSection.settings) return; // Handled by GoRouter push
    setState(() => _selectedSection = section);
    Navigator.pop(context); // Close drawer
  }

  void _onNewChat() {
    setState(() => _selectedSection = MenuSection.chat);
    context.go('/chat/0');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bgMain,
      drawer: SideMenu(
        selectedSection: _selectedSection,
        onSectionChanged: _onSectionChanged,
        onNewChat: _onNewChat,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedSection) {
      case MenuSection.chat:
        return widget.child ?? ChatScreen(
          conversationId: 0,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case MenuSection.voice:
        return const RealtimeVoiceView();
      case MenuSection.notifications:
        return const NotificationHistoryView();
      case MenuSection.settings:
        return widget.child ?? const SizedBox.shrink();
    }
  }
}
