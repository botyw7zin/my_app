import 'dart:async';

class LLMChatService {
  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  Future<bool> loadModel() async {
    await Future.delayed(const Duration(seconds: 2));
    _isModelLoaded = true;
    return true;
  }

  Stream<String> generateResponse(String userMessage, List<Map<String, String>> conversationHistory) async* {
    final responses = {
      'stress': 'I understand exam stress can be overwhelming. Remember to take deep breaths and break your study into manageable chunks. You\'ve got this! 💪',
      'exam': 'You\'ve prepared for this! Trust in your abilities and try to get good rest tonight. Remember, one exam doesn\'t define you. 🌟',
      'tired': 'It\'s okay to feel tired. Make sure you\'re taking breaks and getting enough sleep. Your wellbeing matters more than perfect grades. 🛌',
      'anxious': 'Anxiety before exams is completely normal. Try some breathing exercises: breathe in for 4 counts, hold for 4, out for 4. You\'re stronger than you think! 🧘',
      'help': 'I\'m here for you. What specific challenge are you facing? Whether it\'s time management, understanding material, or just needing encouragement, let\'s work through it together. 💙',
    };

    String response = 'I hear you. Remember, it\'s okay to feel this way. What specifically would help you right now? I\'m here to support you through your studies. 🌈';
    
    final lowerMessage = userMessage.toLowerCase();
    for (final key in responses.keys) {
      if (lowerMessage.contains(key)) {
        response = responses[key]!;
        break;
      }
    }

    for (final word in response.split(' ')) {
      await Future.delayed(const Duration(milliseconds: 80));
      yield '$word ';
    }
  }

  Future<String> generateSimpleResponse(String userMessage) async {
    final buffer = StringBuffer();
    await for (final token in generateResponse(userMessage, [])) {
      buffer.write(token);
    }
    return buffer.toString().trim();
  }

  Future<void> stopGeneration() async {}
  
  Future<void> unloadModel() async {
    _isModelLoaded = false;
  }

  Future<bool> isModelAvailable() async => true;

  void dispose() {}
}
