import 'package:flutter/material.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/theme/app_theme.dart';

class ConversationRow extends StatelessWidget {
  final ConversationSummary conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('conv_${conversation.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: AppTheme.danger, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(Icons.chat_bubble_outline,
            color: Colors.white.withOpacity(0.3), size: 18),
        title: Text(
          conversation.title ?? 'Suhbat',
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${conversation.messageCount ?? 0} xabar',
          style: const TextStyle(color: Colors.white30, fontSize: 11),
        ),
        onTap: onTap,
        trailing: IconButton(
          icon: Icon(Icons.delete_outline,
              color: Colors.white.withOpacity(0.2), size: 18),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
