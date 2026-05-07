class PostLocation {
  const PostLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  factory PostLocation.fromJson(Map<String, dynamic> json) {
    return PostLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.postType,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.location,
    required this.tags,
    this.likeCount = 0,
    this.commentCount = 0,
    this.youLiked = false,
    this.edited = false,
    this.comments = const [],
    this.communityId,
    this.authorName,
    this.imageUrl,
  });

  final String id;
  final String authorId;
  final String? communityId;
  final String? authorName;
  final String postType;
  final String title;
  final String description;
  final String? imageUrl;
  final String status;
  final DateTime createdAt;
  final PostLocation location;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final bool youLiked;
  final bool edited;
  final List<PostComment> comments;

  String get formattedCreatedAt {
    final local = createdAt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$month/$day/$year';
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final rawLocation = json['location'] as Map<String, dynamic>? ?? {};

    return CommunityPost(
      id: (json['id'] ?? json['post_id'])?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      communityId: json['community_id']?.toString(),
      authorName: json['author_username']?.toString(),
      postType: json['post_type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      status: json['status']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      location: PostLocation.fromJson(rawLocation),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag.toString())
          .toList(),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      youLiked: json['you_liked'] as bool? ?? false,
      edited: json['edited'] as bool? ?? false,
      comments: (json['comments'] as List<dynamic>? ?? const [])
          .map(
            (comment) => PostComment.fromJson(comment as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, String> toFeedMap() {
    return {
      'id': id,
      'title': title,
      'authorId': authorId,
      'communityId': communityId ?? '',
      'author': authorName ?? 'Community member',
      'location': '${location.latitude}, ${location.longitude}',
      'posted': formattedCreatedAt,
      'tags': tags.join('|'),
      'image': imageUrl ?? '',
      'description': description,
      'postType': postType,
      'commentCount': '$commentCount',
      'likeCount': '$likeCount',
      'youLiked': '$youLiked',
      'edited': '$edited',
    };
  }

  CommunityPost copyWith({
    String? id,
    String? authorId,
    String? communityId,
    String? authorName,
    String? postType,
    String? title,
    String? description,
    String? imageUrl,
    String? status,
    DateTime? createdAt,
    PostLocation? location,
    List<String>? tags,
    int? likeCount,
    int? commentCount,
    bool? youLiked,
    bool? edited,
    List<PostComment>? comments,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      communityId: communityId ?? this.communityId,
      authorName: authorName ?? this.authorName,
      postType: postType ?? this.postType,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      youLiked: youLiked ?? this.youLiked,
      edited: edited ?? this.edited,
      comments: comments ?? this.comments,
    );
  }

  Map<String, String> toPetMap() {
    final normalizedTags = tags.map((tag) => tag.toLowerCase()).toList();
    final category = normalizedTags.contains('dog')
        ? 'dog'
        : normalizedTags.contains('cat')
        ? 'cat'
        : normalizedTags.contains('bird')
        ? 'bird'
        : 'all';

    return {
      'id': id,
      'authorId': authorId,
      'name': title,
      'meta': [
        postType,
        if (tags.isNotEmpty) tags.take(2).join(', '),
      ].where((value) => value.trim().isNotEmpty).join(' - '),
      'category': category,
      'image': imageUrl ?? '',
      'location': '${location.latitude}, ${location.longitude}',
      'about': description,
      'ownerName': authorName ?? 'Community member',
      'ownerMeta': 'Posted $formattedCreatedAt',
      'breed': tags.isEmpty ? 'Unknown' : tags.first,
      'age': 'Not listed',
      'weight': 'Not listed',
    };
  }
}

class PostComment {
  const PostComment({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.likeCount = 0,
    this.youLiked = false,
    this.replyingToId,
  });

  final String commentId;
  final String postId;
  final String userId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final int likeCount;
  final bool youLiked;
  final String? replyingToId;

  String get relativeCreatedAt {
    final difference = DateTime.now().difference(createdAt.toLocal());

    if (difference.inMinutes < 1) {
      return '0m ago';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final rawAuthorName = json['author_name']?.toString() ?? '';

    return PostComment(
      commentId: json['comment_id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      authorName: rawAuthorName.trim().isEmpty ? 'Member' : rawAuthorName.trim(),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      youLiked: json['you_liked'] as bool? ?? false,
      replyingToId: json['replying_to_id']?.toString(),
    );
  }

  PostComment copyWith({
    String? commentId,
    String? postId,
    String? userId,
    String? authorName,
    String? content,
    DateTime? createdAt,
    int? likeCount,
    bool? youLiked,
    String? replyingToId,
  }) {
    return PostComment(
      commentId: commentId ?? this.commentId,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      youLiked: youLiked ?? this.youLiked,
      replyingToId: replyingToId ?? this.replyingToId,
    );
  }
}

class CreatePostRequest {
  const CreatePostRequest({
    required this.communityId,
    required this.authorId,
    required this.postType,
    required this.title,
    required this.description,
    required this.location,
    required this.tags,
    this.imageUrl,
  });

  final String communityId;
  final String authorId;
  final String postType;
  final String title;
  final String description;
  final String? imageUrl;
  final PostLocation location;
  final List<String> tags;

  Map<String, dynamic> toJson() {
    return {
      'community_id': communityId,
      'author_id': authorId,
      'post_type': postType,
      'title': title,
      'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      'location': location.toJson(),
      'tags': tags,
    };
  }
}