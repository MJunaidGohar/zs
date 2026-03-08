import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/profile_screen.dart';
import '../screens/notes_list_screen.dart';
import '../screens/tools_screen.dart';
import '../services/avatar_image_service.dart';
import '../utils/app_theme.dart';

/// TopBarScaffold - Universal app bar with professional Royal Blue styling
/// Provides consistent header across all screens with avatar, theme toggle, and menu
class TopBarScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? leadingWidget;

  const TopBarScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),

        /// Professional Royal Blue gradient background
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.gradientHeader,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppBorderRadius.lg),
          ),
        ),

        /// Leading Avatar - Clean and professional (Now Clickable!)
        leading: leadingWidget ??
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.pushNamed(context, '/avatarSelection');
                  // If a new avatar is returned, update the provider
                  if (result != null && result is String && context.mounted) {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    await userProvider.setAvatar(result);
                  }
                },
                child: userProvider.selectedAvatar != null
                    ? Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: _buildAvatarImage(userProvider.selectedAvatar!),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: Icon(
                          Icons.account_circle_outlined,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 32,
                        ),
                      ),
              ),
            ),

        actions: [
          /// User Profile button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.person,
                color: Colors.white,
              ),
              tooltip: l10n.myProfile,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen()),
                );
              },
            ),
          ),

          /// Theme toggle button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: IconButton(
              icon: Icon(
                themeProvider.isDarkMode
                    ? Icons.wb_sunny_rounded
                    : Icons.nights_stay_rounded,
                color: Colors.white,
              ),
              tooltip: themeProvider.isDarkMode
                  ? AppLocalizations.of(context).switchToLightMode
                  : AppLocalizations.of(context).switchToDarkMode,
              onPressed: () => themeProvider.toggleTheme(),
            ),
          ),

          /// Popup Menu
          Container(
            margin: const EdgeInsets.only(right: 12, left: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
              elevation: 2,
              onSelected: (value) {
                if (value == 'avatar') {
                  Navigator.pushNamed(context, '/avatarSelection');
                } else if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen()),
                  );
                } else if (value == 'notes') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotesListScreen()),
                  );
                } else if (value == 'tools') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ToolsScreen()),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'tools',
                  child: Row(
                    children: [
                      Icon(
                        Icons.construction,
                        size: 20,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.tools,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'notes',
                  child: Row(
                    children: [
                      Icon(
                        Icons.note_alt,
                        size: 20,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.notes,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'avatar',
                  child: Row(
                    children: [
                      Icon(
                        Icons.face,
                        size: 20,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.changeAvatar,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 20,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.myProfile,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      /// Body
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: body,
      ),
    );
  }

  /// Build avatar image widget - handles both assets and file paths
  Widget _buildAvatarImage(String avatarPath) {
    if (AvatarImageService.isCustomAvatar(avatarPath)) {
      // Custom photo from file
      return Image.file(
        File(avatarPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey[600]),
          );
        },
      );
    } else {
      // Asset image
      return Image.asset(
        avatarPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey[600]),
          );
        },
      );
    }
  }
}
