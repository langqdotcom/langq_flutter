class CommandLineColor {
  static const green = "\x1B[32m";
  static const white = "\x1b[37m";
  static const red = "\x1b[31m";
}

String toCamelCase(String input) {
  // Return as is if the string is already camelCase (contains no delimiters and starts with lowercase)
  if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(input) &&
      input[0] == input[0].toLowerCase()) {
    return input;
  }

  // Replace all non-alphanumeric characters with spaces
  String formatted = input.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ');

  // Split into words
  List<String> words = formatted.trim().split(RegExp(r'\s+'));

  if (words.isEmpty) return '';

  // Keep the first word lowercase
  String camelCase = words.first.toLowerCase();

  // Capitalize the rest
  for (int i = 1; i < words.length; i++) {
    if (words[i].isNotEmpty) {
      camelCase +=
          words[i][0].toUpperCase() + words[i].substring(1).toLowerCase();
    }
  }

  return camelCase;
}
