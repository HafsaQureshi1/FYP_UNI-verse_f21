import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

// Update the enum to include multiple selection options
enum QuestionType {
  multipleChoice, // Single selection radio buttons
  multipleSelect, // Multiple selection checkboxes
  shortAnswer, // Single text field
  multiShortAnswer // Multiple text fields
}

class SurveyQuestion {
  String id;
  String question;
  QuestionType type;
  List<String> options;
  bool isRequired;
  int numberOfFields; // For multiShortAnswer, how many fields to show

  SurveyQuestion({
    String? id,
    required this.question,
    required this.type,
    required this.options,
    this.isRequired = false,
    this.numberOfFields = 1,
  }) : id = id ?? const Uuid().v4();
}

class SurveyFormCreator extends StatefulWidget {
  final String collectionName;

  const SurveyFormCreator({Key? key, required this.collectionName})
      : super(key: key);

  @override
  _SurveyFormCreatorState createState() => _SurveyFormCreatorState();
}

class _SurveyFormCreatorState extends State<SurveyFormCreator> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  List<SurveyQuestion> questions = [];

  @override
  void initState() {
    super.initState();
    // Add a default question
    questions.add(SurveyQuestion(
      question: '',
      type: QuestionType.multipleChoice,
      options: ['Option 1', 'Option 2'],
    ));
  }

  void _addQuestion() {
    setState(() {
      questions.add(SurveyQuestion(
        question: '',
        type: QuestionType.multipleChoice,
        options: ['Option 1', 'Option 2'],
      ));
    });
  }

  void _removeQuestion(int index) {
    if (questions.length > 1) {
      setState(() {
        questions.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey must have at least one question')),
      );
    }
  }

  void _addOption(int questionIndex) {
    setState(() {
      questions[questionIndex].options.add('New Option');
    });
  }

  void _removeOption(int questionIndex, int optionIndex) {
    if (questions[questionIndex].options.length > 2) {
      setState(() {
        questions[questionIndex].options.removeAt(optionIndex);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Multiple choice questions need at least 2 options')),
      );
    }
  }

  // Update the question type toggle method to handle all types
  void _toggleQuestionType(int index, QuestionType newType) {
    setState(() {
      final oldType = questions[index].type;
      questions[index].type = newType;

      // Handle options based on question type
      if (newType == QuestionType.multipleChoice ||
          newType == QuestionType.multipleSelect) {
        // For multiple choice/select, ensure we have options
        if (questions[index].options.isEmpty) {
          questions[index].options = ['Option 1', 'Option 2'];
        }
      } else if (newType == QuestionType.shortAnswer) {
        // For short answer, clear options
        questions[index].options = [];
      } else if (newType == QuestionType.multiShortAnswer) {
        // For multi short answer, set default number of fields
        questions[index].options = [];
        questions[index].numberOfFields = 3; // Default to 3 answer fields
      }
    });
  }

  // Add method to adjust number of text fields for multiShortAnswer
  void _adjustNumberOfFields(int questionIndex, bool increase) {
    setState(() {
      if (increase) {
        questions[questionIndex].numberOfFields++;
      } else if (questions[questionIndex].numberOfFields > 1) {
        questions[questionIndex].numberOfFields--;
      }
    });
  }

  // Add the missing _toggleRequired method
  void _toggleRequired(int index) {
    setState(() {
      questions[index].isRequired = !questions[index].isRequired;
    });
  }

  Future<void> _submitSurvey() async {
    // Check the form validation safely without using ! operator
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      // If form is null or validation fails
      if (_formKey.currentState == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form validation failed')),
        );
      }
      return;
    }

    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one question to the survey')),
      );
      return;
    }

    // Check if all questions have content
    for (int i = 0; i < questions.length; i++) {
      if (questions[i].question.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question ${i + 1} cannot be empty')),
        );
        return;
      }

      // Check options for multiple choice questions
      if (questions[i].type == QuestionType.multipleChoice) {
        for (int j = 0; j < questions[i].options.length; j++) {
          if (questions[i].options[j].trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Option ${j + 1} in question ${i + 1} cannot be empty')),
            );
            return;
          }
        }
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get user details from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String username = userDoc.data()?['username'] ?? 'Anonymous';

      // Convert questions to a serializable format
      final List<Map<String, dynamic>> questionsData = questions
          .map((q) => {
                'id': q.id,
                'question': q.question,
                'type': q.type.toString().split('.').last,
                'options': q.options,
                'isRequired': q.isRequired,
                'numberOfFields': q.numberOfFields,
              })
          .toList();

      // Create survey document with isSurveyForm flag
      final surveyData = {
        'userId': user.uid,
        'userName': username,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'questions': questionsData,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'responses': 0,
        'isSurveyForm': true, // Add this flag
        'postContent':
            _titleController.text.trim(), // For backward compatibility
      };

      // Submit to admin for approval
      await FirebaseFirestore.instance
          .collection('surveyadmin')
          .doc('All')
          .collection('posts')
          .add(surveyData);

      // Show success message and pop back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Survey submitted for approval successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error submitting survey: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating survey: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
        title: const Text(
          'Create Survey',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      // Use a SafeArea to prevent overflow at the bottom
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                // Use a more responsive layout
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    const SizedBox(height: 16),
                    // Survey Title
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Survey Title',
                        hintText: 'Enter a title for your survey',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title for your survey';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Survey Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Add a description for your survey',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Remove External URL field
                    // const SizedBox(height: 16),

                    // Remove Image Upload section
                    // const SizedBox(height: 24),

                    // Section Divider
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Row(
                        children: [
                          Icon(Icons.help_outline),
                          SizedBox(width: 8),
                          Text(
                            'Questions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(thickness: 1.5),

                    // Questions List
                    ...List.generate(
                      questions.length,
                      (index) => _buildQuestionCard(index),
                    ),

                    const SizedBox(height: 16),
                    // Add Question Button
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Question'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _submitSurvey,
                      child: const Text(
                        'Submit Survey for Approval',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 40), // Bottom padding
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    // Safely access the question
    final question = index < questions.length ? questions[index] : null;

    if (question == null) {
      return const SizedBox(); // Return empty widget if question is null
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header with number and delete button
            Row(
              children: [
                // Question number
                CircleAvatar(
                  backgroundColor: const Color.fromARGB(255, 0, 58, 92),
                  radius: 16,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Remove question button
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Question text field
            TextFormField(
              initialValue: question.question,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'Enter your question here',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  questions[index].question = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // Question type selector - use wrap for better spacing
            const Text(
              'Question Type:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            // Use Wrap widget to prevent overflow on small screens
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Single Choice'),
                  selected: question.type == QuestionType.multipleChoice,
                  onSelected: (selected) {
                    if (selected)
                      _toggleQuestionType(index, QuestionType.multipleChoice);
                  },
                ),
                ChoiceChip(
                  label: const Text('Multiple Select'),
                  selected: question.type == QuestionType.multipleSelect,
                  onSelected: (selected) {
                    if (selected)
                      _toggleQuestionType(index, QuestionType.multipleSelect);
                  },
                ),
                ChoiceChip(
                  label: const Text('Short Answer'),
                  selected: question.type == QuestionType.shortAnswer,
                  onSelected: (selected) {
                    if (selected)
                      _toggleQuestionType(index, QuestionType.shortAnswer);
                  },
                ),
                ChoiceChip(
                  label: const Text('Multi Text Inputs'),
                  selected: question.type == QuestionType.multiShortAnswer,
                  onSelected: (selected) {
                    if (selected)
                      _toggleQuestionType(index, QuestionType.multiShortAnswer);
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Options section based on question type
            _buildQuestionOptions(index, question),

            const SizedBox(height: 8),

            // Required toggle
            Row(
              children: [
                Checkbox(
                  value: question.isRequired,
                  onChanged: (_) => _toggleRequired(index),
                ),
                const Text('Required'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Safely build question options with null checks
  Widget _buildQuestionOptions(int index, SurveyQuestion question) {
    // Multiple choice (radio buttons)
    if (question.type == QuestionType.multipleChoice) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Options: (Single Selection)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...List.generate(question.options.length, (optionIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Radio(
                    value: optionIndex,
                    groupValue: null,
                    onChanged: (_) {},
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: question.options[optionIndex],
                      decoration: InputDecoration(
                        hintText: 'Option ${optionIndex + 1}',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          questions[index].options[optionIndex] = value;
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
                    onPressed: () => _removeOption(index, optionIndex),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Option'),
            onPressed: () => _addOption(index),
          ),
        ],
      );
    }

    // Multiple select (checkboxes)
    else if (question.type == QuestionType.multipleSelect) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Options: (Multiple Selection)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...List.generate(question.options.length, (optionIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Checkbox(
                    value: false,
                    onChanged: (_) {},
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: question.options[optionIndex],
                      decoration: InputDecoration(
                        hintText: 'Option ${optionIndex + 1}',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          questions[index].options[optionIndex] = value;
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
                    onPressed: () => _removeOption(index, optionIndex),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Option'),
            onPressed: () => _addOption(index),
          ),
        ],
      );
    }

    // Short answer (single text field)
    else if (question.type == QuestionType.shortAnswer) {
      return Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Short Answer Field',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Respondent\'s answer will appear here',
                filled: true,
                fillColor: Colors.white,
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Multi text inputs (multiple text fields)
    else {
      // For multiShortAnswer, ensure numberOfFields is always initialized
      final numberOfFields =
          question.numberOfFields > 0 ? question.numberOfFields : 1;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Multiple Text Fields',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _adjustNumberOfFields(index, false),
                    tooltip: 'Decrease fields',
                  ),
                  Text('${question.numberOfFields}'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _adjustNumberOfFields(index, true),
                    tooltip: 'Increase fields',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: List.generate(numberOfFields, (fieldIndex) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (question.numberOfFields > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text('Field ${fieldIndex + 1}'),
                        ),
                      const TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          hintText: 'Respondent\'s answer will appear here',
                          filled: true,
                          fillColor: Colors.white,
                          disabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      );
    }
  }
}
