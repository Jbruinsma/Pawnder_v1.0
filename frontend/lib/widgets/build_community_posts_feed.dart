import 'package:flutter/material.dart';
import 'package:pawnder_app/theme.dart';
import 'package:pawnder_app/widgets/pet_image.dart';

Widget buildCommunityPostsFeed({
  required List<Map<String, String>> posts,
  required String searchQuery,
  required ValueChanged<Map<String, String>> onPostTap,
  Future<void> Function(Map<String, String> post)? onCommentTap,
  Future<void> Function(Map<String, String> post)? onLikeTap,
  Future<void> Function(Map<String, String> post)? onDeleteTap,
  String? currentUserId,
}) {
  final query = searchQuery.trim().toLowerCase();

  final visiblePosts = query.isEmpty
      ? posts
      : posts.where((post) {
    final title = (post['title'] ?? '').toLowerCase();
    final description = (post['description'] ?? '').toLowerCase();
    final author = (post['author'] ?? '').toLowerCase();
    final location = (post['location'] ?? '').toLowerCase();
    return title.contains(query) ||
        description.contains(query) ||
        author.contains(query) ||
        location.contains(query);
  }).toList();

  if (visiblePosts.isEmpty) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Center(
          child: Text(
            'No posts found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }

  return ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.only(bottom: 92),
    itemCount: visiblePosts.length,
    separatorBuilder: (context, index) => const SizedBox(height: 14),
    itemBuilder: (context, index) {
      final post = visiblePosts[index];
      final isAuthor =
          currentUserId != null && post['authorId'] == currentUserId;
      return _StackedPostCard(
        post: post,
        onTap: () => onPostTap(post),
        onCommentTap: onCommentTap == null ? null : () => onCommentTap(post),
        onLikeTap: onLikeTap == null ? null : () => onLikeTap(post),
        onDeleteTap: (onDeleteTap == null || !isAuthor)
            ? null
            : () => onDeleteTap(post),
      );
    },
  );
}

class _StackedPostCard extends StatelessWidget {
  final Map<String, String> post;
  final VoidCallback onTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onDeleteTap;

  const _StackedPostCard({
    required this.post,
    required this.onTap,
    this.onCommentTap,
    this.onLikeTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final youLiked = post['youLiked'] == 'true';
    final hasImage = (post['image'] ?? '').trim().isNotEmpty;
    final tags = (post['tags'] ?? '')
        .split('|')
        .where((tag) => tag.trim().isNotEmpty)
        .toList();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: AspectRatio(
                  aspectRatio: 1.55,
                  child: PetImage(
                    image: post['image'],
                    height: double.infinity,
                    width: double.infinity,
                    preserveSubject: true,
                    seed: post['id'] ?? post['title'] ?? '',
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              post['title'] ?? 'Untitled',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 19,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onDeleteTap != null) ...[
                            _RoundCardAction(
                              icon: Icons.delete_outline_rounded,
                              iconColor: Colors.redAccent,
                              onTap: onDeleteTap,
                            ),
                            const SizedBox(width: 8),
                          ],
                          _RoundCardAction(
                            icon: youLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            iconColor: youLiked
                                ? Colors.redAccent
                                : theme.colorScheme.onSurface,
                            onTap: onLikeTap,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if ((post['description'] ?? '').trim().isNotEmpty) ...[
                    Text(
                      post['description'] ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusBadge(
                        label: post['postType'] ?? 'Post',
                      ),
                      ...tags.take(3).map((tag) => _TagChip(tag: tag)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Posted ${post['posted'] ?? 'Recently'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InlineMeta(
                        icon: Icons.mode_comment_outlined,
                        label: post['commentCount'] ?? '0',
                      ),
                      const SizedBox(width: 12),
                      _InlineMeta(
                        icon: youLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: post['likeCount'] ?? '0',
                        iconColor: youLiked ? Colors.redAccent : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _InlineMeta({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: iconColor ?? theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  Color _getTextColor(String type, ThemeData theme) {
    final t = type.toLowerCase();
    if (t == 'lost pet') return Colors.redAccent;
    if (t == 'report') return Colors.orangeAccent;
    if (t == 'found pet') return Colors.green;
    if (t == 'adoption') return Colors.deepPurpleAccent;
    if (t == 'discussion') return Colors.blueAccent;
    return theme.colorScheme.onSurface;
  }

  Color _getBgColor(String type, ThemeData theme) {
    final t = type.toLowerCase();
    final isDark = theme.brightness == Brightness.dark;

    if (t == 'lost pet') return Colors.redAccent.withValues(alpha: 0.12);
    if (t == 'report') return Colors.orangeAccent.withValues(alpha: 0.12);
    if (t == 'found pet') return Colors.green.withValues(alpha: 0.12);
    if (t == 'adoption') return Colors.deepPurpleAccent.withValues(alpha: 0.12);
    if (t == 'discussion') return Colors.blueAccent.withValues(alpha: 0.12);

    return isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _getBgColor(label, theme),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _getTextColor(label, theme),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RoundCardAction extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _RoundCardAction({required this.icon, this.iconColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor ?? theme.colorScheme.onSurface,
            size: 19,
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : const Color(0xFFEDEFF1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}