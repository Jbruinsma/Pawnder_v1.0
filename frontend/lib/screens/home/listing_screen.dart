import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pawnder_app/models/community.dart';
import 'package:pawnder_app/models/community_post.dart';
import 'package:pawnder_app/services/api_client.dart';
import 'package:pawnder_app/services/location_service.dart';
import 'package:pawnder_app/services/post_service.dart';
import 'package:pawnder_app/services/upload_service.dart';
import 'package:pawnder_app/theme.dart';
import 'package:pawnder_app/widgets/build_header.dart';
import 'package:pawnder_app/widgets/image_picker_card.dart';
import 'package:pawnder_app/widgets/input_card.dart';
import 'package:pawnder_app/widgets/search_bar.dart';

class ListingScreen extends StatefulWidget {
  final String? authorId;
  final String? communityId;
  final String? initialCommunityId;
  final List<Community> communities;
  final Map<String, String>? existingPost;

  const ListingScreen({
    super.key,
    this.authorId,
    this.communityId,
    this.initialCommunityId,
    this.communities = const [],
    this.existingPost,
  });

  @override
  State<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends State<ListingScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagSearchController = TextEditingController();
  final _postService = PostService();
  final _apiClient = ApiClient();
  final _locationService = LocationService();
  final _uploadService = UploadService();

  final List<String> _selectedTags = [];
  List<dynamic> _searchResults = [];
  Timer? _debounce;
  bool _isSearching = false;
  Uint8List? _imageBytes;
  String? _imageContentType;
  bool _isSubmitting = false;
  String? _selectedCommunityId;
  String? _selectedPostType;

  static const _defaultLatitude = 40.7128;
  static const _defaultLongitude = -74.0060;

  final List<String> _postTypes = [
    'Lost Pet',
    'Found Pet',
    'Adoption',
    'Photos',
    'Discussion',
    'Report',
  ];

  bool get _shouldShowCommunityPicker =>
      widget.communityId == null && widget.communities.isNotEmpty && widget.existingPost == null;

  bool get _hasChanges {
    if (widget.existingPost == null) return true;

    final currentTitle = _titleController.text.trim();
    final originalTitle = widget.existingPost!['title'] ?? '';
    if (currentTitle != originalTitle) return true;

    final currentDesc = _descriptionController.text.trim();
    final originalDesc = widget.existingPost!['description'] ?? '';
    if (currentDesc != originalDesc) return true;

    final originalType = widget.existingPost!['postType'];
    if (_selectedPostType != originalType) return true;

    final originalCommunity = widget.existingPost!['communityId'];
    if (_selectedCommunityId != originalCommunity) return true;

    final originalTags = (widget.existingPost!['tags'] ?? '').split('|').where((t) => t.isNotEmpty).toList();
    if (_selectedTags.length != originalTags.length) return true;
    for (final tag in _selectedTags) {
      if (!originalTags.contains(tag)) return true;
    }

    if (_imageBytes != null) return true;

    return false;
  }

  @override
  void initState() {
    super.initState();

    if (widget.existingPost != null) {
      _titleController.text = widget.existingPost!['title'] ?? '';
      _descriptionController.text = widget.existingPost!['description'] ?? '';
      _selectedPostType = widget.existingPost!['postType'];

      final tags = (widget.existingPost!['tags'] ?? '').split('|').where((t) => t.isNotEmpty);
      _selectedTags.addAll(tags);

      _selectedCommunityId = widget.existingPost!['communityId'];
    } else {
      _selectedCommunityId =
          widget.communityId ??
          widget.initialCommunityId ??
          (widget.communities.isNotEmpty ? widget.communities.first.id : null);
    }

    _titleController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (widget.existingPost != null) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _tagSearchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      try {
        final response = await _apiClient.get('/tags', queryParameters: {'q': query});
        if (mounted) {
          setState(() {
            _searchResults = response.data as List<dynamic>;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _addTag(String tag) {
    if (_selectedTags.length >= 5) {
      _showMessage('Maximum of 5 tags allowed.');
      return;
    }

    if (!_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _tagSearchController.clear();
        _searchResults = [];
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _selectedTags.remove(tag));
  }

  Future<void> _submitListing() async {
    FocusScope.of(context).unfocus();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final isEditing = widget.existingPost != null;

    if (title.isEmpty || description.isEmpty) {
      _showMessage('Title and description are required.');
      return;
    }

    if (_selectedPostType == null) {
      _showMessage('Please select a post type.');
      return;
    }

    if (_selectedTags.isEmpty) {
      _showMessage('Choose at least one tag.');
      return;
    }

    final authorId = widget.authorId ?? widget.existingPost?['authorId'];
    final communityId = widget.communityId ?? _selectedCommunityId;

    if (authorId == null || communityId == null) {
      _showMessage('Choose a community before posting.');
      return;
    }

    setState(() => _isSubmitting = true);

    PostLocation location = const PostLocation(latitude: _defaultLatitude, longitude: _defaultLongitude);
    try {
      final current = await _locationService.requestAndSaveCurrentLocation();
      if (current != null) location = current;
    } catch (_) {}

    String? imageUrl = widget.existingPost?['image'];
    if (_imageBytes != null && _imageContentType != null) {
      try {
        imageUrl = await _uploadService.uploadImage(
          bytes: _imageBytes!,
          contentType: _imageContentType!,
          purpose: UploadPurpose.post,
        );
      } catch (error) {
        if (!mounted) return;
        _showMessage(_apiClient.messageForError(error));
        setState(() => _isSubmitting = false);
        return;
      }
    }

    final request = CreatePostRequest(
      communityId: communityId,
      authorId: authorId,
      postType: _selectedPostType!,
      title: title,
      description: description,
      location: location,
      tags: _selectedTags,
      imageUrl: imageUrl,
    );

    try {
      if (isEditing) {
        final updatedPost = await _postService.updatePost(
          postId: widget.existingPost!['id']!,
          request: request,
        );
        if (!mounted) return;
        _showMessage('Post updated.');
        Navigator.pop(context, updatedPost.toFeedMap());
      } else {
        await _postService.createPost(request);
        if (!mounted) return;
        _showMessage('Post created.');
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) _showMessage(_apiClient.messageForError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.existingPost != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.backgroundDecoration(context),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 32, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 18),
                HomeHeader(
                  title: isEditing ? 'EDIT POST' : 'CREATE POST',
                  subtitle: isEditing ? 'Update your neighborhood alert' : 'Share a quick alert with your neighborhood',
                  fallbackIcon: isEditing ? Icons.edit_note_rounded : Icons.add_location_alt_outlined,
                ),
                const SizedBox(height: 28),

                if (_shouldShowCommunityPicker) ...[
                  InputCard(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCommunityId,
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.darkSurface : theme.cardColor,
                      decoration: const InputDecoration(
                        labelText: 'Post in community',
                        border: InputBorder.none,
                      ),
                      items: widget.communities
                          .map(
                            (community) => DropdownMenuItem<String>(
                              value: community.id,
                              child: Text(
                                community.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCommunityId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                InputCard(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPostType,
                    isExpanded: true,
                    dropdownColor: isDark ? AppColors.darkSurface : theme.cardColor,
                    decoration: const InputDecoration(
                      labelText: 'Post Type',
                      border: InputBorder.none,
                    ),
                    items: _postTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPostType = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 18),

                InputCard(
                  child: TextField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 18),
                InputCard(
                  minHeight: 148,
                  child: TextField(
                    controller: _descriptionController,
                    maxLines: 6,
                    minLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Add a description', border: InputBorder.none),
                    style: TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 26),

                Center(
                  child: Text(
                    'ADD TAGS',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 14),
                GlassmorphicSearchBar(
                  controller: _tagSearchController,
                  isLoading: _isSearching,
                  hintText: _selectedTags.length >= 5 ? 'Limit reached' : 'Search or create a tag...',
                  onChanged: _selectedTags.length >= 5 ? (_) {} : _onSearchChanged,
                ),
                const SizedBox(height: 12),

                if (_searchResults.isNotEmpty || (_tagSearchController.text.isNotEmpty && !_isSearching))
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (_tagSearchController.text.isNotEmpty &&
                            !_searchResults.any((t) => t['name'].toString().toLowerCase() == _tagSearchController.text.toLowerCase()))
                          _buildSearchChip("Add '${_tagSearchController.text}'", theme, isDark, () => _addTag(_tagSearchController.text), isAction: true),

                        ..._searchResults.map((tag) => _buildSearchChip(tag['name'], theme, isDark, () => _addTag(tag['name']))),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedTags.map((tag) => _buildTagChip(tag, theme, isDark)).toList(),
                ),

                const SizedBox(height: 28),
                ImagePickerCard(
                  bytes: _imageBytes,
                  contentType: _imageContentType,
                  emptyTitle: isEditing && (widget.existingPost?['image']?.isNotEmpty ?? false) ? 'Replace photo' : 'Add photo',
                  onPicked: (bytes, contentType) => setState(() { _imageBytes = bytes; _imageContentType = contentType; }),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: (_isSubmitting || !_hasChanges) ? null : _submitListing,
                    child: _isSubmitting
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            isEditing ? 'Update Post' : 'Upload Post',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchChip(String label, ThemeData theme, bool isDark, VoidCallback onTap, {bool isAction = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: isAction ? theme.colorScheme.primaryContainer : (isDark ? Colors.white10 : Colors.black12),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  Widget _buildTagChip(String tag, ThemeData theme, bool isDark) {
    return InkWell(
      onTap: () => _removeTag(tag),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tag, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.colorScheme.onPrimary)),
            const SizedBox(width: 6),
            Icon(Icons.close_rounded, size: 16, color: theme.colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }
}