import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyResponseScreen extends StatefulWidget {
  final String surveyId;
  final String collectionPath;

  const SurveyResponseScreen({
    Key? key,
    required this.surveyId,
    required this.collectionPath,
  }) : super(key: key);

  @override
  _SurveyResponseScreenState createState() => _SurveyResponseScreenState();
}

class _SurveyResponseScreenState extends State<SurveyResponseScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _surveyData;
  final Map<String, dynamic> _responses = {};

  @override
  void initState() {
    super.initState();
    _fetchSurveyData();
  }

  Future<void> _fetchSurveyData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.surveyId)
          .get();

      if (doc.exists) {
        setState(() {
          _surveyData = doc.data();
          _isLoading = false;
        });
      } else {
        throw Exception('Survey not found');
      }
    } catch (e) {
      print('Error fetching survey: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading survey: ${e.toString()}')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _submitResponses() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to submit a response')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // First check if there are any unanswered required questions
      List<dynamic> questions = _surveyData?['questions'] ?? [];
      for (int i = 0; i < questions.length; i++) {
        final questionId = questions[i]['id'];
        final isRequired = questions[i]['isRequired'] ?? false;

        if (isRequired && !_responses.containsKey(questionId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please answer all required questions')),
          );
          setState(() {
            _isSubmitting = false;
          });
          return;
        }
      }

      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final username = userDoc.data()?['username'] ?? 'Anonymous';

      // Prepare the response data
      final responseData = {
        'userId': userId,
        'username': username,
        'responses': _responses,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Submit response
      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.surveyId)
          .collection('responses')
          .add(responseData);

      // Update the response count
      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.surveyId)
          .update({
        'responses': FieldValue.increment(1),
      });

      // Add notification for survey creator
      final authorId = _surveyData?['userId'];
      if (authorId != null && authorId != userId) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': authorId,
          'senderId': userId,
          'senderName': username,
          'postId': widget.surveyId,
          'collection': widget.collectionPath,
          'message': "$username responded to your survey",
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'survey_response',
          'isRead': false,
        });
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your responses!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      print('Error submitting responses: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitSurveyResponses() async {
    // ...existing validation code...

    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      // Prepare the answers data
      Map<String, dynamic> answers = {};

      for (var question in _surveyData?['questions'] ?? []) {
        final String questionId = question['id'];

        if (_responses.containsKey(questionId)) {
          answers[questionId] = _responses[questionId];
        }
      }

      // Create response document
      final responseData = {
        'userId': userId,
        'answers': answers,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add to responses subcollection
      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.surveyId)
          .collection('responses')
          .add(responseData);

      // Update response count in the parent document
      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.surveyId)
          .update({
        'responses': FieldValue.increment(1),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey submitted successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting survey: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Survey'),
          backgroundColor: const Color.fromARGB(255, 0, 58, 92),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String title = _surveyData?['title'] ?? 'Survey';
    final String description = _surveyData?['description'] ?? '';
    final List<dynamic> questions = _surveyData?['questions'] ?? [];
    final String? imageUrl = _surveyData?['imageUrl'];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Survey Title and Description
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],

                  // Survey Image
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Questions
                  for (int i = 0; i < questions.length; i++)
                    _buildQuestion(questions[i], i),

                  const SizedBox(height: 60), // Space for button
                ],
              ),
            ),
          ),

          // Submit Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 0, 58, 92),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isSubmitting ? null : _submitResponses,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(Map<String, dynamic> questionData, int index) {
    final String id = questionData['id'];
    final String question = questionData['question'];
    final String type = questionData['type'];
    final List<dynamic> options = questionData['options'] ?? [];
    final bool isRequired = questionData['isRequired'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 0, 58, 92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isRequired)
                      const Text(
                        '* Required',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Multiple Choice Options
          if (type == 'multipleChoice')
            Column(
              children: [
                for (int i = 0; i < options.length; i++)
                  RadioListTile<String>(
                    title: Text(options[i]),
                    value: options[i],
                    groupValue: _responses[id],
                    onChanged: (value) {
                      setState(() {
                        _responses[id] = value;
                      });
                    },
                    activeColor: const Color.fromARGB(255, 0, 58, 92),
                  ),
              ],
            ),

          // Short Answer
          if (type == 'shortAnswer')
            TextField(
              decoration: InputDecoration(
                hintText: 'Your answer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color.fromARGB(255, 0, 58, 92),
                    width: 2,
                  ),
                ),
              ),
              maxLines: 3,
              onChanged: (value) {
                _responses[id] = value;
              },
            ),
        ],
      ),
    );
  }
}
