import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'utils.dart';
import 'extraction/models.dart';

class LangQTranslate {
  LangQTranslate({required this.apiKey, required this.extractedStrings}) {
    init();
  }

  final String apiKey;
  final List<ExtractedString> extractedStrings;

  init() async {
    final loading = _startLoading();

    stdout.write('Checking translation credits');

    try {
      var response = await http.post(
        Uri.parse(
          "https://ymsreanckxyrthosfqiq.supabase.co/functions/v1/auto-translate",
        ),
        headers: {'Authorization': 'Bearer $apiKey'},
        body: jsonEncode({
          'data': [
            ...extractedStrings.map((e) {
              return {
                // 'key': e.suggestedKey,
                'value': e.value,
                'path': e.filePath,
                'placeholders': e.placeholders,
                'line_column': {'line': e.line, 'column': e.column},
                // 'type': e..toString(),
              };
            }),
          ],
        }),
      );

      if (response.statusCode == 200) {
        var bytes = utf8.decode(response.bodyBytes);
        var data = jsonDecode(bytes);

        print('Response data is $data');

        exit(0);
      } else {
        var data = jsonDecode(response.body);
        await loading.cancel();
        stdout.write('\r');
        stdout.write('\r\x1B[2K');
        stdout.write('${CommandLineColor.red}❌ Error: ${data['error']}\n');
        stdout.write('\r${CommandLineColor.white}');
        exit(0);
      }
    } catch (e) {
      loading.cancel();
      stdout.write('\r');
      stdout.write('\r\x1B[2K');
      stdout.write('${CommandLineColor.red}❌ Error: $e\n');
      stdout.write('\r${CommandLineColor.white}');
      exit(0);
    }
  }

  /// Function to display a loading
  StreamSubscription<void> _startLoading() {
    final List<String> spinner = ['-', '\\', '|', '/'];
    int index = 0;

    return Stream.periodic(Duration(milliseconds: 150), (_) {
      stdout.write(
        '\r⏳ Downloading l10n files ${spinner[index % spinner.length]}',
      );
      index++;
    }).listen((_) {});
  }
}
