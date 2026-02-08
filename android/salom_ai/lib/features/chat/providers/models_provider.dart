import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/api/api_client.dart';
import 'package:salom_ai/core/api/api_models.dart';

final modelsProvider = StateNotifierProvider<ModelsNotifier, ModelsState>((ref) {
  return ModelsNotifier(ref.watch(apiClientProvider));
});

class ModelsState {
  final List<AIModel> models;
  final String? selectedModelId;
  final bool isLoading;

  ModelsState({
    this.models = const [],
    this.selectedModelId,
    this.isLoading = false,
  });

  AIModel? get selectedModel {
    if (selectedModelId == null) return models.isNotEmpty ? models.first : null;
    try {
      return models.firstWhere((m) => m.id == selectedModelId);
    } catch (_) {
      return models.isNotEmpty ? models.first : null;
    }
  }

  ModelsState copyWith({
    List<AIModel>? models,
    String? selectedModelId,
    bool? isLoading,
  }) {
    return ModelsState(
      models: models ?? this.models,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ModelsNotifier extends StateNotifier<ModelsState> {
  final ApiClient _client;

  ModelsNotifier(this._client) : super(ModelsState());

  Future<void> fetchModels() async {
    state = state.copyWith(isLoading: true);
    try {
      final models = await _client.listModels();
      state = state.copyWith(models: models, isLoading: false);
    } catch (e) {
      print('Failed to fetch models: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void selectModel(String modelId) {
    state = state.copyWith(selectedModelId: modelId);
  }
}
