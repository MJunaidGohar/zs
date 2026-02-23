import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/profile_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),

        /// Gradient Background with enhanced colors
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF667EEA),
                      const Color(0xFF764BA2),
                    ]
                  : [
                      const Color(0xFF4FACFE),
                      const Color(0xFF00F2FE),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        elevation: 8,
        shadowColor: isDark ? Colors.purple.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),

        /// Leading Avatar with glow effect
        leading: leadingWidget ??
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: userProvider.selectedAvatar != null
                  ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isDark 
                          ? Colors.purpleAccent.withValues(alpha: 0.6)
                          : Colors.blueAccent.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.8),
                      width: 2.5),
                ),
                child: ClipOval(
                  child: Image.asset(
                    userProvider.selectedAvatar!,
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: Icon(Icons.account_circle_outlined,
                          color: Colors.white.withValues(alpha: 0.9), size: 32),
                    ),
            ),

        actions: [
          /// Theme toggle with animated icon
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  themeProvider.isDarkMode
                      ? Icons.wb_sunny_rounded
                      : Icons.nights_stay_rounded,
                  key: ValueKey(themeProvider.isDarkMode),
                  color: themeProvider.isDarkMode
                      ? Colors.orange.shade300
                      : Colors.indigo.shade300,
                ),
              ),
              tooltip: themeProvider.isDarkMode
                  ? "Switch to Light Mode"
                  : "Switch to Dark Mode",
              onPressed: () => themeProvider.toggleTheme(),
            ),
          ),

          /// Popup Menu with glassmorphism
          Container(
            margin: const EdgeInsets.only(right: 12, left: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: isDark 
                  ? const Color(0xFF2D2D3A).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              onSelected: (value) {
                if (value == 'avatar') {
                  Navigator.pushNamed(context, '/avatarSelection');
                } else if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen()),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'avatar',
                  child: Row(
                    children: [
                      Icon(Icons.face, size: 20, 
                          color: isDark ? Colors.purpleAccent : Colors.blueAccent),
                      const SizedBox(width: 12),
                      Text("Change Avatar",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 20,
                          color: isDark ? Colors.purpleAccent : Colors.blueAccent),
                      const SizedBox(width: 12),
                      Text("Profile",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          )),
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
}
