import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pawnder_app/models/community.dart';
import 'package:pawnder_app/screens/home/listing_screen.dart';
import 'package:pawnder_app/services/api_client.dart';
import 'package:pawnder_app/services/community_service.dart';
import 'package:pawnder_app/services/location_service.dart';
import 'package:pawnder_app/services/upload_service.dart';
import 'package:pawnder_app/widgets/build_header.dart';
import 'package:pawnder_app/widgets/image_picker_card.dart';
import 'package:pawnder_app/widgets/input_card.dart';

class CreateCommunityScreen extends StatefulWidget {
  final String authorId;

  const CreateCommunityScreen({super.key, required this.authorId});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _communityService = CommunityService();
  final _locationService = LocationService();
  final _uploadService = UploadService();
  final _apiClient = ApiClient();

  bool _isSubmitting = false;
  Community? _createdCommunity;

  Uint8List? _imageBytes;
  String? _imageContentType;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createCommunity() async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty || description.isEmpty || _imageBytes == null) {
      String errorMessage = 'Community name and description are required.';
      if (_imageBytes == null) {
        errorMessage = 'A community banner image is required.';
      }
      _showMessage(errorMessage);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final location = await _locationService.requestAndSaveCurrentLocation();
      if (location == null) {
        throw Exception(
          'Enable location access to create a community near you.',
        );
      }

      String? bannerImageUrl;
      if (_imageBytes != null && _imageContentType != null) {
        try {
          bannerImageUrl = await _uploadService.uploadImage(
            bytes: _imageBytes!,
            contentType: _imageContentType!,
            purpose: UploadPurpose.community,
          );
        } catch (error) {
          if (!mounted) return;
          _showMessage(_apiClient.messageForError(error));
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final community = await _communityService.createNeighborhood(
        CreateCommunityRequest(
          name: name,
          description: description,
          latitude: location.latitude,
          longitude: location.longitude,
          imageUrl: bannerImageUrl,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() => _createdCommunity = community);
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message =
          error is Exception &&
                  error.toString().contains('Enable location access')
              ? 'Enable location access to create a community near you.'
              : _apiClient.messageForError(error);
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openListingForCommunity() async {
    final community = _createdCommunity;
    if (community == null) {
      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ListingScreen(authorId: widget.authorId, communityId: community.id),
      ),
    );

    if (!mounted) {
      return;
    }

    Navigator.pop(context, community);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 32,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              const HomeHeader(
                title: 'CREATE COMMUNITY',
                subtitle: 'Start a neighborhood group before posting alerts',
                fallbackIcon: Icons.add_location_alt_outlined,
              ),
              const SizedBox(height: 28),
              if (_createdCommunity == null) ...[
                InputCard(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Community name',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
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
                    decoration: const InputDecoration(
                      hintText: 'Describe this community',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ImagePickerCard(
                  bytes: _imageBytes,
                  contentType: _imageContentType,
                  emptyTitle: 'Add banner',
                  emptySubtitle: 'Tap to upload a community photo (Required)',
                  previewHeight: 180,
                  onPicked: (bytes, contentType) {
                    setState(() {
                      _imageBytes = bytes;
                      _imageContentType = contentType;
                    });
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _createCommunity,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text(
                            'Create community',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _createdCommunity!.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _createdCommunity!.description,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _openListingForCommunity,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Create a First Post!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, _createdCommunity),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}