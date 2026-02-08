import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/features/chat/providers/attachment_provider.dart';

class AttachmentPreviewRow extends ConsumerWidget {
  const AttachmentPreviewRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(attachmentProvider);

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: attachments.items.length,
        itemBuilder: (context, index) {
          final item = attachments.items[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: item.isImage
                      ? Image.file(item.file, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.description, color: Colors.white54, size: 24),
                            const SizedBox(height: 2),
                            Text(
                              item.name.length > 8 ? '${item.name.substring(0, 8)}...' : item.name,
                              style: const TextStyle(color: Colors.white54, fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                ),
                // Upload indicator
                if (item.isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black54,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                // Remove button
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () => ref.read(attachmentProvider.notifier).removeItem(index),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.danger,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
