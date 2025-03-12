import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Notifications")),
        body: Center(child: Text("Error: User not authenticated")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Notifications")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: currentUserId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No notifications yet."));
          }

          // Debugging: Print fetched notifications
          print("Fetched ${snapshot.data!.docs.length} notifications");
          for (var doc in snapshot.data!.docs) {
            print("Notification Data: ${doc.data()}");
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;

              return ListTile(
                leading: Icon(
                  data['type'] == 'like' ? Icons.favorite : Icons.comment,
                  color: Colors.red,
                ),
                title: Text(data['message']),
                subtitle: Text(
                  data['timestamp'] != null
                      ? data['timestamp'].toDate().toString()
                      : 'No timestamp',
                ),
                trailing: data['isRead'] == true
                    ? Icon(Icons.check, color: Colors.green)
                    : Icon(Icons.circle, color: Colors.blue),
                onTap: () {
                  // Mark notification as read when tapped
                  FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(doc.id)
                      .update({'isRead': true}).catchError((error) {
                    print("Error updating notification: $error");
                  });
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
