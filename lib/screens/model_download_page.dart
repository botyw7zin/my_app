import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import '../services/llm_download_service.dart';
import '../widgets/background.dart'; 

class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({Key? key}) : super(key: key);

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  final LLMDownloadService _downloadService = LLMDownloadService();
  bool _isDownloading = false;
  bool _isDownloaded = false;
  double _downloadProgress = 0.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
    _downloadService.downloadProgress.listen((progress) {
      if (mounted) {
        setState(() {
          _downloadProgress = progress;
          if (progress >= 1.0) {
            _isDownloading = false;
            _isDownloaded = true;
          }
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isDownloading = false;
        });
      }
    });
  }

  Future<void> _checkModelStatus() async {
    try {
      final downloaded = await _downloadService.isModelDownloaded();
      if (mounted) {
        setState(() {
          _isDownloaded = downloaded;
        });
      }
    } catch (e) {
      debugPrint('Error checking status: $e');
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _error = null;
      _downloadProgress = 0.0;
    });

    try {
      final success = await _downloadService.downloadModel();

      if (mounted) {
        if (success) {
          setState(() {
            _isDownloaded = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI Model downloaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _error = 'Download failed. Please check your connection.';
            _isDownloading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred: $e';
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _deleteModel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF363A4D),
        title: const Text('Delete Model', style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to delete the AI model? You will need to download it again to use the chat feature.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _downloadService.deleteModel();
      if (success && mounted) {
        setState(() {
          _isDownloaded = false;
          _downloadProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model deleted')),
        );
      }
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF15171E),
      appBar: AppBar(
        title: const Text(
          'AI Model Settings',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Stack(
        // 1. FIX: Add this line to force the stack to fill the screen
        fit: StackFit.expand, 
        children: [
          // 2. Background Layer
          const Positioned.fill(
            child: GlowyBackground(),
          ),

          // 3. Content Layer
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info Card
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF363A4D).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            ' Emotional Support Model ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: const [
                              Icon(Icons.sd_storage_outlined,
                                  size: 16, color: Colors.grey),
                              SizedBox(width: 6),
                              Text(
                                'Size: ~1 GB',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'This AI model runs entirely on your device to provide private, offline emotional support. No data leaves your phone.',
                            style: TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Error Message
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Download/Status Section
                  if (_isDownloading)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF363A4D).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _downloadProgress,
                              minHeight: 10,
                              backgroundColor: Colors.white10,
                              color: const Color(0xFF7550FF),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Please keep the app open',
                            style: TextStyle(
                                fontSize: 12, color: Colors.white38),
                          ),
                        ],
                      ),
                    )
                  else if (_isDownloaded)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.check_circle,
                                  color: Colors.greenAccent),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Model ready for use',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.greenAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: _deleteModel,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete Model'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _startDownload,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download AI Model'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7550FF), // Main purple
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFF7550FF).withOpacity(0.4),
                      ),
                    ),

                  const SizedBox(height: 32),

                  const Text(
                    'Note: WiFi recommended. The download is ~1 GB.\nKeep this screen open until completion.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white38,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _downloadService.dispose();
    super.dispose();
  }
}