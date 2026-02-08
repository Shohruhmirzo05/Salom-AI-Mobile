import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:salom_ai/core/api/api_client.dart';

final attachmentProvider =
    StateNotifierProvider.autoDispose<AttachmentNotifier, AttachmentState>((ref) {
  return AttachmentNotifier(ref.watch(apiClientProvider));
});

class AttachmentState {
  final List<AttachmentItem> items;
  final bool isUploading;

  AttachmentState({this.items = const [], this.isUploading = false});

  AttachmentState copyWith({List<AttachmentItem>? items, bool? isUploading}) {
    return AttachmentState(
      items: items ?? this.items,
      isUploading: isUploading ?? this.isUploading,
    );
  }

  List<String> get uploadedUrls =>
      items.where((i) => i.uploadedUrl != null).map((i) => i.uploadedUrl!).toList();
}

class AttachmentItem {
  final File file;
  final String name;
  final bool isImage;
  final String? uploadedUrl;
  final bool isUploading;

  AttachmentItem({
    required this.file,
    required this.name,
    this.isImage = false,
    this.uploadedUrl,
    this.isUploading = false,
  });

  AttachmentItem copyWith({String? uploadedUrl, bool? isUploading}) {
    return AttachmentItem(
      file: file,
      name: name,
      isImage: isImage,
      uploadedUrl: uploadedUrl ?? this.uploadedUrl,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

class AttachmentNotifier extends StateNotifier<AttachmentState> {
  final ApiClient _client;
  final _picker = ImagePicker();

  AttachmentNotifier(this._client) : super(AttachmentState());

  Future<void> pickImage() async {
    try {
      final xFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (xFile == null) return;
      final file = File(xFile.path);
      final item = AttachmentItem(
        file: file,
        name: xFile.name,
        isImage: true,
        isUploading: true,
      );
      state = state.copyWith(items: [...state.items, item]);
      await _uploadItem(state.items.length - 1);
    } catch (e) {
      debugPrint('Pick image error: $e');
    }
  }

  Future<void> pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;
      final pf = result.files.first;
      if (pf.path == null) return;
      final file = File(pf.path!);
      final item = AttachmentItem(
        file: file,
        name: pf.name,
        isImage: false,
        isUploading: true,
      );
      state = state.copyWith(items: [...state.items, item]);
      await _uploadItem(state.items.length - 1);
    } catch (e) {
      debugPrint('Pick document error: $e');
    }
  }

  Future<void> _uploadItem(int index) async {
    try {
      state = state.copyWith(isUploading: true);
      final item = state.items[index];
      final response = await _client.uploadFile(item.file);
      final updated = List<AttachmentItem>.from(state.items);
      updated[index] = item.copyWith(uploadedUrl: response.url, isUploading: false);
      state = state.copyWith(items: updated, isUploading: false);
    } catch (e) {
      debugPrint('Upload error: $e');
      final updated = List<AttachmentItem>.from(state.items);
      updated[index] = updated[index].copyWith(isUploading: false);
      state = state.copyWith(items: updated, isUploading: false);
    }
  }

  void removeItem(int index) {
    final updated = List<AttachmentItem>.from(state.items);
    updated.removeAt(index);
    state = state.copyWith(items: updated);
  }

  void clear() {
    state = AttachmentState();
  }
}
