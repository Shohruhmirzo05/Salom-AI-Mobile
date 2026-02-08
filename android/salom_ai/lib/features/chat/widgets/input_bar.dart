import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/features/chat/providers/attachment_provider.dart';
import 'package:salom_ai/features/chat/widgets/attachment_preview.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:salom_ai/core/services/haptic_manager.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onVoiceRecord;
  final bool isImageMode;
  final ValueChanged<bool> onImageModeChanged;
  final bool isSending;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onVoiceRecord,
    required this.isImageMode,
    required this.onImageModeChanged,
    this.isSending = false,
  });

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attachments = ref.watch(attachmentProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attachment previews
          if (attachments.items.isNotEmpty) const AttachmentPreviewRow(),

          // Top row: toggles
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                // Image mode toggle
                _MiniToggle(
                  icon: Icons.image,
                  isActive: widget.isImageMode,
                  onTap: () {
                    HapticManager.selection();
                    widget.onImageModeChanged(!widget.isImageMode);
                  },
                ),
                const SizedBox(width: 8),
                // Attachment button
                _MiniToggle(
                  icon: Icons.attach_file,
                  isActive: false,
                  onTap: () => _showAttachmentOptions(context),
                ),
                const SizedBox(width: 8),
                // Voice button
                _MiniToggle(
                  icon: Icons.mic,
                  isActive: false,
                  onTap: widget.onVoiceRecord,
                ),
              ],
            ),
          ),

          // Bottom row: text field + send
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: widget.isImageMode
                          ? LinearGradient(
                              colors: [
                                AppTheme.accentPrimary.withOpacity(0.15),
                                AppTheme.accentSecondary.withOpacity(0.08),
                              ],
                            )
                          : null,
                      color: widget.isImageMode ? null : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: widget.isImageMode
                          ? Border.all(color: AppTheme.accentPrimary.withOpacity(0.3))
                          : null,
                    ),
                    child: TextField(
                      controller: widget.controller,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: widget.isImageMode
                            ? ref.tr('image_prompt_hint')
                            : ref.tr('message_hint'),
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                GestureDetector(
                  onTap: (_hasText && !widget.isSending) ? () {
                    HapticManager.light();
                    widget.onSend();
                  } : null,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: (_hasText && !widget.isSending)
                          ? const LinearGradient(
                              colors: [AppTheme.accentPrimary, AppTheme.accentSecondary],
                            )
                          : null,
                      color: (_hasText && !widget.isSending) ? null : Colors.white.withOpacity(0.1),
                    ),
                    child: widget.isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.arrow_upward, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    HapticManager.selection();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: AppTheme.accentSecondary),
              title: Text(ref.tr('photo'), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(attachmentProvider.notifier).pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: AppTheme.accentTertiary),
              title: Text(ref.tr('document'), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(attachmentProvider.notifier).pickDocument();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _MiniToggle({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? AppTheme.accentPrimary.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
          border: isActive
              ? Border.all(color: AppTheme.accentPrimary.withOpacity(0.5))
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? AppTheme.accentPrimary : Colors.white54,
        ),
      ),
    );
  }
}
