import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DeepSeekChatScreen extends StatefulWidget {
  @override
  _DeepSeekChatScreenState createState() => _DeepSeekChatScreenState();
}

class _DeepSeekChatScreenState extends State<DeepSeekChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  // Your OpenRouter API key and endpoint
  final String apiUrl = "https://openrouter.ai/api/v1/chat/completions";
  final String apiKey = "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";

  // Function to send request to DeepSeek-R1 API and get the response
  Future<String> _getDeepSeekResponse(String query) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',  // Your OpenRouter API key
        'HTTP-Referer': 'https://yourapp.com',  // Optional, for site ranking purposes
        'X-Title': 'UNI-verse Assistant',       // Optional, for site ranking purposes
      },
      body: jsonEncode({
        "model": "deepseek/deepseek-r1:free",  // Specify the DeepSeek-R1 model
        "messages": [
          {"role": "system", "content": "You are a helpful assistant for university students."},
          {"role": "user", "content": query}
        ],
      
      }),
    );

    // Handling the response
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final textResponse = data['choices'][0]['message']['content'] ?? "Sorry, I couldn't get a response.";
      return textResponse;
    } else {
      print("Error: ${response.body}");
      return "Sorry, I'm having trouble right now. Please try again later.";
    }
  }

  // Function to handle sending the message and updating the UI
  void _sendMessage() async {
    String input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _messages.add({'text': input, 'isUser': true});
    });

    _controller.clear();

    // Get the response from DeepSeek-R1 API
    String response = await _getDeepSeekResponse(input);

    setState(() {
      _messages.add({'text': response, 'isUser': false});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("DeepSeek Assistant 🤖")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg['isUser'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.all(8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg['isUser'] ? Colors.blue : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg['text'],
                      style: TextStyle(
                        color: msg['isUser'] ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration.collapsed(hintText: "Talk to DeepSeek..."),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
