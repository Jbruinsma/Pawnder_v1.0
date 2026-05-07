import 'package:flutter/material.dart';
import 'package:pawnder_app/models/current_user.dart';
import 'package:pawnder_app/screens/auth/login_screen.dart';
import 'package:pawnder_app/screens/home/user_posts_screen.dart';
import 'package:pawnder_app/services/auth_service.dart';
import 'package:pawnder_app/services/post_service.dart';
import 'package:pawnder_app/services/profile_photo_service.dart';
import 'package:pawnder_app/theme.dart';
import 'package:pawnder_app/widgets/build_header.dart';
import 'package:pawnder_app/widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _postService = PostService();
  final _profilePhotoService = ProfilePhotoService();
  CurrentUser? _currentUser;
  String? _profilePhotoPath;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = await _authService.getCurrentUser();
      final savedPhotoPath = await _profilePhotoService.getPhotoPath(user.id);
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _profilePhotoPath = savedPhotoPath;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _authService.messageForError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = _currentUser;
    final displayName = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName
        : 'Account';
    final joinedLabel = user == null
        ? ''
        : 'Joined ${user.createdAt.month}/${user.createdAt.day}/${user.createdAt.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HomeHeader(
            title: 'Account Center',
            subtitle: 'Profile, listings, and contact details',
            fallbackIcon: Icons.account_circle_outlined,
          ),
          const SizedBox(height: 18),
          Container(height: 2, color: theme.dividerColor),
          if (_isLoading) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _ProfileNotice(message: _errorMessage!, onRetry: _loadCurrentUser),
          ],
          const SizedBox(height: 16),
          _ThemeToggleTile(isDark: isDark),
          const SizedBox(height: 28),
          _ProfilePhotoDisplay(
            photoPath: _profilePhotoPath,
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              displayName.toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (user != null) ...[
            const SizedBox(height: 6),
            Text(
              user.role,
              style: TextStyle(
                color: isDark ? AppColors.darkMuted : const Color(0xFF27313A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              joinedLabel,
              style: TextStyle(
                color: isDark ? AppColors.darkMuted : AppColors.bodyText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _MenuTile(
            label: 'MY POSTS',
            icon: Icons.list_alt_rounded,
            onTap: user == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserPostsScreen(
                          title: 'My Posts',
                          subtitle: 'Posts you\'ve created',
                          fallbackIcon: Icons.list_alt_rounded,
                          loadPosts: () =>
                              _postService.getUserPosts(userId: user.id),
                        ),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 10),
          _MenuTile(
            label: 'BOOKMARKS',
            icon: Icons.bookmark_outline_rounded,
            onTap: user == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserPostsScreen(
                          title: 'Bookmarks',
                          subtitle: 'Posts you\'ve saved',
                          fallbackIcon: Icons.bookmark_outline_rounded,
                          loadPosts: () =>
                              _postService.getUserBookmarks(userId: user.id),
                        ),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 10),
          _AccountDetailsCard(email: user?.email),
          const SizedBox(height: 24),
          _MenuTile(
            label: 'LOG OUT',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

class _ProfileNotice extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileNotice({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _AccountDetailsCard extends StatelessWidget {
  final String? email;

  const _AccountDetailsCard({required this.email});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACCOUNT DETAILS',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          _AccountDetailRow(
            label: 'Email',
            value: email?.trim().isNotEmpty == true ? email! : 'Not available',
          ),
          const SizedBox(height: 12),
          _AccountDetailRow(label: 'Password', value: '••••••••'),
        ],
      ),
    );
  }
}

class _AccountDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _AccountDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfilePhotoDisplay extends StatelessWidget {
  final String? photoPath;

  const _ProfilePhotoDisplay({
    this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: theme.cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: theme.dividerColor, width: 2),
      ),
      child: ClipOval(
        child: UserAvatar(
          imagePath: photoPath,
          size: 96,
          backgroundColor: theme.cardColor,
          iconColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const _MenuTile({required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: theme.colorScheme.onSurface, size: 22),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggleTile extends StatelessWidget {
  final bool isDark;

  const _ThemeToggleTile({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dark mode',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  isDark ? 'Deep night theme enabled' : 'Soft daylight theme',
                  style: TextStyle(
                    color: isDark ? AppColors.darkMuted : AppColors.bodyText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isDark,
            activeThumbColor: theme.colorScheme.primary,
            onChanged: AppThemeController.setDarkMode,
          ),
        ],
      ),
    );
  }
}