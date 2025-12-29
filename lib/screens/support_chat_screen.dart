import 'package:flutter/material.dart';
import 'package:my_app/services/llm_chat_service.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({Key? key}) : super(key: key);

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final LLMChatService _chatService = LLMChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isGenerating = false;
  String _currentResponse = '';

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    
    final available = await _chatService.isModelAvailable();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please download the AI model from settings first'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }
    
    final loaded = await _chatService.loadModel();
    if (!loaded && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load AI model')),
      );
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isGenerating) return;
    
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _messageController.clear();
      _isGenerating = true;
      _currentResponse = '';
    });
    
    _scrollToBottom();
    
    // Add placeholder for assistant message
    setState(() {
      _messages.add({'role': 'assistant', 'content': ''});
    });
    
    try {
      await for (final token in _chatService.generateResponse(text, _messages)) {
        setState(() {
          _currentResponse += token;
          _messages[_messages.length - 1]['content'] = _currentResponse;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error in chat: $e');
    }
    
    setState(() {
      _isGenerating = false;
      _currentResponse = '';
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emotional Support Chat'),
        backgroundColor: const Color(0xFF7550FF),
        actions: [
          if (_chatService.isModelLoaded)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _messages.clear();
                });
              },
              tooltip: 'Clear chat',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_chatService.isModelLoaded
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'AI model not available',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Go to Settings'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isUser = msg['role'] == 'user';
                          
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? const Color(0xFF7550FF)
                                    : const Color(0xFF363A4D),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                msg['content'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Input area
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF363A4D),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Share how you\'re feeling...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF2A2D3A),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              enabled: !_isGenerating,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: const Color(0xFF7550FF),
                            child: IconButton(
                              icon: _isGenerating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send, color: Colors.white),
                              onPressed: _isGenerating ? null : _sendMessage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatService.dispose();
    super.dispose();
  }
}
