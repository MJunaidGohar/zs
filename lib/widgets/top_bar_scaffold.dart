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
    final userProvider = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
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

        /// Gradient Background
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.deepPurple.shade700, Colors.indigo.shade900]
                  : [Colors.blue.shade600, Colors.indigo.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        elevation: 6,
        shadowColor: Colors.black38,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),

        /// Leading Avatar
        leading: leadingWidget ??
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: userProvider.selectedAvatar != null
                  ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.6),
                      blurRadius: 6,
                      spreadRadius: 1.5,
                    ),
                  ],
                  border: Border.all(
                      color: isDark
                          ? Colors.white30
                          : Colors.grey.shade200,
                      width: 2),
                ),
                child: ClipOval(
                  child: Image.asset(
                    userProvider.selectedAvatar!,
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  : Icon(Icons.account_circle_outlined,
                  color: Colors.white, size: 30),
            ),

        actions: [
          /// Theme toggle
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode
                  ? Icons.wb_sunny
                  : Icons.nights_stay,
              color: Colors.yellow.shade200,
            ),
            tooltip: themeProvider.isDarkMode
                ? "Switch to Light Mode"
                : "Switch to Dark Mode",
            onPressed: () => themeProvider.toggleTheme(),
          ),

          /// Popup Menu
          PopupMenuButton<String>(
            color: theme.cardColor.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                    Icon(Icons.face, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text("Change Avatar"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text("Profile"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
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
