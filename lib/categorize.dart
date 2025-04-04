import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> _classifyPostWithDeepSeek(String postText) async {
  final url = Uri.parse("https://api.deepseek.com/v1/chat/completions"); // Replace with actual API endpoint
  final headers = {
    "Authorization": "Bearer sk-874cd61b34ba477ab266c3132a3da13c",  // Replace with actual API key
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
