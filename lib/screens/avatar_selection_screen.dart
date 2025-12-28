import 'package:flutter/material.dart';
import '../widgets/top_bar_scaffold.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

/// ------------------------------------------------------------
/// Avatar Selection Screen
/// ------------------------------------------------------------
/// Lets user pick an avatar from available options.
/// Saves selection via [UserProvider] (which also updates
/// SharedPreferences), and closes the screen.
/// ------------------------------------------------------------
class AvatarSelectionScreen extends StatelessWidget {
  const AvatarSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    /// ---------------------- Available Avatars ----------------------
    final avatars = [
      'assets/avatar/boy_avatar.png',
      'assets/avatar/girl_avatar.png',
    ];

    final theme = Theme.of(context);

    return TopBarScaffold(
      title: "Select Your Avatar",
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: avatars.map((avatarPath) {
            return GestureDetector(
              onTap: () async {
                /// ✅ Save selected avatar using provider
                final userProvider =
                Provider.of<UserProvider>(context, listen: false);
                await userProvider.setAvatar(avatarPath);

                /// ✅ Close screen (no need to return anything)
                Navigator.pop(context);
              },

              /// Avatar UI container
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  /// Theme-based border
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 4,
                  ),

                  /// Subtle shadow for depth
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ],

                  /// Avatar image
                  image: DecorationImage(
                    image: AssetImage(avatarPath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
