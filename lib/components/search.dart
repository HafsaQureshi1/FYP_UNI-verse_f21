import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final collections = [
        'lostfoundposts',
        'Peerposts',
        'Eventposts',
        'Surveyposts',
      ];

      List<Map<String, dynamic>> results = [];

      for (String collection in collections) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection(collection)
            .doc('All')
            .collection('posts')
            .get();

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final content = (data['postContent'] ?? '').toString().toLowerCase();
       String location = '';
if (data['location'] is String) {
  location = data['location'].toLowerCase();
} else if (data['location'] is Map) {
  location = data['location'].toString().toLowerCase();
}
          final url = (data['url'] ?? '').toString().toLowerCase();
          final queryLower = query.toLowerCase();

          if (content.contains(queryLower) ||
              location.contains(queryLower) ||
              url.contains(queryLower)) {
            results.add({
              ...data,
              'id': doc.id,
              'collection': collection,
              'timestamp': data['timestamp'] ?? Timestamp.now(),
            });
          }
        }
      }

      results.sort((a, b) =>
          (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
String _getCollectionDisplayName2(String collection) {
  final normalized = collection.toLowerCase().trim();
  print("Normalized collection is: $normalized");
if (normalized == 'lostfoundposts') return 'Lost & Found';
  if (normalized == 'lostfoundposts/all/posts') return 'Lost & Found';
  if (normalized == 'peerposts/all/posts') return 'Peer Assistance';
    if (normalized == 'peerposts') return 'Peer Assistance';
  if (normalized == 'eventposts/all/posts') return 'Events & Jobs';
    if (normalized == 'eventposts') return 'Events & Jobs';
  if (normalized == 'surveyposts/all/posts') return 'Surveys';
    if (normalized == 'surveyposts') return 'Surveys';

  print("⚠️ Unmatched collection: $collection");
  return 'nknown Collection'; // Fallback
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search posts...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (value) => _performSearch(value),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
              ? const Center(child: Text('No results found'))
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    final timestamp = result['timestamp'] as Timestamp;
                    final formattedDate = DateFormat('MMM d, yyyy • h:mm a')
                        .format(timestamp.toDate());

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: ListTile(
                        title: Text(
                          result['userName'] ?? 'Anonymous',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(result['postContent'] ?? ''),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  _getCollectionDisplayName2(
                                      result['collection']),
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(' • '),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          // Navigate to post details if needed
                        },
                      ),
                    );
                  },
                ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
