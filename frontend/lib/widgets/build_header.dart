import 'package:flutter/material.dart';
import 'package:pawnder_app/theme.dart';

Widget buildHeader() {
  return const HomeHeader(
    title: 'PAWNDER',
    subtitle: 'Nearby pets and community alerts',
    leadingAsset: 'assets/images/app_icon.png',
  );
}

class HomeHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? leadingAsset;
  final IconData? fallbackIcon;
  final Widget? trailing;

  const HomeHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingAsset,
    this.fallbackIcon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leadingAsset != null || fallbackIcon != null) ...[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: leadingAsset != null
                  ? Image.asset(
                      leadingAsset!,
                      fit: BoxFit.cover,
                    )
                  : Icon(fallbackIcon, color: theme.colorScheme.onSurface, size: 19),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: AppTextStyles.screenTitle(context).copyWith(
                    fontSize: 21,
                    height: 1.02,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.screenSubtitle(context).copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}