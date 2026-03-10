import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
// import 'package:google_fonts/google_fonts.dart';  // DISABLED - Using local font instead
import 'dart:io';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Localization
import 'l10n/app_localizations.dart';

// Services
import 'services/hive_service.dart';
import 'services/question_service.dart';
import 'services/notification_service.dart';
import 'services/floating_button_service.dart';
import 'services/chat_quota_service.dart';
import 'services/admob_service.dart';
import 'services/notes_service.dart';

// Providers
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/language_provider.dart';

// Screens
import 'screens/onboarding_screen.dart';
import 'screens/main_selection_screen.dart';
import 'screens/avatar_selection_screen.dart';
import 'screens/profile_screen.dart';

// Widgets
import 'widgets/animated_splash_screen.dart';

// Theme
import 'utils/app_theme.dart';

// Chat Widgets
import 'widgets/global_chat_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait orientation by default
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Hive
  await Hive.initFlutter();
  await HiveService.init();

  // Version check for app updates
  const int currentAppVersion = 5;
  final settingsBox = HiveService.settingsBox;
  final int savedVersion = settingsBox.get('app_version', defaultValue: 0) as int;

  if (savedVersion < currentAppVersion) {
    final questionService = QuestionService();
    await questionService.addNewQuestions();
    await settingsBox.put('app_version', currentAppVersion);
  }

  // Notifications
  await NotificationService.init();

  // Seed default questions
  final questionService = QuestionService();
  await questionService.seedQuestions();

  // Initialize chat services
  final floatingButtonService = FloatingButtonService();
  await floatingButtonService.init();
  
  final chatQuotaService = ChatQuotaService();
  await chatQuotaService.init();

  // Initialize Notes service
  await NotesService.init();
  
  // Initialize Providers
  final userProvider = UserProvider();
  await userProvider.loadUserData();
  final themeProvider = ThemeProvider();
  final chatProvider = ChatProvider();
  await chatProvider.init();
  final languageProvider = LanguageProvider();
  await Future.delayed(Duration.zero); // Allow language provider to initialize

  // AdMob - uses platform-aware service
  await AdMobService.initialize();

  runApp(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => userProvider),
          ChangeNotifierProvider(create: (_) => themeProvider),
          ChangeNotifierProvider(create: (_) => chatProvider),
          ChangeNotifierProvider(create: (_) => languageProvider),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    // Loading state - show animated splash screen
    if (userProvider.isLoading || languageProvider.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(context),
        darkTheme: _buildDarkTheme(context),
        themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AnimatedSplashScreen(),
      );
    }

    // Determine start screen route
    final String initialRoute =
        (userProvider.userName == null || userProvider.userName!.isEmpty)
            ? '/onboarding'
            : '/mainSelection';

    // Route observer for hiding chat button on certain screens
    final showButtonNotifier = ValueNotifier<bool>(initialRoute != '/onboarding');
    final chatButtonObserver = ChatButtonRouteObserver(
      showButtonNotifier: showButtonNotifier,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zarori Sawal',
      theme: _buildLightTheme(context),
      darkTheme: _buildDarkTheme(context),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: languageProvider.locale,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [chatButtonObserver],
      initialRoute: initialRoute,
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/mainSelection': (_) => const MainSelectionScreen(),
        '/avatarSelection': (_) => const AvatarSelectionScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
      builder: (context, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => GlobalChatOverlay(
                  showButtonNotifier: showButtonNotifier,
                  child: child!,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build Light Theme with optional Urdu font support
  ThemeData _buildLightTheme(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isUrdu = languageProvider.currentLanguageCode == 'ur';
    
    // Use Noto Nastaliq Urdu for Urdu language, default font otherwise
    final textTheme = isUrdu
        ? _buildUrduTextTheme(ThemeData.light().textTheme)
        : const TextTheme(
            displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight, letterSpacing: -0.5),
            displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight, letterSpacing: -0.5),
            displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight, letterSpacing: -0.25),
            headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
            headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
            headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
            titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
            titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
            titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
            bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.textPrimaryLight, height: 1.5),
            bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textSecondaryLight, height: 1.5),
            bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textTertiaryLight, height: 1.4),
            labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryLight),
            labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textTertiaryLight),
            labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiaryLight, letterSpacing: 0.5),
          );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE0E7FF),
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFF1F5F9),
        onSecondaryContainer: AppColors.secondaryDark,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        onSurfaceVariant: AppColors.textSecondaryLight,
        outline: AppColors.dividerLight,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorLight,
        onErrorContainer: AppColors.error,
        surfaceContainerHighest: Color(0xFFF1F5F9),
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppBorderRadius.lg),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.dividerLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.dividerLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        hintStyle: const TextStyle(color: AppColors.textTertiaryLight),
        labelStyle: const TextStyle(color: AppColors.textSecondaryLight),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
          elevation: 0,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
          elevation: 1,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.md)),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textSecondaryLight,
        size: AppSpacing.iconSizeMedium,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.textPrimaryLight),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.circular)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.xl)),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: AppColors.primaryLight,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xxl)),
        ),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
        tileColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      ),
      textTheme: textTheme,
    );
  }

  /// Build Urdu text theme using locally bundled Noto Nastaliq Urdu font
  TextTheme _buildUrduTextTheme(TextTheme base) {
    const urduFontFamily = 'NotoNastaliqUrdu';
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontFamily: urduFontFamily, fontSize: 28, height: 1.6),
      displayMedium: base.displayMedium?.copyWith(fontFamily: urduFontFamily, fontSize: 24, height: 1.6),
      displaySmall: base.displaySmall?.copyWith(fontFamily: urduFontFamily, fontSize: 20, height: 1.6),
      headlineLarge: base.headlineLarge?.copyWith(fontFamily: urduFontFamily, fontSize: 20, height: 1.6),
      headlineMedium: base.headlineMedium?.copyWith(fontFamily: urduFontFamily, fontSize: 18, height: 1.6),
      headlineSmall: base.headlineSmall?.copyWith(fontFamily: urduFontFamily, fontSize: 16, height: 1.6),
      titleLarge: base.titleLarge?.copyWith(fontFamily: urduFontFamily, fontSize: 16, height: 1.6),
      titleMedium: base.titleMedium?.copyWith(fontFamily: urduFontFamily, fontSize: 14, height: 1.6),
      titleSmall: base.titleSmall?.copyWith(fontFamily: urduFontFamily, fontSize: 12, height: 1.6),
      bodyLarge: base.bodyLarge?.copyWith(fontFamily: urduFontFamily, fontSize: 14, height: 1.8),
      bodyMedium: base.bodyMedium?.copyWith(fontFamily: urduFontFamily, fontSize: 12, height: 1.8),
      bodySmall: base.bodySmall?.copyWith(fontFamily: urduFontFamily, fontSize: 10, height: 1.8),
      labelLarge: base.labelLarge?.copyWith(fontFamily: urduFontFamily, fontSize: 12, height: 1.6),
      labelMedium: base.labelMedium?.copyWith(fontFamily: urduFontFamily, fontSize: 10, height: 1.6),
      labelSmall: base.labelSmall?.copyWith(fontFamily: urduFontFamily, fontSize: 9, height: 1.6),
    );
  }

  /// Build Dark Theme with optional Urdu font support
  ThemeData _buildDarkTheme(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isUrdu = languageProvider.currentLanguageCode == 'ur';
    
    // Use Noto Nastaliq Urdu for Urdu language, default font otherwise
    final textTheme = isUrdu
        ? _buildUrduTextTheme(ThemeData.dark().textTheme.copyWith(
              bodyLarge: const TextStyle(color: AppColors.textPrimaryDark),
              bodyMedium: const TextStyle(color: AppColors.textSecondaryDark),
              bodySmall: const TextStyle(color: AppColors.textTertiaryDark),
            ))
        : const TextTheme(
            displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark, letterSpacing: -0.5),
            displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark, letterSpacing: -0.5),
            displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark, letterSpacing: -0.25),
            headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
            headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
            headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
            titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
            titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
            titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
            bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.textPrimaryDark, height: 1.5),
            bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textSecondaryDark, height: 1.5),
            bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textTertiaryDark, height: 1.4),
            labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryDark),
            labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textTertiaryDark),
            labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiaryDark, letterSpacing: 0.5),
          );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF1E3A8A),
        onPrimaryContainer: Colors.white,
        secondary: AppColors.secondaryLight,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFF334155),
        onSecondaryContainer: Colors.white,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        onSurfaceVariant: AppColors.textSecondaryDark,
        outline: AppColors.dividerDark,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: Color(0xFF7F1D1D),
        onErrorContainer: Colors.white,
        surfaceContainerHighest: Color(0xFF334155),
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppBorderRadius.lg),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.dividerDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.dividerDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
          elevation: 0,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
          elevation: 1,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.md)),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textSecondaryDark,
        size: AppSpacing.iconSizeMedium,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.textPrimaryDark),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.circular)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.xl)),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
        contentTextStyle: const TextStyle(color: AppColors.textPrimaryLight),
        actionTextColor: AppColors.primary,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xxl)),
        ),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
        tileColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      ),
      textTheme: textTheme,
    );
  }
}
