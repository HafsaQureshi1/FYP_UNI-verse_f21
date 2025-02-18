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
      // List of collections to search through
      final collections = [
        'lostfoundposts',
        'Peerposts',
        'Eventposts',
        'Surveyposts',
      ];

      List<Map<String, dynamic>> results = [];

      // Search in each collection
      for (String collection in collections) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection(collection)
            .where('postContent', isGreaterThanOrEqualTo: query)
            .where('postContent', isLessThanOrEqualTo: query + '\uf8ff')
            .get();

        // Process results from this collection
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          results.add({
            ...data,
            'id': doc.id,
            'collection': collection,
            'timestamp': data['timestamp'] ?? Timestamp.now(),
          });
        }
      }

      // Sort results by timestamp
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

  String _getCollectionDisplayName(String collection) {
    switch (collection) {
      case 'lostfoundposts':
        return 'Lost & Found';
      case 'Peerposts':
        return 'Peer Assistance';
      case 'Eventposts':
        return 'Events & Jobs';
      case 'Surveyposts':
        return 'Surveys';
      default:
        return collection;
    }
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
              ? const Center(
                  child: Text('No results found'),
                )
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
                                  _getCollectionDisplayName(
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
                          // Navigate to the post detail if needed
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
