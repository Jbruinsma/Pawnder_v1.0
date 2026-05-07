import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pawnder_app/models/community.dart';
import 'package:pawnder_app/screens/home/search_results.dart';
import 'package:pawnder_app/widgets/build_header.dart';
import 'package:pawnder_app/widgets/community_card.dart';
import 'package:pawnder_app/widgets/search_bar.dart';
import 'package:pawnder_app/widgets/search_status.dart';

class CommunityScreen extends StatefulWidget {
  final List<Community> communities;
  final bool isLoading;
  final ValueChanged<Community> onCommunityTap;
  final VoidCallback onCreateCommunityTap;
  final VoidCallback onCreatePostTap;
  final Future<void> Function() onRefresh;
  final String? selectedCommunityName;

  const CommunityScreen({
    super.key,
    required this.communities,
    this.isLoading = false,
    required this.onCommunityTap,
    required this.onCreateCommunityTap,
    required this.onCreatePostTap,
    required this.onRefresh,
    this.selectedCommunityName,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _isCreateMenuExpanded = false;

  void _handleNewCommunityTap() {
    setState(() => _isCreateMenuExpanded = false);
    widget.onCreateCommunityTap();
  }

  void _handleNewPostTap() {
    setState(() => _isCreateMenuExpanded = false);
    widget.onCreatePostTap();
  }

  void _toggleCreateMenu() {
    setState(() {
      _isCreateMenuExpanded = !_isCreateMenuExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeHeader(
            fallbackIcon: Icons.travel_explore_rounded,
            subtitle: 'Neighborhood groups and pet alerts',
            title: 'Communities',
          ),
          const SizedBox(height: 18),
          GlassmorphicSearchBar(
            hintText: 'Search communities...',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SearchResultsPage(
                    isCommunitiesOnly: true,
                  ),
                ),
              );
            },
            readOnly: true,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              color: theme.colorScheme.primary,
              onRefresh: widget.onRefresh,
              child: _buildBody(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: !_isCreateMenuExpanded
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            key: const ValueKey('community-create-menu'),
                            children: [
                              FilledButton.icon(
                                icon: const Icon(Icons.post_add_rounded),
                                label: const Text(
                                  'NEW POST',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                onPressed: _handleNewPostTap,
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  elevation: theme.brightness == Brightness.dark ? 0 : 2,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  shadowColor: const Color(0x18000000),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 8,
                                    sigmaY: 8,
                                  ),
                                  child: FilledButton.tonalIcon(
                                    icon: const Icon(Icons.group_add_rounded),
                                    label: const Text(
                                      'NEW COMMUNITY',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    onPressed: _handleNewCommunityTap,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.black.withValues(alpha: 0.05),
                                      foregroundColor: theme.colorScheme.onSurface,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                  ),
                  IconButton.filled(
                    icon: Icon(
                      _isCreateMenuExpanded ? Icons.close_rounded : Icons.add_rounded,
                      size: 26,
                    ),
                    onPressed: _toggleCreateMenu,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      elevation: theme.brightness == Brightness.dark ? 0 : 2,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.all(14),
                      shadowColor: const Color(0x18000000),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (widget.communities.isEmpty) {
      return _buildScrollableStatus(
        SearchStatus(
          icon: widget.isLoading ? Icons.travel_explore_rounded : Icons.groups_outlined,
          title: widget.isLoading
              ? 'Loading nearby neighborhoods...'
              : 'No neighborhoods are available yet.',
        ),
      );
    }

    return ListView.separated(
      itemBuilder: (context, index) {
        final community = widget.communities[index];
        return CommunityCard(
          community: community,
          isSelected: community.name == widget.selectedCommunityName,
          onTap: () => widget.onCommunityTap(community),
        );
      },
      itemCount: widget.communities.length,
      padding: const EdgeInsets.only(bottom: 148),
      physics: const AlwaysScrollableScrollPhysics(),
      separatorBuilder: (context, index) => const SizedBox(height: 14),
    );
  }

  Widget _buildScrollableStatus(Widget status) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: status),
          ),
        );
      },
    );
  }
}