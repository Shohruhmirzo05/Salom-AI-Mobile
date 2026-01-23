import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/api/api_client.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// Simple State Provider for chat messages
final chatMessagesProvider = StateProvider.family<List<MessageDTO>, int>((ref, convId) => []);

class ChatScreen extends ConsumerStatefulWidget {
  final int? conversationId;
  const ChatScreen({super.key, this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  
  // Local messages state to show immediate UI updates
  List<MessageDTO> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (widget.conversationId != null && widget.conversationId != 0) {
      // Mock loading or fetch from API
      // final msgs = await ref.read(apiClientProvider).getConversationMessages(widget.conversationId!);
      // setState(() => _messages = msgs);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    _controller.clear();
    setState(() {
      _messages.add(MessageDTO(id: 0, role: MessageRole.user, text: text, createdAt: DateTime.now()));
      _isSending = true;
    });
    
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final response = await ref.read(apiClientProvider).sendChatMessage(
        text,
        conversationId: widget.conversationId == 0 ? null : widget.conversationId,
      );
      
      setState(() {
        _messages.add(MessageDTO(
          id: 1, 
          role: MessageRole.assistant, 
          text: response.reply, 
          createdAt: DateTime.now()
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(MessageDTO(
          id: -1, 
          role: MessageRole.system, 
          text: "Error sending message: \$e", 
          createdAt: DateTime.now()
        ));
      });
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salom AI'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(backgroundColor: Colors.transparent, color: AppTheme.primary),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageDTO msg) {
    final isUser = msg.role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : AppTheme.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: isUser 
          ? Text(msg.text ?? "", style: const TextStyle(color: Colors.white, fontSize: 16))
          : MarkdownBody(
              data: msg.text ?? "",
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: const TextStyle(color: Colors.white, fontSize: 16),
                code: TextStyle(backgroundColor: Colors.black.withOpacity(0.3), fontFamily: 'monospace'),
              ),
            ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  fillColor: AppTheme.background,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: _sendMessage,
              mini: true,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}
