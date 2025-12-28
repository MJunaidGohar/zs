import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'avatar_selection_screen.dart';
import '../widgets/top_bar_scaffold.dart';
import '../providers/user_provider.dart';
import 'main_selection_screen.dart';

/// Main onboarding screen where user enters their name
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedAvatar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
  }

  /// Load saved avatar and user name from provider
  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() {
      _nameController.text = userProvider.userName ?? '';
      _selectedAvatar = userProvider.selectedAvatar;
    });
  }

  /// Save user name and navigate to MainSelectionScreen
  Future<void> _saveNameAndProceed() async {
    String name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.setUserName(name);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainSelectionScreen()),
    );
  }

  /// Open Avatar Selection Screen
  Future<void> _chooseAvatar() async {
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AvatarSelectionScreen()),
    );

    if (selected != null && mounted) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.setAvatar(selected);
      setState(() => _selectedAvatar = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TopBarScaffold(
      title: "Zaroi Sawal",
      leadingWidget: GestureDetector(
        onTap: _chooseAvatar,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green, width: 3),
          ),
          child: ClipOval(
            child: _selectedAvatar != null
                ? Image.asset(_selectedAvatar!, fit: BoxFit.cover)
                : const Icon(Icons.person, color: Colors.white, size: 32),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter your cute name',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),

            // Name input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter here...',
              ),
            ),
            const SizedBox(height: 20),

            // Next button
            ElevatedButton(
              onPressed: _saveNameAndProceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Done'),
            ),
            const SizedBox(height: 40),

            const SizedBox(height: 40),

            // Footer
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontSize: 12, color: Colors.grey),
                children: [
                  TextSpan(text: '© '),
                  TextSpan(
                      text: "J_studio",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: " developed by "),
                  TextSpan(
                      text: "M. Junaid Gohar",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            /*RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style : TextStyle(fontSize:12, color: Colors.grey),
                    children: [
                  TextSpan (text: 'With the collaboration of '),
                  TextSpan(
                  text: "Spring Field Public School",
                  style: TextStyle(fontWeight: FontWeight.bold)),

                  ],
              )

            )*/
          ],
        ),
      ),
    );
  }
}
