import 'package:pawnder_app/models/community.dart';
import 'package:pawnder_app/models/community_post.dart';
import 'package:pawnder_app/services/api_client.dart';

class FeedService {
  FeedService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getNewFeed({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/community/new-feed',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    final data = response.data ?? const {};

    final communities = (data['communities'] as List? ?? const [])
        .map((c) => Community.fromJson(c as Map<String, dynamic>))
        .toList();

    final postsData = data['posts'] as Map<String, dynamic>? ?? const {};

    final lostPosts = (postsData['lost'] as List? ?? const [])
        .map((p) => CommunityPost.fromJson(p as Map<String, dynamic>))
        .toList();

    final foundPosts = (postsData['found'] as List? ?? const [])
        .map((p) => CommunityPost.fromJson(p as Map<String, dynamic>))
        .toList();

    final miscPosts = (postsData['misc'] as List? ?? const [])
        .map((p) => CommunityPost.fromJson(p as Map<String, dynamic>))
        .toList();

    final tags = (data['applicable_tags'] as List?)?.cast<String>() ?? [];

    return {
      'communities': communities,
      'posts': {
        'lost': lostPosts,
        'found': foundPosts,
        'misc': miscPosts,
      },
      'applicable_tags': tags,
    };
  }
}