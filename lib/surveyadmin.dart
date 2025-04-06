import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyAdmin extends StatefulWidget {
  const SurveyAdmin({super.key});

  @override
  _SurveyAdminState createState() => _SurveyAdminState();
}

class _SurveyAdminState extends State<SurveyAdmin> {
  // Theme colors - match with Home.dart
  final Color _primaryColor = const Color.fromARGB(255, 0, 58, 92);
  final Color _backgroundColor = const Color.fromARGB(64, 236, 236, 236);

  Stream<QuerySnapshot> _getSurveysStream() {
    return FirebaseFirestore.instance
        .collection('surveyadmin')
        .doc("All")
        .collection("posts")
        .where('approval', isEqualTo: null)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<String> _getUserProfilePicture(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.data()?['profilePicture'] ?? '';
    } catch (e) {
      print("Error fetching profile picture: $e");
      return '';
    }
  }

  Future<void> _approveSurvey(DocumentSnapshot survey) async {
    final surveyData = survey.data() as Map<String, dynamic>;
    final surveyId = survey.id;

    final approvedSurveyData = {
      ...surveyData,
      'approval': 'approved',
    };

    await FirebaseFirestore.instance
        .collection('Surveyposts')
        .doc("All")
        .collection("posts")
        .doc(surveyId)
        .set(approvedSurveyData);

    await FirebaseFirestore.instance
        .collection('surveyadmin')
        .doc("All")
        .collection("posts")
        .doc(surveyId)
        .delete();
  }

  Future<void> _rejectSurvey(DocumentSnapshot survey) async {
    final surveyId = survey.id;
    await FirebaseFirestore.instance
        .collection('surveyadmin')
        .doc("All")
        .collection("posts")
        .doc(surveyId)
        .delete();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();

    // Convert to 12-hour format with AM/PM
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.day}/${date.month}/${date.year} $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: _getSurveysStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.poll_outlined,
                      size: 70, color: _primaryColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No surveys to approve',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
            );
          }

          var surveys = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: surveys.length,
            itemBuilder: (context, index) {
              var surveyData = surveys[index].data() as Map<String, dynamic>;
              String userId = surveyData['userId'] ?? '';
              String username = surveyData['userName'] ?? 'Anonymous';
              String title = surveyData['postContent'] ?? '';
              String description = surveyData['description'] ?? '';
              List<dynamic> options = surveyData['options'] ?? [];
              String imageUrl = surveyData['imageUrl'] ?? '';
              Timestamp? timestamp = surveyData['timestamp'];

              return FutureBuilder<String>(
                future: _getUserProfilePicture(userId),
                builder: (context, profileSnapshot) {
                  String profileImageUrl = profileSnapshot.data ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (profileImageUrl.isNotEmpty)
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      NetworkImage(profileImageUrl),
                                )
                              else
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      _primaryColor.withOpacity(0.2),
                                  child:
                                      Icon(Icons.person, color: _primaryColor),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _formatTimestamp(timestamp),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 200,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                      child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        _primaryColor),
                                  ));
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  height: 100,
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Options:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          ...options.map((option) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 8.0, top: 4.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.circle,
                                        size: 8, color: _primaryColor),
                                    const SizedBox(width: 8),
                                    Text(option),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _approveSurvey(surveys[index]),
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Approve",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF28A745),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () => _rejectSurvey(surveys[index]),
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Reject",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC3545),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
