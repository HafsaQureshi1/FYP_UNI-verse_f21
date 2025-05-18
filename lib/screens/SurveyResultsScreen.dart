import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyResultsScreen extends StatefulWidget {
  final String surveyId;
  final String collectionPath;

  const SurveyResultsScreen({
    Key? key,
    required this.surveyId,
    required this.collectionPath,
  }) : super(key: key);

  @override
  State<SurveyResultsScreen> createState() => _SurveyResultsScreenState();
}

class _SurveyResultsScreenState extends State<SurveyResultsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _surveyData;
  List<Map<String, dynamic>> _responses = [];
  int _totalResponses = 0;

  @override
  void initState() {
    super.initState();
    _fetchSurveyResults();
  }

  Future<void> _fetchSurveyResults() async {
    try {
      // Fetch survey data
      final doc = await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.surveyId)
          .get();

      if (!doc.exists) throw Exception('Survey not found');
      final surveyData = doc.data();

      // Fetch responses
      final responsesSnapshot = await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.surveyId)
          .collection('responses')
          .get();

      final responses = responsesSnapshot.docs
          .map((d) => d.data())
          .toList()
          .cast<Map<String, dynamic>>();

      setState(() {
        _surveyData = surveyData;
        _responses = responses;
        _totalResponses = responses.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching survey results: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading results: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Widget _buildResults() {
    if (_surveyData == null) return const SizedBox();

    final questions = _surveyData?['questions'] ?? [];
    final title = _surveyData?['title'] ?? 'Survey Results';
    final description = _surveyData?['description'] ?? '';

    // Show "No responses yet" if there are no responses
    if (_totalResponses == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No responses yet",
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description ?? '',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.people, color: Color.fromARGB(255, 0, 58, 92)),
            const SizedBox(width: 6),
            Text(
              '$_totalResponses ${_totalResponses == 1 ? "Response" : "Responses"}',
              style: TextStyle(
                color: Color.fromARGB(255, 0, 58, 92),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...List.generate(questions.length, (i) {
          final q = questions[i];
          return _buildQuestionResult(q, i);
        }),
      ],
    );
  }

  Widget _buildQuestionResult(Map<String, dynamic> question, int index) {
    final String id = question['id'];
    final String text = question['question'];
    final String type = question['type'];
    final List options = question['options'] ?? [];
    final bool isRequired = question['isRequired'] ?? false;

    // Count answers for this question
    Map<String, int> optionCounts = {};
    int answeredCount = 0;

    if (type == 'multipleChoice') {
      for (var resp in _responses) {
        final answer = (resp['responses'] ?? resp['answers'] ?? {})[id];
        if (answer != null && answer is String) {
          optionCounts[answer] = (optionCounts[answer] ?? 0) + 1;
          answeredCount++;
        }
      }
    } else if (type == 'multipleSelect') {
      for (var resp in _responses) {
        final answer = (resp['responses'] ?? resp['answers'] ?? {})[id];
        if (answer != null && answer is List) {
          for (var opt in answer) {
            optionCounts[opt] = (optionCounts[opt] ?? 0) + 1;
          }
          answeredCount++;
        }
      }
    } else {
      // Short answer or multiShortAnswer
      for (var resp in _responses) {
        final answer = (resp['responses'] ?? resp['answers'] ?? {})[id];
        if (answer != null && answer.toString().trim().isNotEmpty) {
          answeredCount++;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 0, 58, 92),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                if (isRequired)
                  const Text('*',
                      style: TextStyle(color: Colors.red, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            if (type == 'multipleChoice' || type == 'multipleSelect')
              ...options.map<Widget>((opt) {
                final count = optionCounts[opt] ?? 0;
                final percent = _totalResponses > 0
                    ? ((count / _totalResponses) * 100).toStringAsFixed(1)
                    : '0.0';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(opt.toString())),
                      Text('$count'),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: LinearProgressIndicator(
                          value:
                              _totalResponses > 0 ? count / _totalResponses : 0,
                          backgroundColor: Colors.grey.shade200,
                          color: Colors.blue,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$percent%'),
                    ],
                  ),
                );
              }).toList(),
            if (type == 'shortAnswer' || type == 'multiShortAnswer')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Responses:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  ..._responses
                      .map((resp) {
                        final answer =
                            (resp['responses'] ?? resp['answers'] ?? {})[id];
                        if (answer == null || answer.toString().trim().isEmpty)
                          return const SizedBox();
                        if (type == 'multiShortAnswer' && answer is List) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(answer.length, (i) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('- ${answer[i]}'),
                              );
                            }),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('- $answer'),
                        );
                      })
                      .where((w) => w is! SizedBox)
                      .toList(),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'Answered: $answeredCount / $_totalResponses',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Results'),
        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildResults(),
    );
  }
}
