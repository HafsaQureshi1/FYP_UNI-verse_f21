import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';

class DialogflowService {
  late AutoRefreshingAuthClient _client;
  final _scopes = ['https://www.googleapis.com/auth/cloud-platform'];
  final _projectId = 'chatbot-abif'; // Replace with your Dialogflow project ID

  Future<void> init() async {
    final serviceAccount = await rootBundle.loadString('assets/chatbot-abif-e9e7a3b6c2e9.json');
    final credentials = ServiceAccountCredentials.fromJson(serviceAccount);
    _client = await clientViaServiceAccount(credentials, _scopes);
  }

  bool _isDialogflowDefaultResponse(String response) {
    final defaultPhrases = [
      "what was that",
      "i didn't get that",
      "i missed what you said",
      "sorry, i didn't understand",
      "sorry what was that",
      "sorry can you say that again",
      "say that one more time",
      "can you rephrase",
      "i’m not sure",
      "i think you’re asking",
      "try asking about"
    ];

    final lowerResponse = response.toLowerCase();
    return defaultPhrases.any((phrase) => lowerResponse.contains(phrase));
  }

  Future<String> detectIntent(String query) async {
    try {
      final dialogflowResponse = await _detectDialogflowIntent(query);

      if (dialogflowResponse != null && !_isDialogflowDefaultResponse(dialogflowResponse)) {
        return dialogflowResponse;
      } else {
        return "I'm sorry, I didn't understand that. Could you rephrase?";
      }
    } catch (e) {
      print("Dialogflow error: $e");
      return "Oops! Something went wrong.";
    }
  }

  Future<String?> _detectDialogflowIntent(String query) async {
    final response = await _client.post(
      Uri.parse('https://dialogflow.googleapis.com/v2/projects/$_projectId/agent/sessions/123456789:detectIntent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "queryInput": {
          "text": {
            "text": query,
            "languageCode": "en-US"
          }
        }
      }),
    );

    final data = jsonDecode(response.body);
    final textResponse = data['queryResult']?['fulfillmentText'];
    return textResponse;
  }
}
