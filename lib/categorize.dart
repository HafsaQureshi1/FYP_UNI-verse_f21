import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> _classifyPostWithDeepSeek(String postText) async {
  final url = Uri.parse("https://api.deepseek.com/v1/classify"); // Replace with actual API endpoint
  final headers = {
    "Authorization": "Bearer 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",  // Replace with actual API key
    "Content-Type": "application/json"
  };

  final body = jsonEncode({
    "input": postText,
    "labels": ["Clothes", "Documents", "Electronics", "Books", "Miscellaneous"]
  });

  try {
    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['category'] ?? "Miscellaneous";  // Default to 'Miscellaneous'
    } else {
      return "Miscellaneous"; // Fallback category in case of API failure
    }
  } catch (e) {
    print("DeepSeek API Error: $e");
    return "Miscellaneous"; // Fallback category
  }
}
