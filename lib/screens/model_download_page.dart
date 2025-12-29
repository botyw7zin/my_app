// lib/screens/model_download_page.dart

import 'package:flutter/material.dart';
import '../services/llm_download_service.dart';

class ModelDownloadPage extends StatefulWidget {
  const ModelDownloadPage({Key? key}) : super(key: key);

  @override
  State<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends State<ModelDownloadPage> {
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
      setState(() {
        _downloadProgress = progress;
        if (progress >= 1.0) {
          _isDownloading = false;
          _isDownloaded = true;
        }
      });
    }, onError: (error) {
      setState(() {
        _error = error.toString();
        _isDownloading = false;
      });
    });
  }

  Future<void> _checkModelStatus() async {
    final downloaded = await _downloadService.isModelDownloaded();
    setState(() {
      _isDownloaded = downloaded;
    });
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _error = null;
      _downloadProgress = 0.0;
    });

    final success = await _downloadService.downloadModel();

    if (success) {
      setState(() {
        _isDownloaded = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Model downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() {
        _error = 'Download failed. Please check your connection.';
      });
    }
  }

  Future<void> _deleteModel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: const Text('Are you sure you want to delete the AI model? You will need to download it again to use the chat feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _downloadService.deleteModel();
      if (success) {
        setState(() {
          _isDownloaded = false;
          _downloadProgress = 0.0;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model deleted')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Model Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SmolLM2 Emotional Support Model',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Size: ~1 GB',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This AI model helps provide guidance, reassurance, and emotional support for students.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            if (_error != null) const SizedBox(height: 16),

            if (_isDownloading)
              Column(
                children: [
                  LinearProgressIndicator(value: _downloadProgress),
                  const SizedBox(height: 8),
                  Text(
                    'Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              )
            else if (_isDownloaded)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Model downloaded and ready to use',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _deleteModel,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Model'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download),
                label: const Text('Download AI Model'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),

            const SizedBox(height: 16),

            const Text(
              'Note: Make sure you are connected to WiFi. The download is approximately 1 GB and may take several minutes.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _downloadService.dispose();
    super.dispose();
  }
}
