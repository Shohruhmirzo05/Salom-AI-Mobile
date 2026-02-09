import 'package:flutter/material.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/theme/app_theme.dart';

class SearchHitRow extends StatelessWidget {
  final MessageSearchHit hit;
  final VoidCallback onTap;

  const SearchHitRow({
    super.key,
    required this.hit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Icon(
        hit.role == 'user' ? Icons.person_outline : Icons.smart_toy_outlined,
        color: Colors.white38,
        size: 20,
      ),
      title: Text(
        hit.conversationTitle ?? 'Suhbat #${hit.conversationId}',
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        hit.text ?? '',
        style: const TextStyle(color: Colors.white38, fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
