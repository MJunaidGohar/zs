import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

// Services
import 'services/hive_service.dart';
import 'services/question_service.dart';
import 'services/notification_service.dart';

// Providers
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';

// Screens
import 'screens/onboarding_screen.dart';
import 'screens/main_selection_screen.dart';
import 'screens/avatar_selection_screen.dart';
import 'screens/profile_screen.dart';

//Goole Admob
import 'package:google_mobile_ads/google_mobile_ads.dart'; // 🔹 Admob

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  await HiveService.init(); // register adapters & open boxes

  // 🔹 Added: Version check to add new Hive data on app update
  const int currentAppVersion = 5; // increment this on every new release
  var settingsBox = await Hive.openBox('settings');
  int savedVersion = settingsBox.get('app_version', defaultValue: 0);

  if (savedVersion < currentAppVersion) {
    // Add new Hive data here
    final questionService = QuestionService();
    await questionService.addNewQuestions(); // implement this in QuestionService

    // Update saved version
    await settingsBox.put('app_version', currentAppVersion);
  }

  // Notifications (must run after Hive is ready)
  await NotificationService.init();

  // Seed default questions if empty
  final questionService = QuestionService();
  await questionService.seedQuestions();
  final allQuestions = await questionService.getQuestions();
  if (allQuestions.isEmpty) {
    // Optionally handle when no questions exist
  }

  // Initialize UserProvider and ThemeProvider
  final userProvider = UserProvider();
  await userProvider.loadUserData();
  final themeProvider = ThemeProvider();

  // For Admob
  WidgetsFlutterBinding.ensureInitialized(); // 🔹 Required before async calls
  await MobileAds.instance.initialize(); // 🔹 Initialize AdMob SDK

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => userProvider),
        ChangeNotifierProvider(create: (_) => themeProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    // Show loading while UserProvider is initializing
    if (userProvider.isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Decide start screen
    final Widget startScreen =
    (userProvider.userName == null || userProvider.userName!.isEmpty)
        ? const OnboardingScreen()
        : const MainSelectionScreen();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zarori Sawal',

      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo.shade500,
          foregroundColor: Colors.white,
          elevation: 3,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ),
      ),

      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.black87,
        ),
      ),

      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/mainSelection': (_) => const MainSelectionScreen(),
        '/avatarSelection': (_) => const AvatarSelectionScreen(),
        '/profile': (_) => const ProfileScreen(),
      },

      home: startScreen,
    );
  }
}
