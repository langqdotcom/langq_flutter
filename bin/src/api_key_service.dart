import 'dart:io';

import 'package:dotenv/dotenv.dart';

class ApiKeyService {
  // Helper methods (reuse from other commands)
  static String getApiKey() {
    // Try environment variable
    String? apiKey = Platform.environment['LANGQ_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      return apiKey;
    }

    if (apiKey == null) {
      var dotenv = DotEnv();
      dotenv.load();

      apiKey = dotenv['LANGQ_API_KEY'];

      if (apiKey != null && apiKey.isNotEmpty) {
        return apiKey;
      }
    }

    throw Exception(
      'API key not found. Set it in langq.yaml or LANGQ_API_KEY environment variable',
    );
  }
}
