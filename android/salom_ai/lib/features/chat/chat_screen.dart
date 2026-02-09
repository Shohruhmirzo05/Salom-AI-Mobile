import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:salom_ai/core/api/api_client.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/theme/shimmer.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:salom_ai/core/services/haptic_manager.dart';
import 'package:salom_ai/features/chat/chat_view_model.dart';
import 'package:salom_ai/features/chat/providers/models_provider.dart';
import 'package:salom_ai/features/chat/providers/attachment_provider.dart';
import 'package:salom_ai/features/chat/widgets/input_bar.dart';
import 'package:salom_ai/features/chat/widgets/image_viewer.dart';
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
    // Fetch models on first load
    Future.microtask(() => ref.read(modelsProvider.notifier).fetchModels());
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
          ref.read(chatViewModelProvider.notifier).loadConversation(widget.conversationId));
    } else {
      Future.microtask(() =>
          ref.read(chatViewModelProvider.notifier).clearMessages());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _jumpToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _sendMessage() {
    final state = ref.read(chatViewModelProvider);
    final modelState = ref.read(modelsProvider);
    final attachments = ref.read(attachmentProvider);

    if (state.isImageMode) {
      ref.read(chatViewModelProvider.notifier).generateImage(_textController.text);
    } else {
      ref.read(chatViewModelProvider.notifier).sendMessage(
        _textController.text,
        conversationId: widget.conversationId,
        model: modelState.selectedModel?.id,
        attachments: attachments.uploadedUrls.isNotEmpty ? attachments.uploadedUrls : null,
      );
    }
    _textController.clear();
    ref.read(attachmentProvider.notifier).clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _handleVoiceRecord() async {
    // Record audio and send to STT
    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/stt_recording_${DateTime.now().millisecondsSinceEpoch}.wav');
      // For now, show a snackbar - full voice-to-text uses the realtime voice view
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.tr('voice_chat')),
          action: SnackBarAction(label: ref.tr('ok'), onPressed: () {}),
        ),
      );
    } catch (e) {
      debugPrint('Voice record error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatViewModelProvider);

    ref.listen(chatViewModelProvider, (prev, next) {
      final messagesChanged = next.messages.length != (prev?.messages.length ?? 0);
      final lastMessageContentChanged = (next.messages.isNotEmpty && prev?.messages.isNotEmpty == true) &&
          (next.messages.last.text != prev?.messages.last.text);

      if (messagesChanged || lastMessageContentChanged) {
        if (next.isSending && lastMessageContentChanged) {
          _jumpToBottom();
        } else {
          _scrollToBottom();
        }
      }
    });

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          _buildTopBar(state),
          Expanded(
            child: state.messages.isEmpty && !state.isLoading
                ? _buildEmptyState()
                : state.isLoading
                    ? _buildLoadingState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 20, top: 10),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final msg = state.messages[index];
                          // Show shimmer for empty assistant message during generation
                          if (msg.role == MessageRole.assistant &&
                              (msg.text == null || msg.text!.isEmpty) &&
                              (state.isSending || state.isGeneratingImage)) {
                            return const ShimmerMessagePlaceholder();
                          }
                          return _buildMessage(msg);
                        },
                      ),
          ),
          ChatInputBar(
            controller: _textController,
            onSend: _sendMessage,
            onVoiceRecord: _handleVoiceRecord,
            isImageMode: state.isImageMode,
            onImageModeChanged: (v) =>
                ref.read(chatViewModelProvider.notifier).toggleImageMode(),
            isSending: state.isSending || state.isGeneratingImage,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ChatState state) {
    final modelState = ref.watch(modelsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.currentConversation?.title ?? 'Salom AI',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  state.isLoading
                      ? ref.tr('loading')
                      : '${state.messages.length} ${ref.tr('messages').toLowerCase()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          // Model selector
          if (modelState.models.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.auto_awesome, color: AppTheme.accentSecondary, size: 20),
              color: AppTheme.bgSecondary,
              onSelected: (modelId) {
                HapticManager.selection();
                ref.read(modelsProvider.notifier).selectModel(modelId);
              },
              itemBuilder: (ctx) => modelState.models.map((m) => PopupMenuItem(
                value: m.id,
                child: Row(
                  children: [
                    if (m.id == modelState.selectedModelId)
                      const Icon(Icons.check, color: AppTheme.accentPrimary, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                    if (m.tier != null && m.tier != 'free')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(m.tier!, style: const TextStyle(color: Colors.amber, fontSize: 10)),
                      ),
                  ],
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/app_icon_transparent.png',
              width: 80, height: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(ref.tr('message_hint').replaceAll('...', '?'),
              style: const TextStyle(color: Colors.white54, fontSize: 18)),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(3, (i) => ShimmerMessagePlaceholder(isUser: i % 2 == 0)),
    );
  }

  Widget _buildMessage(MessageDTO msg) {
    final isUser = msg.role == MessageRole.user;

    return GestureDetector(
      onLongPress: () => _showMessageMenu(msg),
      child: Align(
        key: Key(msg.id.toString()),
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            gradient: isUser
                ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF1ED6FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isUser ? null : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: isUser ? null : Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Inline images
              if (msg.imageUrls != null && msg.imageUrls!.isNotEmpty)
                ...msg.imageUrls!.map((url) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => ImageViewer.show(context, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => AppShimmer(
                          child: SizedBox(height: 200, width: double.infinity),
                        ),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38),
                      ),
                    ),
                  ),
                )),

              // Text content
              if (msg.text != null && msg.text!.isNotEmpty)
                isUser
                    ? Text(msg.text!, style: GoogleFonts.inter(fontSize: 16, color: Colors.white))
                    : MarkdownBody(
                        data: msg.text!,
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          p: GoogleFonts.inter(fontSize: 16, color: Colors.white),
                          code: GoogleFonts.robotoMono(backgroundColor: Colors.black38, color: Colors.white),
                          codeblockDecoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),

              // File URLs
              if (msg.fileUrls != null && msg.fileUrls!.isNotEmpty)
                ...msg.fileUrls!.map((url) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, color: AppTheme.accentSecondary, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          url.split('/').last,
                          style: const TextStyle(color: AppTheme.accentSecondary, fontSize: 13, decoration: TextDecoration.underline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),

              // Search results
              if (msg.searchResults != null && msg.searchResults!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: msg.searchResults!.map((sr) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sr.title ?? sr.url ?? '',
                        style: const TextStyle(color: AppTheme.accentSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                  ),
                ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
    );
  }

  void _showMessageMenu(MessageDTO msg) {
    if (msg.text == null || msg.text!.isEmpty) return;
    HapticManager.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: Text(ref.tr('copy'), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.text!));
                Navigator.pop(ctx);
                HapticManager.success();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white70),
              title: Text(ref.tr('share'), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(msg.text!);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
