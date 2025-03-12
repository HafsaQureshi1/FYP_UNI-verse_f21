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

          return ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: const Color.fromARGB(255, 255, 255, 255),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(12),
                    leading: Icon(
                      data['type'] == 'like' ? Icons.favorite : Icons.comment,
                      color: data['type'] == 'like' ? Colors.red : Colors.blue,
                    ),
                    title: Text(
                      data['message'],
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      data['timestamp'] != null
                          ? data['timestamp'].toDate().toString()
                          : 'No timestamp',
                      style: TextStyle(color: Colors.grey),
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
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
