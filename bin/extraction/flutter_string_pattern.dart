import 'string_pattern.dart';
import 'context_type.dart';
// lib/src/extraction/flutter_string_patterns.dart

class FlutterStringPatterns {
  static List<StringPattern> get all => [
    ...uiPatterns,
    // ...dialogPatterns,
    // ...navigationPatterns,
    // ...genericPatterns,
  ];

  static List<StringPattern> get uiPatterns => [];
}

// Extension to add test cases for patterns
extension StringPatternTesting on StringPattern {
  /// Test this pattern against sample code
  List<String> testAgainstSamples() {
    final samples = _getSampleStringsForContext(contextType);
    final matches = <String>[];

    for (final sample in samples) {
      final match = regex.firstMatch(sample);
      if (match != null && match.groupCount >= 1) {
        final extracted = match.group(1);
        if (extracted != null) {
          matches.add(extracted);
        }
      }
    }

    return matches;
  }

  List<String> _getSampleStringsForContext(ContextType context) {
    switch (context) {
      case ContextType.uiText:
        return [
          'Text("Hello World")',
          "Text('Welcome User')",
          'Text("This is a longer message")',
        ];
      case ContextType.appBarTitle:
        return ['title: Text("Home Page")', 'title: Text("Settings")'];
      case ContextType.buttonText:
        return [
          'child: Text("Submit")',
          'child: Text("Cancel")',
          'child: Text("Save Changes")',
        ];
      case ContextType.inputText:
        return [
          'labelText: "Enter your name"',
          'hintText: "Type here..."',
          'helperText: "This field is required"',
        ];
      case ContextType.interpolatedString:
        return [
          '"Hello \${userName}"',
          '"You have \$count messages"',
          "'Welcome back, \$name!'",
        ];
      default:
        return ['"Sample text"', "'Another sample'"];
    }
  }
}
