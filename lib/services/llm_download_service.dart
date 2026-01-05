import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

class LLMDownloadService {
  static const String MODEL_URL = 
      'https://huggingface.co/lmstudio-community/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q4_K_M.gguf';
  static const String MODEL_FILENAME = 'smollm2-1.7b-instruct-q4.gguf';

  final Dio _dio = Dio();

  // Stream to track download progress (0.0 to 1.0)
  Stream<double> get downloadProgress => _progressController.stream;
  final _progressController = StreamController<double>.broadcast();

  // Check if model is already downloaded
  Future<bool> isModelDownloaded() async {
    try {
      final file = await _getModelFile();
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  // Get model file path
  Future<File> _getModelFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$MODEL_FILENAME');
  }

  // Get model file path as string (for passing to inference engine)
  Future<String?> getModelPath() async {
    final file = await _getModelFile();
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  // Download the model
  Future<bool> downloadModel() async {
    try {
      final file = await _getModelFile();

      // Check if already exists
      if (await file.exists()) {
        _progressController.add(1.0);
        return true;
      }

      

      await _dio.download(
        MODEL_URL,
        file.path,
        onReceiveProgress: (received, total) {
            if (total != -1) {
            final progress = received / total;
            _progressController.add(progress);
          }
        },
        options: Options(
          receiveTimeout: const Duration(hours: 1),
          sendTimeout: const Duration(hours: 1),
        ),
      );

      
      return true;

    } catch (e) {
      _progressController.addError(e);
      return false;
    }
  }

  // Delete the model to free up space
  Future<bool> deleteModel() async {
    try {
      final file = await _getModelFile();
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get model size in MB
  Future<double?> getModelSize() async {
    try {
      final file = await _getModelFile();
      if (await file.exists()) {
        final bytes = await file.length();
        return bytes / (1024 * 1024); // Convert to MB
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _progressController.close();
  }
}
