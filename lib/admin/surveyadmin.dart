import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fcm-service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SurveyAdmin extends StatefulWidget {
  const SurveyAdmin({super.key});

  @override
  _SurveyAdminState createState() => _SurveyAdminState();
}

class _SurveyAdminState extends State<SurveyAdmin> {
  // Theme colors - match with Home.dart
  final Color _primaryColor = const Color.fromARGB(255, 0, 58, 92);
  final Color _backgroundColor = const Color.fromARGB(64, 236, 236, 236);
  final ScrollController _scrollController = ScrollController();

  // Add toast notification method
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );
  }

  // Stream for pending approval surveys
  Stream<QuerySnapshot> _getPendingSurveysStream() {
    return FirebaseFirestore.instance
        .collection('surveyadmin')
        .doc("All")
        .collection("posts")
        .where('approval', isEqualTo: null)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Stream for all approved surveys
  Stream<QuerySnapshot> _getAllSurveysStream() {
    return FirebaseFirestore.instance
        .collection('Surveyposts')
        .doc("All")
        .collection("posts")
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
    final posterId = surveyData['userId'];
    final posterName = surveyData['userName'] ?? 'Someone';
    
    if (posterId == null) {
      print("❌ No userId field found in post");
      return;
    }
    
    _showLoadingDialog(context, "Approving post and sending notifications...");

    final approvedSurveyData = {
      ...surveyData,
      'approval': 'approved',
      'timestamp': FieldValue.serverTimestamp(),
      // Add a field to indicate if this is a form survey or just a URL post
      // Only set isSurveyForm to true if this was created through the form creator
      'isSurveyForm': surveyData['questions'] != null &&
          (surveyData['questions'] as List).isNotEmpty,
      'postContent': (surveyData['title']?.trim().isNotEmpty ?? false)
    ? surveyData['title']
    : (surveyData['postContent']?.trim().isNotEmpty ?? false)
        ? surveyData['postContent']
        : 'New Survey',

    };

    // Move to main approved collection
    await FirebaseFirestore.instance
        .collection('Surveyposts')
        .doc("All")
        .collection("posts")
        .doc(surveyId)
        .set(approvedSurveyData);

    // Remove from admin approval list
    await FirebaseFirestore.instance
        .collection('surveyadmin')
        .doc("All")
        .collection("posts")
        .doc(surveyId)
        .delete();

    // Send push notification
    final FCMService _fcmService = FCMService();

    await _fcmService.sendNotificationOnNewPost(
      posterId,
      posterName,
      'Surveys',
    );
    await _fcmService.sendNotificationPostApproved(posterId, 'Surveys');

    // Create notifications
    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': posterId,
      'senderId': 'admin',
      'senderName': 'Admin',
      'postId': surveyId,
      'collection': 'Surveyposts/All/posts',
      'message': "✅ Your survey was approved by admin",
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'approval',
      'isRead': false,
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': null,
      'senderId': posterId,
      'senderName': posterName,
      'postId': surveyId,
      'collection': 'Surveyposts/All/posts',
      'message': "📢 $posterName added a new survey",
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'new_post',
      'isRead': false,
    });
    
    Navigator.of(context, rootNavigator: true).pop();
    _showToast("Post approved");
  }

  Future<void> _rejectSurvey(DocumentSnapshot survey) async {
    final postData = survey.data() as Map<String, dynamic>;
    final posterId = postData['userId'] ?? '';
    final posterName = postData['userName'] ?? 'Someone';
    final surveyId = survey.id;

    await FirebaseFirestore.instance
        .collection('surveyadmin')
        .doc("All")
        .collection("posts")
        .doc(surveyId)
        .delete();

    final FCMService _fcmService = FCMService();
    await _fcmService.sendNotificationPostRejected(posterId, 'Surveys');

    _showToast("Survey rejected");
    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': posterId,
      'senderId': 'admin',
      'senderName': 'Admin',
      'postId': surveyId,
      'collection': 'Surveyposts/All/posts',
      'message': "❌ Your survey was rejected by admin",
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'rejection',
      'isRead': false,
    });
  }

  Future<void> _deleteSurvey(DocumentSnapshot survey) async {
    final surveyId = survey.id;
    await FirebaseFirestore.instance
        .collection('Surveyposts')
        .doc("All")
        .collection("posts")
        .doc(surveyId)
        .delete();

    _showToast("Survey deleted successfully");
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

  Widget _buildSurveyCard(DocumentSnapshot survey, {bool showApproveReject = false}) {
    final surveyData = survey.data() as Map<String, dynamic>;
    final String userId = surveyData['userId'] ?? '';
    final String username = surveyData['userName'] ?? 'Anonymous';
    final String title = surveyData['title'] ?? '';
    final String description = surveyData['description'] ?? '';
    final String content = surveyData['postContent'] ?? '';
    
    final String imageUrl = surveyData['imageUrl'] ?? '';
    final String url = surveyData['url'] ?? '';
    final Timestamp? timestamp = surveyData['timestamp'];
    
    // Handle both old and new survey formats
    final List<dynamic> questions = surveyData['questions'] ?? [];

    return FutureBuilder<String>(
      future: _getUserProfilePicture(userId),
      builder: (context, profileSnapshot) {
        final String profileImageUrl = profileSnapshot.data ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
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
                        backgroundImage: NetworkImage(profileImageUrl),
                      )
                    else
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _primaryColor.withOpacity(0.2),
                        child: Icon(Icons.person, color: _primaryColor),
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
                    if (!showApproveReject)
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red[700]),
                        onPressed: () => _deleteSurvey(survey),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Display survey title and description
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(description),
                ],

                const SizedBox(height: 12),

                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                _primaryColor),
                          ),
                        );
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
 if (content.isNotEmpty && questions.isEmpty) ...[
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
              ],
                if (url.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.link, size: 18, color: _primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              url,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Display survey questions
                if (questions.isNotEmpty) ...[
                  const Text(
                    'Preview of Questions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < questions.length; i++) ...[
                          if (i > 0) const Divider(height: 16),
                          _buildQuestionPreview(questions[i], i),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                if (showApproveReject) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _rejectSurvey(survey),
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
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _approveSurvey(survey),
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
                    ],
                  )
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionPreview(Map<String, dynamic> questionData, int index) {
    final String question = questionData['question'] ?? '';
    final String type = questionData['type'] ?? 'multipleChoice';
    final List<dynamic> options = questionData['options'] ?? [];
    final bool isRequired = questionData['isRequired'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${index + 1}. $question',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isRequired)
              const Text(' *',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
            'Type: ${type == 'multipleChoice' ? 'Multiple Choice' : 'Short Answer'}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        if (type == 'multipleChoice' && options.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...options.map((option) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: _primaryColor),
                    const SizedBox(width: 8),
                    Text(option.toString()),
                  ],
                ),
              )),
        ],
        if (type == 'shortAnswer')
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 16),
            child: Text('(Short answer field)',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _buildPendingSurveysTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getPendingSurveysStream(),
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
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: surveys.length,
          itemBuilder: (context, index) => _buildSurveyCard(surveys[index], showApproveReject: true),
        );
      },
    );
  }

  Widget _buildAllSurveysTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAllSurveysStream(),
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
                Icon(Icons.assessment_outlined,
                    size: 70, color: _primaryColor.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  'No approved surveys available',
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
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: surveys.length,
          itemBuilder: (context, index) => _buildSurveyCard(surveys[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 10,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.black,
            indicatorColor: Color.fromARGB(255, 0, 28, 187),
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'All Surveys'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingSurveysTab(),
            _buildAllSurveysTab(),
          ],
        ),
      ),
    );
  }
}