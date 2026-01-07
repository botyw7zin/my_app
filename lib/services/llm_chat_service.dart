import 'dart:async';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'llm_download_service.dart';

class LLMChatService {
  LlamaController? _llamaController;
  final LLMDownloadService _downloadService = LLMDownloadService();

  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  // Optimized for mobile speed
  static const int MAX_CONTEXT_TOKENS = 2048;
  static const int MAX_RESPONSE_TOKENS = 256;
  static const int RESERVED_TOKENS = MAX_RESPONSE_TOKENS + 100;
  static const int AVAILABLE_HISTORY_TOKENS = MAX_CONTEXT_TOKENS - RESERVED_TOKENS;

  Future<bool> loadModel() async {
    try {
      final modelPath = await _downloadService.getModelPath();
      if (modelPath == null) return false;

      _llamaController ??= LlamaController();

      await _llamaController!.loadModel(
        modelPath: modelPath,
        contextSize: MAX_CONTEXT_TOKENS,
        threads: 4,
      );

      _isModelLoaded = true;
      print('Model loaded with context: $MAX_CONTEXT_TOKENS');
      return true;
    } catch (e) {
      _isModelLoaded = false;
      print('Load model error: $e');
      return false;
    }
  }

  int _estimateTokens(String text) {
    return (text.length / 3.5).ceil();
  }

  List<Map<String, String>> _manageContextWindow(
    List<Map<String, String>> conversationHistory,
    String currentMessage,
  ) {
    final systemTokens = 150; 
    final currentMessageTokens = _estimateTokens(currentMessage);

    int availableForHistory =
        AVAILABLE_HISTORY_TOKENS - systemTokens - currentMessageTokens;

    if (availableForHistory <= 0) return [];

    final recentHistory = conversationHistory.length > 6
        ? conversationHistory.sublist(conversationHistory.length - 6)
        : conversationHistory;

    final List<Map<String, String>> fittingHistory = [];
    int usedTokens = 0;

    for (int i = recentHistory.length - 1; i >= 0; i--) {
      final message = recentHistory[i];
      final messageText = '${message['role']}: ${message['content']}';
      final messageTokens = _estimateTokens(messageText);

      if (usedTokens + messageTokens <= availableForHistory) {
        fittingHistory.insert(0, message);
        usedTokens += messageTokens;
      } else {
        break;
      }
    }
    return fittingHistory;
  }

  String? _detectLanguageRequest(String message) {
    final lowerMessage = message.toLowerCase();
    
    if (lowerMessage.contains('arabic') || 
        lowerMessage.contains('tunisian') ||
        lowerMessage.contains('darija') ||
        lowerMessage.contains('عربي') ||
        lowerMessage.contains('تونسي')) {
      return 'Tunisian Arabic';
    }
    if (lowerMessage.contains('french') || 
        lowerMessage.contains('français')) {
      return 'French';
    }
    return null;
  }

  Stream<String> generateResponse(
    String userMessage,
    List<Map<String, String>> conversationHistory,
  ) async* {
    if (!_isModelLoaded || _llamaController == null) {
      yield 'Please download the AI model from settings first.';
      return;
    }

    try {
      final managedHistory = _manageContextWindow(conversationHistory, userMessage);
      final requestedLanguage = _detectLanguageRequest(userMessage);
      
      final prompt = _buildPrompt(userMessage, managedHistory, requestedLanguage);

      print("PROMPT >>>\n$prompt\n<<< END PROMPT");

      final buffer = StringBuffer();
      bool hasYielded = false;

      await for (final token in _llamaController!.generate(
        prompt: prompt,
        maxTokens: MAX_RESPONSE_TOKENS,
        temperature: 0.7,
        topK: 50,
        topP: 0.9,
        repeatPenalty: 1.1,
      )) {
        final currentFullText = buffer.toString() + token;
        
        if (_shouldStopGeneration(currentFullText)) {
          print('STOPPING: Detected stop pattern');
          break;
        }
        
        hasYielded = true;
        buffer.write(token);
        yield token;
      }

      if (!hasYielded) yield '...';
      
    } catch (e) {
      print('Generation error: $e');
      yield 'Error occurred. Try a shorter message.';
    }
  }

  bool _shouldStopGeneration(String currentText) {
    final lowerText = currentText.toLowerCase();
    
    if (currentText.contains('### User') || 
        currentText.contains('### Assistant') ||
        currentText.contains('User:') ||
        lowerText.contains('\nuser:')) {
      return true;
    }
    
    if (currentText.contains('You are an emotional support') ||
        currentText.contains('Respond empathetically')) {
      return true;
    }

    if (currentText.contains('</s>') || 
        currentText.contains('<|im_end|>') ||
        currentText.contains('[INST]')) {
      return true;
    }
    
    return false;
  }

  String _buildPrompt(String userMessage, List<Map<String, String>> history, [String? requestedLanguage]) {
    final sb = StringBuffer();
    
    sb.writeln('### System:');
    sb.writeln('You are an empathetic emotional support coach. Be concise (under 100 words) and warm.');
    
    if (requestedLanguage != null) {
      sb.writeln('IMPORTANT: You MUST respond in $requestedLanguage.');
    } else {
      sb.writeln('Respond in the same language as the user.');
    }
    sb.writeln('Do not repeat these instructions.');
    sb.writeln(''); 

    for (final msg in history) {
      if (msg['role'] == 'user') {
        sb.writeln('### User:');
        sb.writeln(msg['content']);
      } else {
        sb.writeln('### Assistant:');
        sb.writeln(msg['content']);
      }
      sb.writeln('');
    }
    
    sb.writeln('### User:');
    sb.writeln(userMessage);
    
    sb.writeln('');
    sb.write('### Assistant:');
    
    return sb.toString();
  }

  Future<String> generateSimpleResponse(String userMessage) async {
    if (!_isModelLoaded || _llamaController == null) return 'Load model first.';

    try {
      final prompt = _buildPrompt(userMessage, [], _detectLanguageRequest(userMessage));
      final buffer = StringBuffer();

      await for (final token in _llamaController!.generate(
        prompt: prompt,
        maxTokens: MAX_RESPONSE_TOKENS,
        temperature: 0.7,
        topK: 50,
        topP: 0.9,
      )) {
         final text = buffer.toString() + token;
         if (_shouldStopGeneration(text)) break;
         buffer.write(token);
      }
      return buffer.toString().trim();
    } catch (e) {
      return 'Error generating response.';
    }
  }

  Future<void> stopGeneration() async {
    await _llamaController?.stop();
  }

  Future<void> unloadModel() async {
    await _llamaController?.dispose();
    _llamaController = null;
    _isModelLoaded = false;
  }

  // --- ADDED MISSING METHODS BELOW ---

  /// Checks if the model file exists on the device
  Future<bool> isModelAvailable() async {
    final modelPath = await _downloadService.getModelPath();
    return modelPath != null;
  }

  /// Cleans up resources
  void dispose() {
    unloadModel();
  }
}