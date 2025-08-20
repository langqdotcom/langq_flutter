// lib/src/utils/package_info.dart
import 'dart:io';
import 'package:yaml/yaml.dart';

class PackageInfo {
  static String? _cachedPackageName;

  static Future<String> getPackageName([String? projectPath]) async {
    if (_cachedPackageName != null) {
      return _cachedPackageName!;
    }

    projectPath ??= Directory.current.path;
    final pubspecFile = File('$projectPath/pubspec.yaml');

    if (!await pubspecFile.exists()) {
      throw Exception('pubspec.yaml not found in $projectPath');
    }

    try {
      final content = await pubspecFile.readAsString();
      final yaml = loadYaml(content) as Map;

      final packageName = yaml['name'] as String?;
      if (packageName == null || packageName.isEmpty) {
        throw Exception('Package name not found in pubspec.yaml');
      }

      _cachedPackageName = packageName;
      return packageName;
    } catch (e) {
      throw Exception('Error reading package name from pubspec.yaml: $e');
    }
  }

  static void clearCache() {
    _cachedPackageName = null;
  }
}
