import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/llm_chat_service.dak';
import '../widgets/background.dart';
import 'model_download_page.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({Key? key}) : super(key: key);

  @override
  State<SupportChatScreen> createState() => SupportChatScreenState();
}

class SupportChatScreenState extends State<SupportChatScreen> {
  final LLMChatService chatService = LLMChatService();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final List<Map<String, String>> messages = [];
  final List<Map<String, String>> llmHistory = [];
  bool isLoading = false;
  bool isGenerating = false;
  bool shouldStopGeneration = false;
  String currentResponse = '';

  @override
  void initState() {
    super.initState();
    initializeChat();
  }

  Future<void> initializeChat() async {
    setState(() => isLoading = true);
    final available = await chatService.isModelAvailable();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please download the AI model first'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      setState(() => isLoading = false);
      return;
    }

    final loaded = await chatService.loadModel();
    if (!loaded && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load AI model')),
      );
    }
    setState(() => isLoading = false);
  }

  void stopGeneration() {
    setState(() {
      shouldStopGeneration = true;
    });
  }

  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Message copied to clipboard'),
            ],
          ),
          backgroundColor: const Color(0xFF7550FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || isGenerating) return;

    setState(() {
      messages.add({'role': 'user', 'content': text});
      messageController.clear();
      isGenerating = true;
      shouldStopGeneration = false;
      currentResponse = '';
    });

    scrollToBottom();

    while (llmHistory.length > 8) {
      llmHistory.removeAt(0);
    }

    llmHistory.add({'role': 'user', 'content': text});

    try {
      // Add assistant placeholder FIRST
      setState(() {
        messages.add({'role': 'assistant', 'content': ''});
      });

      await for (final token in chatService.generateResponse(text, llmHistory)) {
        if (!mounted || shouldStopGeneration) {
          // Stop generation if flag is set
          if (shouldStopGeneration) {
            debugPrint('Generation stopped by user');
          }
          break;
        }

        var cleanedToken = token
            .replaceAll(RegExp(r'\[MODE:?.*?\]'), '')
            .replaceAll(RegExp(r'System:?\s*'), '')
            .replaceAll(RegExp(r'<\|?end?\|?>'), '');

        if (cleanedToken.isNotEmpty) {
          setState(() {
            currentResponse += cleanedToken;
            messages[messages.length - 1]['content'] = currentResponse;
          });
          scrollToBottom();
        }
      }

      final finalResponse = _normalizeSpacing(currentResponse);
      setState(() {
        messages[messages.length - 1]['content'] = finalResponse;
      });

      if (finalResponse.isNotEmpty) {
        llmHistory.add({'role': 'assistant', 'content': finalResponse});
      } else if (shouldStopGeneration && messages.isNotEmpty && messages.last['role'] == 'assistant') {
        // Remove empty assistant message if generation was stopped immediately
        if (messages.last['content']?.isEmpty ?? true) {
          messages.removeLast();
        }
      }
    } catch (e) {
      debugPrint('Generation error: $e');
      setState(() {
        if (messages.isNotEmpty && messages.last['role'] == 'assistant') {
          messages.last['content'] = 'Sorry, something went wrong. Tap refresh to try again.';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          isGenerating = false;
          shouldStopGeneration = false;
        });
      }
    }
  }

  String _normalizeSpacing(String text) {
    if (text.isEmpty) return '';

    // STRATEGY 1: Remove ALL dollar artifacts FIRST (bulletproof)
    String cleaned = text
        .replaceAll('\$\$', '') // Remove literal $$
        .replaceAll(r'$1', '') // Remove $1
        .replaceAll(r'$2', '') // Remove $2
        .replaceAll(r'$3', '') // Remove $3
        .replaceAll(RegExp(r'\$\d'), ''); // Remove any $number

    // STRATEGY 2: Simple space normalization (NO complex regex)
    cleaned = cleaned
        .replaceAll(RegExp(r' +'), ' ') // Multiple spaces → single space
        .replaceAll(RegExp(r'\n+'), ' ') // Multiple newlines → space
        .trim(); // Remove leading/trailing spaces

    return cleaned;
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void clearChat() {
    setState(() {
      messages.clear();
      llmHistory.clear();
      currentResponse = '';
      isGenerating = false;
      shouldStopGeneration = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF15171E),
      body: Stack(
        children: [
          const Positioned.fill(child: GlowyBackground()),
          // Content area with messages
          SafeArea(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7550FF)))
                : !chatService.isModelLoaded
                    ? _buildModelNotLoaded()
                    : Column(
                        children: [
                          // Spacer for AppBar
                          const SizedBox(height: 56), // Standard AppBar height
                          // Messages
                          Expanded(
                            child: messages.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                      top: 16,
                                      bottom: 100, // Space for input area
                                    ),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final msg = messages[index];
                                      final isUser = msg['role'] == 'user';
                                      return _buildMessageBubble(msg, isUser);
                                    },
                                  ),
                          ),
                          _buildInputArea(),
                        ],
                      ),
          ),
          // AppBar on top (positioned last so it's on top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7550FF).withOpacity(0.3),
                    blurRadius: 25,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: AppBar(
                title: const Text(
                  'Emotional Support Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(color: Colors.black.withOpacity(0.3)),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7550FF), Color(0xFF5A3FFF)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: clearChat,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelNotLoaded() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF363A4D).withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off, size: 80, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text(
            'AI Model Not Downloaded',
            style: TextStyle(fontSize: 22, color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModelDownloadScreen()),
              ),
              icon: const Icon(Icons.download),
              label: const Text('Download Model'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7550FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF7550FF).withOpacity(0.1),
                Colors.transparent,
              ]),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent, size: 90, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ready to help!',
            style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Share how you\'re feeling...',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> msg, bool isUser) {
    final content = msg['content'] ?? '';
    return GestureDetector(
      onLongPress: () {
        if (content.isNotEmpty) {
          copyToClipboard(content);
        }
      },
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isUser ? 60 : 0,
          right: isUser ? 0 : 60,
        ),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[ 
              CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFF363A4D),
                child: Icon(Icons.support_agent, size: 22, color: Colors.white70),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Container(
                padding: EdgeInsets.fromLTRB(isUser ? 20 : 16, 16, isUser ? 16 : 20, 16),
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isUser
                        ? const [Color(0xFF7550FF), Color(0xFF5A3FFF)]
                        : const [Color(0xFF363A4D), Color(0xFF2A2D3A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isUser ? 22 : 26),
                    topRight: Radius.circular(isUser ? 26 : 22),
                    bottomLeft: const Radius.circular(26),
                    bottomRight: const Radius.circular(26),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isUser ? const Color(0xFF7550FF) : const Color(0xFF363A4D))
                          .withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  content,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    height: 1.45,
                    fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (isUser) ...[ 
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFF7550FF).withOpacity(0.3),
                child: Icon(Icons.person, size: 22, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7550FF).withOpacity(0.25),
            blurRadius: 25,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF7550FF).withOpacity(0.4),
                width: 1.8,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => sendMessage(),
                    enabled: !isGenerating,
                    style: const TextStyle(color: Colors.white, fontSize: 16.5),
                    decoration: InputDecoration(
                      hintText: 'Share how you\'re feeling...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isGenerating
                          ? const [Color(0xFFFF5555), Color(0xFFFF3333)] // Red gradient for stop
                          : const [Color(0xFF7550FF), Color(0xFF5A3FFF)], // Purple gradient for send
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: isGenerating
                      ? IconButton(
                          icon: const Icon(Icons.stop, color: Colors.white),
                          onPressed: stopGeneration,
                          tooltip: 'Stop generation',
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: sendMessage,
                          tooltip: 'Send message',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    chatService.dispose();
    super.dispose();
  }
}