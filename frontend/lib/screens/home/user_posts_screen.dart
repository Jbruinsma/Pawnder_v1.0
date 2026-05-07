import 'package:flutter/material.dart';
import 'package:pawnder_app/models/community_post.dart';
import 'package:pawnder_app/screens/home/unified_post_detail_screen.dart';
import 'package:pawnder_app/widgets/build_community_posts_feed.dart';
import 'package:pawnder_app/widgets/build_header.dart';

class UserPostsScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData fallbackIcon;
  final Future<List<CommunityPost>> Function() loadPosts;

  const UserPostsScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fallbackIcon,
    required this.loadPosts,
  });

  @override
  State<UserPostsScreen> createState() => _UserPostsScreenState();
}

class _UserPostsScreenState extends State<UserPostsScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  String? _errorMessage;
  List<CommunityPost> _posts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final posts = await widget.loadPosts();
      if (!mounted) {
        return;
      }

      setState(() => _posts = posts);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Could not load posts right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handlePostUpdate(Map<String, String>? updatedPost) {
    if (updatedPost == null || !mounted) return;

    setState(() {
      final postId = updatedPost['id'];
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index] = _posts[index].copyWith(
          title: updatedPost['title'],
          description: updatedPost['description'],
          postType: updatedPost['postType'],
          imageUrl: updatedPost['image'],
          tags: updatedPost['tags']?.split('|').where((t) => t.isNotEmpty).toList(),
          likeCount: int.tryParse(updatedPost['likeCount'] ?? '0') ?? 0,
          commentCount: int.tryParse(updatedPost['commentCount'] ?? '0') ?? 0,
          youLiked: updatedPost['youLiked'] == 'true',
          edited: updatedPost['edited'] == 'true',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postMaps = _posts.map((post) => post.toFeedMap()).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeHeader(
                title: widget.title,
                subtitle: widget.subtitle,
                fallbackIcon: widget.fallbackIcon,
                trailing: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search your posts...',
                          border: InputBorder.none,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? _PostsNotice(
                        message: _errorMessage!,
                        actionLabel: 'Try again',
                        onPressed: _load,
                      )
                    : _posts.isEmpty
                    ? const _PostsNotice(
                        message:
                            'No listings yet. Create a post and it will show up here.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: theme.colorScheme.primary,
                        child: buildCommunityPostsFeed(
                          posts: postMaps,
                          searchQuery: _searchQuery,
                          onPostTap: (postMap) async {
                            final result = await Navigator.push<Map<String, String>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UnifiedPostDetailScreen(
                                  post: postMap,
                                ),
                              ),
                            );
                            _handlePostUpdate(result);
                          },
                          onCommentTap: (postMap) async {
                            final result = await Navigator.push<Map<String, String>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UnifiedPostDetailScreen(
                                  post: postMap,
                                ),
                              ),
                            );
                            _handlePostUpdate(result);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostsNotice extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onPressed;

  const _PostsNotice({required this.message, this.actionLabel, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt_rounded,
              size: 34,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: onPressed,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}