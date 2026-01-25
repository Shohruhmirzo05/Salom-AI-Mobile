import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/features/chat/chat_view_model.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int conversationId;
  final VoidCallback? onMenuTap;
  
  const ChatScreen({super.key, required this.conversationId, this.onMenuTap});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _loadConversation();
  }
  
  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _loadConversation();
    }
  }
  
  void _loadConversation() {
    if (widget.conversationId != 0) {
      Future.microtask(() => 
        ref.read(chatViewModelProvider.notifier).loadConversation(widget.conversationId)
      );
    } else {
      Future.microtask(() => 
        ref.read(chatViewModelProvider.notifier).clearMessages()
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200, // Extra scroll
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    ref.read(chatViewModelProvider.notifier).sendMessage(
      _textController.text, 
      conversationId: widget.conversationId
    );
    _textController.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
     final state = ref.watch(chatViewModelProvider);
     
     // Auto scroll on new messages
     ref.listen(chatViewModelProvider, (prev, next) {
        if (next.messages.length > (prev?.messages.length ?? 0)) {
           Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
     });

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          // Top Bar
          _buildTopBar(state),
          
          // Messages
          Expanded(
            child: state.messages.isEmpty && !state.isLoading
            ? _buildEmptyState()
            : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 20, top: 10),
              itemCount: state.messages.length + (state.isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= state.messages.length) {
                   return const Padding(
                     padding: EdgeInsets.all(16.0),
                     child: Center(child: CircularProgressIndicator(color: AppTheme.accentPrimary)),
                   );
                }
                
                final msg = state.messages[index];
                return _buildMessage(msg);
              },
            ),
          ),
          
          // Input
          _buildInputBar(),
        ],
      ),
    );
  }
  
  Widget _buildTopBar(ChatState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
         border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
         color: AppTheme.bgMain.withOpacity(0.8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: widget.onMenuTap,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.currentConversation?.title ?? "Salom AI",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                ),
                Text(
                  state.isLoading ? "Yuklanmoqda..." : "${state.messages.length} xabar",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onPressed: () {},
          )
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
            Image.asset('assets/images/app_icon_transparent.png', width: 80, height: 80, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text("Qanday yordam bera olaman?", style: TextStyle(color: Colors.white54, fontSize: 18)),
         ],
       ).animate().fadeIn(),
     );
  }
  
  Widget _buildMessage(MessageDTO msg) {
    final isUser = msg.role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
         constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
         decoration: BoxDecoration(
           color: isUser ? AppTheme.accentPrimary : AppTheme.card,
           borderRadius: BorderRadius.only(
             topLeft: const Radius.circular(20),
             topRight: const Radius.circular(20),
             bottomLeft: Radius.circular(isUser ? 20 : 4),
             bottomRight: Radius.circular(isUser ? 4 : 20),
           ),
         ),
         child: isUser 
             ? Text(msg.text ?? "", style: GoogleFonts.inter(fontSize: 16, color: Colors.white))
             : MarkdownBody(
                 data: msg.text ?? "",
                 styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                   p: GoogleFonts.inter(fontSize: 16, color: Colors.white),
                   code: GoogleFonts.robotoMono(backgroundColor: Colors.black38, color: Colors.white),
                   codeblockDecoration: BoxDecoration(
                     color: Colors.black26,
                     borderRadius: BorderRadius.circular(8),
                   ),
                 ),
               ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
         border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white70),
            onPressed: () {}, // Attach
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: "Xabar yozing...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentPrimary,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
