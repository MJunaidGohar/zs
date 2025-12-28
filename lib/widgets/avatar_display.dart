import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

/// ------------------------------------------------------------
/// AvatarDisplay Widget
/// ------------------------------------------------------------
/// Reads avatar from UserProvider (not SharedPreferences).
/// If no avatar is selected, shows a default person icon.
/// ------------------------------------------------------------
class AvatarDisplay extends StatelessWidget {
  /// Size of the avatar (width/height)
  final double size;

  const AvatarDisplay({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final avatarPath = userProvider.selectedAvatar;

    return GestureDetector(
      onTap: () async {
        // Navigate to AvatarSelectionScreen
        final result = await Navigator.pushNamed(context, '/avatarSelection');

        // If a new avatar is returned → update provider
        if (result != null && result is String) {
          await userProvider.setAvatar(result);
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        /// Circle Avatar inside decorated container
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.grey[300],

          /// ✅ If avatar exists → show it from File
          backgroundImage: (avatarPath != null && avatarPath.isNotEmpty)
              ? FileImage(File(avatarPath))
              : null,

          /// ✅ Otherwise fallback to person icon
          child: (avatarPath == null || avatarPath.isEmpty)
              ? Icon(
                  Icons.person,
                  size: size / 2,
                  color: Colors.grey,
                )
              : null,
        ),
      ),
    );
  }
}
