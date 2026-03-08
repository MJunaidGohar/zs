import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// AppLocalizations handles loading and providing localized strings
/// Supports English (en) and Urdu (ur) languages
/// Urdu uses RTL text direction
class AppLocalizations {
  final Locale locale;
  late Map<String, String> _localizedStrings;

  AppLocalizations(this.locale) {
    _localizedStrings = {};
  }

  /// Helper method to get the current AppLocalizations instance
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// Load the localized strings from JSON file
  Future<bool> load() async {
    try {
      String jsonString = await rootBundle.loadString(
        'lib/l10n/${locale.languageCode}.json',
      );
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      
      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });
      
      debugPrint('AppLocalizations: Loaded ${locale.languageCode} with ${_localizedStrings.length} strings');
      return true;
    } catch (e) {
      debugPrint('AppLocalizations: Error loading ${locale.languageCode}: $e');
      // Fallback to English if translation file not found
      if (locale.languageCode != 'en') {
        try {
          String jsonString = await rootBundle.loadString('lib/l10n/en.json');
          Map<String, dynamic> jsonMap = json.decode(jsonString);
          _localizedStrings = jsonMap.map((key, value) {
            return MapEntry(key, value.toString());
          });
          debugPrint('AppLocalizations: Fallback to English loaded');
        } catch (fallbackError) {
          debugPrint('AppLocalizations: Fallback also failed: $fallbackError');
        }
      }
      return true;
    }
  }

  /// Translate a key to the current locale's string
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  /// Get string with fallback
  String translateOrDefault(String key, String defaultValue) {
    return _localizedStrings[key] ?? defaultValue;
  }

  /// Check if current locale is RTL
  bool get isRtl => locale.languageCode == 'ur' || locale.languageCode == 'ar';

  /// Get text direction based on locale
  TextDirection get textDirection => isRtl ? TextDirection.rtl : TextDirection.ltr;

  /// Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('en'),
    Locale('ur', 'PK'),
    Locale('ur'),
  ];

  // ================== GETTERS FOR ALL LOCALIZED STRINGS ==================

  // App General
  String get appName => translate('appName');
  String get welcome => translate('welcome');
  String get beginYourLearningJourney => translate('beginYourLearningJourney');
  String get joinThousandsOfLearners => translate('joinThousandsOfLearners');
  String get tapToCustomize => translate('tapToCustomize');
  String get whatShouldWeCallYou => translate('whatShouldWeCallYou');
  String get chooseNameThatInspires => translate('chooseNameThatInspires');
  String get enterYourName => translate('enterYourName');
  String get characters => translate('characters');
  String get startLearningJourney => translate('startLearningJourney');
  String get enterYourNameButton => translate('enterYourNameButton');
  String get freeForever => translate('freeForever');
  String get learnOffline => translate('learnOffline');
  String get earnRewards => translate('earnRewards');
  String get pleaseEnterYourName => translate('pleaseEnterYourName');
  String get nameShouldBeAtLeast2Characters => translate('nameShouldBeAtLeast2Characters');

  // Navigation
  String get home => translate('home');
  String get profile => translate('profile');
  String get settings => translate('settings');
  String get darkMode => translate('darkMode');
  String get lightMode => translate('lightMode');
  String get language => translate('language');
  String get english => translate('english');
  String get urdu => translate('urdu');

  // Selection
  String get selectTopic => translate('selectTopic');
  String get selectLevel => translate('selectLevel');
  String get selectSubtopic => translate('selectSubtopic');
  String get topics => translate('topics');
  String get levels => translate('levels');
  String get subtopics => translate('subtopics');
  String get noTopicsAvailable => translate('noTopicsAvailable');
  String get noLevelsAvailable => translate('noLevelsAvailable');
  String get noSubtopicsAvailable => translate('noSubtopicsAvailable');

  // Test & Learn
  String get testMode => translate('testMode');
  String get learnMode => translate('learnMode');
  String get startTest => translate('startTest');
  String get startLearning => translate('startLearning');
  String get questions => translate('questions');
  String get question => translate('question');
  String get questionOf => translate('of');
  String get next => translate('next');
  String get previous => translate('previous');
  String get submit => translate('submit');
  String get finish => translate('finish');
  String get cancel => translate('cancel');
  String get confirm => translate('confirm');
  String get back => translate('back');
  String get done => translate('done');
  String get close => translate('close');
  String get save => translate('save');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get share => translate('share');
  String get download => translate('download');
  String get refresh => translate('refresh');
  String get retry => translate('retry');
  String get loading => translate('loading');
  String get noData => translate('noData');
  String get error => translate('error');
  String get success => translate('success');

  // Results
  String get correct => translate('correct');
  String get incorrect => translate('incorrect');
  String get explanation => translate('explanation');
  String get yourAnswer => translate('yourAnswer');
  String get correctAnswer => translate('correctAnswer');
  String get timeTaken => translate('timeTaken');
  String get score => translate('score');
  String get totalScore => translate('totalScore');
  String get percentage => translate('percentage');
  String get passed => translate('passed');
  String get failed => translate('failed');
  String get excellent => translate('excellent');
  String get goodJob => translate('goodJob');
  String get keepPracticing => translate('keepPracticing');
  String get testCompleted => translate('testCompleted');
  String get viewResults => translate('viewResults');
  String get retakeTest => translate('retakeTest');

  // Notes
  String get studyMaterial => translate('studyMaterial');
  String get notes => translate('notes');
  String get videos => translate('videos');
  String get noNotesAvailable => translate('noNotesAvailable');
  String get noVideosAvailable => translate('noVideosAvailable');
  String get addNote => translate('addNote');
  String get editNote => translate('editNote');
  String get noteTitle => translate('noteTitle');
  String get noteContent => translate('noteContent');
  String get enterNoteTitle => translate('enterNoteTitle');
  String get enterNoteContent => translate('enterNoteContent');
  String get saveNote => translate('saveNote');
  String get deleteNote => translate('deleteNote');
  String get deleteNoteConfirm => translate('deleteNoteConfirm');
  String get lastModified => translate('lastModified');
  String get created => translate('created');

  // Chat
  String get chatWithAI => translate('chatWithAI');
  String get askAnything => translate('askAnything');
  String get typeYourMessage => translate('typeYourMessage');
  String get send => translate('send');
  String get aiAssistant => translate('aiAssistant');
  String get thinking => translate('thinking');
  String get dailyQuota => translate('dailyQuota');
  String get messagesRemaining => translate('messagesRemaining');
  String get upgradeForUnlimited => translate('upgradeForUnlimited');

  // Game
  String get game => translate('game');
  String get playGame => translate('playGame');
  String get scoreGame => translate('scoreGame');
  String get highScore => translate('highScore');
  String get newHighScore => translate('newHighScore');
  String get level => translate('level');
  String get combo => translate('combo');
  String get pause => translate('pause');
  String get resume => translate('resume');
  String get restart => translate('restart');
  String get quit => translate('quit');
  String get gameOver => translate('gameOver');
  String get playAgain => translate('playAgain');

  // Tools
  String get tools => translate('tools');
  String get calculator => translate('calculator');
  String get converter => translate('converter');
  String get dictionary => translate('dictionary');
  String get translator => translate('translator');
  String get qrScanner => translate('qrScanner');

  // Profile
  String get myProfile => translate('myProfile');
  String get editProfile => translate('editProfile');
  String get changeAvatar => translate('changeAvatar');
  String get statistics => translate('statistics');
  String get achievements => translate('achievements');
  String get progress => translate('progress');
  String get completed => translate('completed');
  String get inProgress => translate('inProgress');
  String get notStarted => translate('notStarted');
  String get streak => translate('streak');
  String get dayStreak => translate('dayStreak');
  String get totalTime => translate('totalTime');
  String get testsTaken => translate('testsTaken');
  String get averageScore => translate('averageScore');

  // Settings
  String get notifications => translate('notifications');
  String get sound => translate('sound');
  String get vibration => translate('vibration');
  String get music => translate('music');
  String get backgroundMusic => translate('backgroundMusic');
  String get volume => translate('volume');

  // About
  String get about => translate('about');
  String get version => translate('version');
  String get privacyPolicy => translate('privacyPolicy');
  String get termsOfService => translate('termsOfService');
  String get contactUs => translate('contactUs');
  String get rateApp => translate('rateApp');
  String get shareApp => translate('shareApp');

  // Connectivity
  String get offlineMode => translate('offlineMode');
  String get onlineMode => translate('onlineMode');
  String get syncData => translate('syncData');
  String get dataSynced => translate('dataSynced');
  String get noInternet => translate('noInternet');
  String get checkConnection => translate('checkConnection');

  // Dialogs
  String get areYouSure => translate('areYouSure');
  String get unsavedChanges => translate('unsavedChanges');
  String get discardChanges => translate('discardChanges');
  String get stay => translate('stay');
  String get exit => translate('exit');
  String get yes => translate('yes');
  String get no => translate('no');
  String get ok => translate('ok');
  String get gotIt => translate('gotIt');
  String get comingSoon => translate('comingSoon');
  String get featureComingSoon => translate('featureComingSoon');
  
  // Main Selection Screen
  String get learningPath => translate('learningPath');
  String get chooseYourJourney => translate('chooseYourJourney');
  String get offline => translate('offline');
  String get usingSavedContent => translate('usingSavedContent');
  String get checkInternetConnection => translate('checkInternetConnection');
  String get selectTopicFirst => translate('selectTopicFirst');
  String get selectLevelFirst => translate('selectLevelFirst');
  String get challengeYourself => translate('challengeYourself');
  String get learnAtYourPace => translate('learnAtYourPace');
  String get consultation => translate('consultation');
  
  // Test Screen (additional strings not already defined)
  String get result => translate('result');
  String get noQuestionsAvailable => translate('noQuestionsAvailable');
  String get noStudyMaterialAvailable => translate('noStudyMaterialAvailable');
  String get checkBackLater => translate('checkBackLater');
  String get loadingStudyMaterial => translate('loadingStudyMaterial');
  String get completedPercent => translate('completedPercent');
  String get submitTest => translate('submitTest');
  String get nextQuestion => translate('nextQuestion');
  String get reattempt => translate('reattempt');
  String get wrong => translate('wrong');
  String get answer => translate('answer');
  String get noAnswerAvailable => translate('noAnswerAvailable');
  String get endOfStudyMaterial => translate('endOfStudyMaterial');
  String get unitCompleted => translate('unitCompleted');
  String get dontGiveUp => translate('dontGiveUp');
  String get shareResult => translate('shareResult');
  String get sharing => translate('sharing');
  
  // Profile Screen (additional strings not already defined)
  String get personalProfile => translate('personalProfile');
  String get loadingProfile => translate('loadingProfile');
  String get studyProgress => translate('studyProgress');
  String get testProgress => translate('testProgress');
  String get retryWrongTests => translate('retryWrongTests');
  String get practiceQuestionsWrong => translate('practiceQuestionsWrong');
  String get gameTime => translate('gameTime');
  String get watchVideos => translate('watchVideos');
  String get noStudyProgressFound => translate('noStudyProgressFound');
  String get noTestProgressFound => translate('noTestProgressFound');
  String get noWrongAttempts => translate('noWrongAttempts');
  String get editName => translate('editName');
  String get nameUpdatedSuccessfully => translate('nameUpdatedSuccessfully');
  
  // Notes Screen
  String get notesTitle => translate('notesTitle');
  String get createNewNote => translate('createNewNote');
  String get tapToStartWriting => translate('tapToStartWriting');
  String get recentNotes => translate('recentNotes');
  String get note => translate('note');
  String get noNotesYet => translate('noNotesYet');
  String get createFirstNote => translate('createFirstNote');
  String get deleteNoteConfirmTitle => translate('deleteNoteConfirmTitle');
  String get renameNote => translate('renameNote');
  String get enterNewName => translate('enterNewName');
  String get rename => translate('rename');
  String get pin => translate('pin');
  String get unpin => translate('unpin');
  String get today => translate('today');
  String get yesterday => translate('yesterday');
  
  // Tools Screen
  String get toolsTitle => translate('toolsTitle');
  String get utilityTools => translate('utilityTools');
  String get selectToolToStart => translate('selectToolToStart');
  String get ruler => translate('ruler');
  String get stopwatch => translate('stopwatch');
  String get planner => translate('planner');
  String get flashlight => translate('flashlight');
  String get comingSoonExclamation => translate('comingSoonExclamation');
  
  // Chat Screen
  String get welcomeToZSAssistant => translate('welcomeToZSAssistant');
  String get askYourQuestion => translate('askYourQuestion');
  String get messagesPerDay => translate('messagesPerDay');
  String get typeYourQuestion => translate('typeYourQuestion');
  String get dailyQuotaReached => translate('dailyQuotaReached');
  String get quotaExhausted => translate('quotaExhausted');
  String get dailyQuotaReachedMessage => translate('dailyQuotaReachedMessage');
  
  // TopBarScaffold Menu & Avatar Screen
  String get selectYourAvatar => translate('selectYourAvatar');
  String get chooseYourLook => translate('chooseYourLook');
  String get selectAvatarRepresentsYou => translate('selectAvatarRepresentsYou');
  String get tapAvatarToSelect => translate('tapAvatarToSelect');
  String get boyAvatar => translate('boyAvatar');
  String get girlAvatar => translate('girlAvatar');
  String get yourPhoto => translate('yourPhoto');
  String get switchToLightMode => translate('switchToLightMode');
  String get switchToDarkMode => translate('switchToDarkMode');
  String get permissionRequired => translate('permissionRequired');
  String get dismiss => translate('dismiss');
  
  // Note Editor Screen
  String get unsavedChangesTitle => translate('unsavedChangesTitle');
  String get unsavedChangesMessage => translate('unsavedChangesMessage');
  String get discard => translate('discard');
  String get noteSavedSuccessfully => translate('noteSavedSuccessfully');
  String get enterNoteTitleHint => translate('enterNoteTitleHint');
  String get newNote => translate('newNote');
  String get startWritingNote => translate('startWritingNote');
  String get chars => translate('chars');
  String get cannotOpenLink => translate('cannotOpenLink');
  String get errorOpeningLink => translate('errorOpeningLink');
  
  String get welcomeToBrainStorming => translate('welcomeToBrainStorming');
  String get matchColorfulTiles => translate('matchColorfulTiles');
  String get howToSwap => translate('howToSwap');
  String get tapOneTileThenAdjacent => translate('tapOneTileThenAdjacent');
  String get makeMatches => translate('makeMatches');
  String get matchThreeOrMore => translate('matchThreeOrMore');
  String get startPlaying => translate('startPlaying');
  String get dontShowAgain => translate('dontShowAgain');
  String get chooseYourTheme => translate('chooseYourTheme');
  String get selectEmojiStyle => translate('selectEmojiStyle');
  String get fruits => translate('fruits');
  String get classicFruitEmojis => translate('classicFruitEmojis');
  String get selected => translate('selected');
  String get emojis => translate('emojis');
  String get socialMediaFavorites => translate('socialMediaFavorites');
  String get brainStorming => translate('brainStorming');
  String get noMatchesAvailable => translate('noMatchesAvailable');
  
  // Learning Videos Screen
  String get backToProfile => translate('backToProfile');
  String get learningVideos => translate('learningVideos');
  String get searchLearningVideos => translate('searchLearningVideos');
  String get discoverLearningVideos => translate('discoverLearningVideos');
  String get searchEducationalVideos => translate('searchEducationalVideos');
  String get noResultsFound => translate('noResultsFound');
  String get tryDifferentKeywords => translate('tryDifferentKeywords');
  String get somethingWentWrong => translate('somethingWentWrong');
  String get tryAgain => translate('tryAgain');
  String get year => translate('year');
  String get years => translate('years');
  String get month => translate('month');
  String get months => translate('months');
  String get day => translate('day');
  String get days => translate('days');
  String get hour => translate('hour');
  String get hours => translate('hours');
  String get minute => translate('minute');
  String get minutes => translate('minutes');
  String get justNow => translate('justNow');
  String get ago => translate('ago');
  
  // Video Player Screen
  String get nowPlaying => translate('nowPlaying');
  String get youtubeChannel => translate('youtubeChannel');
  String get description => translate('description');
  String get noDescriptionAvailable => translate('noDescriptionAvailable');
  String get useYouTubeControls => translate('useYouTubeControls');
  String get contentFromYouTube => translate('contentFromYouTube');
  String get adLoading => translate('adLoading');
  String get errorLoadingVideo => translate('errorLoadingVideo');
}

/// Localizations delegate for AppLocalizations
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Support English and Urdu
    return ['en', 'ur'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    debugPrint('AppLocalizationsDelegate: Loading locale ${locale.languageCode}');
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    debugPrint('AppLocalizationsDelegate: Finished loading ${locale.languageCode}');
    return localizations;
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => true;
}
