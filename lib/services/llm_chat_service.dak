import 'dart:async';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'llm_download_service.dart';

class LLMChatService {
  LlamaController? _llamaController;
  final LLMDownloadService _downloadService = LLMDownloadService();

  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  // System prompt for emotional support
  static const String SYSTEM_PROMPT = """You are a caring and empathetic AI assistant designed to help students with stress, exams, and emotional well-being. Your role is to:
- Provide reassurance and encouragement
- Help students manage exam anxiety and stress
- Offer practical study tips when needed
- Listen without judgment
- Give nurturing, supportive responses
- Keep responses concise and friendly

Always be warm, understanding, and positive.""";

  // Load the model
  Future<bool> loadModel() async {
    try {
      // Check if model is downloaded
      final modelPath = await _downloadService.getModelPath();
      if (modelPath == null) {
        print('Model not downloaded yet');
        return false;
      }

      // Initialize controller if not already done
      _llamaController ??= LlamaController();

      // Load the model - parameters go in generate(), not loadModel()
      await _llamaController!.loadModel(
        modelPath: modelPath,
        contextSize: 2048,
        threads: 4,
      );

      _isModelLoaded = true;
      print('Model loaded successfully');
      return true;

    } catch (e) {
      print('Error loading model: $e');
      _isModelLoaded = false;
      return false;
    }
  }

  // Generate response with streaming
  Stream<String> generateResponse(String userMessage, List<Map<String, String>> conversationHistory) async* {
    if (!_isModelLoaded || _llamaController == null) {
      yield 'Error: Model not loaded. Please download the AI model from settings.';
      return;
    }

    try {
      // Build conversation context
      final prompt = _buildPrompt(userMessage, conversationHistory);

      // Generate response with streaming - parameters go here
      await for (final token in _llamaController!.generate(
        prompt: prompt,
        maxTokens: 512,
        temperature: 0.7,
        topK: 40,
        topP: 0.9,
        repeatPenalty: 1.1,
      )) {
        yield token;
      }

    } catch (e) {
      print('Error generating response: $e');
      yield 'I apologize, but I encountered an error. Please try again.';
    }
  }

  // Build prompt with conversation history
  String _buildPrompt(String userMessage, List<Map<String, String>> history) {
    final buffer = StringBuffer();

    // Add system prompt
    buffer.writeln('System: $SYSTEM_PROMPT\n');

    // Add conversation history (last 5 messages to stay within context)
    final recentHistory = history.length > 5 ? history.sublist(history.length - 5) : history;
    for (final msg in recentHistory) {
      final role = msg['role'] == 'user' ? 'User' : 'Assistant';
      buffer.writeln('$role: ${msg['content']}\n');
    }

    // Add current user message
    buffer.writeln('User: $userMessage\n');
    buffer.write('Assistant:');

    return buffer.toString();
  }

  // Simple non-streaming response (for simpler use cases)
  Future<String> generateSimpleResponse(String userMessage) async {
    if (!_isModelLoaded || _llamaController == null) {
      return 'Error: Model not loaded. Please download the AI model from settings.';
    }

    try {
      final prompt = 'System: $SYSTEM_PROMPT\n\nUser: $userMessage\n\nAssistant:';
      final buffer = StringBuffer();

      await for (final token in _llamaController!.generate(
        prompt: prompt,
        maxTokens: 512,
        temperature: 0.7,
        topK: 40,
        topP: 0.9,
        repeatPenalty: 1.1,
      )) {
        buffer.write(token);
      }

      return buffer.toString().trim();

    } catch (e) {
      print('Error generating response: $e');
      return 'I apologize, but I encountered an error. Please try again.';
    }
  }

  // Stop generation mid-process
  Future<void> stopGeneration() async {
    try {
      await _llamaController?.stop();
    } catch (e) {
      print('Error stopping generation: $e');
    }
  }

  // Unload model to free memory
  Future<void> unloadModel() async {
    try {
      await _llamaController?.dispose();
      _llamaController = null;
      _isModelLoaded = false;
      print('Model unloaded');
    } catch (e) {
      print('Error unloading model: $e');
    }
  }

  // Check if model is available for use
  Future<bool> isModelAvailable() async {
    final modelPath = await _downloadService.getModelPath();
    return modelPath != null;
  }

  void dispose() {
    unloadModel();
  }
}
