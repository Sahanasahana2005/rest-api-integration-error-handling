import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// 1. Data Model with JSON Serialization
class Post {
  final int id;
  final String title;
  final String body;

  Post({required this.id, required this.title, required this.body});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
  };
}

// 2. API Service Class (GET, POST, PUT)
class ApiService {
  static const String baseUrl = "https://jsonplaceholder.typicode.com";

  Future<List<Post>> fetchPosts(int page, int limit) async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts?_page=$page&_limit=$limit'),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Post.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load posts from API');
    }
  }

  Future<Post> createPost(String title, String body) async {
    final response = await http.post(
      Uri.parse('$baseUrl/posts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title, 'body': body, 'userId': 1}),
    );
    return Post.fromJson(jsonDecode(response.body));
  }

  Future<Post> updatePost(int id, String title, String body) async {
    final response = await http.put(
      Uri.parse('$baseUrl/posts/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': id, 'title': title, 'body': body, 'userId': 1}),
    );
    return Post.fromJson(jsonDecode(response.body));
  }
}

void main() => runApp(const ApiApp());

class ApiApp extends StatelessWidget {
  const ApiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REST API & Error Handling',
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const PostListScreen(),
    );
  }
}

class PostListScreen extends StatefulWidget {
  const PostListScreen({super.key});

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasError = false;
  String _errorMessage = "";
  int _page = 1;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadInitialPosts() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _page = 1;
    });
    try {
      final posts = await _apiService.fetchPosts(_page, _limit);
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = "Network Error: Unable to fetch data.";
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMore && !_isLoading) {
      _fetchMorePosts();
    }
  }

  Future<void> _fetchMorePosts() async {
    setState(() => _isFetchingMore = true);
    try {
      _page++;
      final newPosts = await _apiService.fetchPosts(_page, _limit);
      setState(() {
        _posts.addAll(newPosts);
        _isFetchingMore = false;
      });
    } catch (e) {
      setState(() => _isFetchingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('REST API & Network Error Handling')),
      body: Column(
        children: [
          // Network Error Banner
          if (_hasError)
            Container(
              color: Colors.redAccent,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.white))),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadInitialPosts,
                  )
                ],
              ),
            ),
          
          Expanded(
            child: _isLoading
                ? _buildShimmerLoadingSkeleton()
                : RefreshIndicator(
                    onRefresh: _loadInitialPosts, // Pull-to-Refresh
                    child: ListView.builder(
                      controller: _scrollController, // Infinite Scroll Pagination
                      itemCount: _posts.length + (_isFetchingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _posts.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final post = _posts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${post.id}')),
                            title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Shimmer Skeleton Loading Animation Replacement
  Widget _buildShimmerLoadingSkeleton() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
