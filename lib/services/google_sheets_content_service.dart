import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import '../models/question.dart';
import 'hive_service.dart';

/// Service to fetch content from Google Sheets with offline persistence using Hive
/// 
/// Behavior:
/// - Online: Fetches fresh data from Google Sheets, saves to Hive
/// - Offline: Loads last saved data from Hive
/// - When back online: Automatically fetches and updates Hive data
/// - NO DUPLICATION: Each fetch replaces (not appends) cached data
class GoogleSheetsContentService {
  static final GoogleSheetsContentService _instance = GoogleSheetsContentService._internal();
  factory GoogleSheetsContentService() => _instance;
  GoogleSheetsContentService._internal();

  // Google Sheet IDs - Two separate sheets for Study and Test
  static const String _studySheetId = '1zkYzx9K4xz8RXCrxbUEaFRG6IEnqyAs007-Zv_H-Blg';  // Study Data
  static const String _testSheetId = '1EBd97At5nr1yKa6gBmZsUuOuoGTMGmJQq7vNSMA5-BI';   // Test Data (MCQs)
  
  // Hive storage keys
  static const String _hiveStudyData = 'gsheets_study_data';
  static const String _hiveTestData = 'gsheets_test_data';
  static const String _hiveTopics = 'gsheets_topics';
  static const String _hiveLevels = 'gsheets_levels';
  static const String _hiveSubtopics = 'gsheets_subtopics';
  static const String _hiveLastSync = 'gsheets_last_sync';
  
  // In-memory cache
  Map<String, List<Question>>? _studyCache;
  Map<String, List<Question>>? _testCache;
  Set<String>? _availableTopics;
  Map<String, Set<String>>? _availableLevelsPerTopic;
  Map<String, Set<String>>? _availableSubtopicsPerCombo;
  
  bool _isInitialized = false;
  DateTime? _lastSyncTime;
  Box? _cacheBox;

  /// Public getter to check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize service - checks connectivity and loads appropriate data
  ///
  /// Returns: true if fresh data was loaded from internet, false if using cached data
  Future<bool> initialize({bool forceReload = false}) async {
    // Allow force reload for cases where cache needs to be reloaded
    if (_isInitialized && !forceReload) {
      debugPrint('GoogleSheetsContentService: Already initialized, skipping');
      return false;
    }

    // Get Hive box
    _cacheBox = HiveService.gsheetsCacheBox;
    debugPrint('GoogleSheetsContentService: Hive box obtained, isOpen=${_cacheBox?.isOpen}');

    _studyCache = {};
    _testCache = {};
    _availableTopics = {};
    _availableLevelsPerTopic = {};
    _availableSubtopicsPerCombo = {};

    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;
      debugPrint('GoogleSheetsContentService: isOnline=$isOnline');

      if (isOnline) {
        // Online: Fetch fresh data and save locally
        try {
          await _fetchAndCacheFromSheets();
          _isInitialized = true;
          debugPrint('GoogleSheetsContentService: Fresh data loaded from internet');
          return true; // Fresh data loaded
        } catch (e) {
          debugPrint('GoogleSheetsContentService: Fetch failed, trying cache: $e');
          // Fetch failed, try to load cached data
          final hasCache = await _loadFromLocalStorage();
          _isInitialized = true;
          // If we loaded cache successfully but have no sync time, set it to now
          // to prevent "OFFLINE" badge from showing when we have valid data
          if (hasCache && _lastSyncTime == null) {
            _lastSyncTime = DateTime.now();
          }
          debugPrint('GoogleSheetsContentService: Using cache, hasCache=$hasCache');
          return false; // Using cache
        }
      } else {
        // Offline: Load from local storage
        debugPrint('GoogleSheetsContentService: Offline mode, loading from Hive');
        final hasCache = await _loadFromLocalStorage();
        _isInitialized = true;
        // If we have cached data but no sync time was restored, set it to now
        // so the OFFLINE badge doesn't show for valid cached data
        if (hasCache && _lastSyncTime == null) {
          _lastSyncTime = DateTime.now();
        }
        debugPrint('GoogleSheetsContentService: Cache loaded: hasCache=$hasCache, topics=${_availableTopics?.length}, lastSyncTime=$_lastSyncTime');
        return false; // Using cache
      }
    } catch (e) {
      // Error checking connectivity, try local storage
      debugPrint('GoogleSheetsContentService: Connectivity check error: $e');
      final hasCache = await _loadFromLocalStorage();
      _isInitialized = true;
      // If we have cached data but no sync time was restored, set it to now
      if (hasCache && _lastSyncTime == null) {
        _lastSyncTime = DateTime.now();
      }
      debugPrint('GoogleSheetsContentService: Fallback cache loaded: hasCache=$hasCache');
      return false;
    }
  }

  /// Check if currently online
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Force refresh data from Google Sheets
  /// 
  /// Call this when user pulls to refresh or when app detects network restoration
  /// SAFE: Clears existing data first, then saves new data (no duplication)
  Future<bool> refreshData() async {
    if (!await isOnline()) {
      return false; // Can't refresh when offline
    }

    try {
      // SAFETY: Clear all caches first to prevent duplication
      _clearAllCaches();
      
      await _fetchAndCacheFromSheets();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get last sync time
  DateTime? getLastSyncTime() => _lastSyncTime;

  /// Check if data was loaded from cache without any prior sync
  /// This returns true ONLY if no data has ever been synced (truly offline with no cache)
  /// Once data is fetched and cached, this returns false even if user goes offline later
  bool get isUsingCachedData => _lastSyncTime == null;

  // ==================== Data Fetching & Storage ====================

  /// Clear all in-memory caches (prevents duplication)
  void _clearAllCaches() {
    _studyCache?.clear();
    _testCache?.clear();
    _availableTopics?.clear();
    _availableLevelsPerTopic?.clear();
    _availableSubtopicsPerCombo?.clear();
  }

  /// Fetch data from Google Sheets and save to Hive
  /// SAFE: Clears existing data first, then saves fresh data
  Future<void> _fetchAndCacheFromSheets() async {
    try {
      // SAFETY: Clear existing data before fetching new data
      _clearAllCaches();
      if (_cacheBox != null && _cacheBox!.isOpen) {
        await _cacheBox!.clear();
      }

      // Fetch Study sheet
      await _fetchSheetData(_studySheetId, isTest: false);
      // Fetch Test sheet (MCQs)
      await _fetchSheetData(_testSheetId, isTest: true);
      
      // Save to Hive
      await _saveToLocalStorage();
      
      // Update sync time
      _lastSyncTime = DateTime.now();
    } catch (e) {
      throw Exception('Failed to fetch from Google Sheets: $e');
    }
  }

  /// Fetch data from a specific Google Sheet
  Future<void> _fetchSheetData(String sheetId, {required bool isTest}) async {
    final url = 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv';
    
    debugPrint('GoogleSheetsContentService: Fetching sheet ${isTest ? "TEST" : "STUDY"} from $sheetId');
    
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch sheet $sheetId: HTTP ${response.statusCode}');
    }

    // Properly decode UTF-8 response body to handle Urdu/Unicode characters
    final csvContent = utf8.decode(response.bodyBytes);
    final lines = csvContent.split('\n');
    debugPrint('GoogleSheetsContentService: Total lines in CSV: ${lines.length}');
    
    // Debug: Print first data row to verify encoding
    if (lines.length > 1) {
      debugPrint('GoogleSheetsContentService: First data row: ${lines[1]}');
    }
    
    if (lines.length < 2) {
      debugPrint('GoogleSheetsContentService: Empty sheet - no data rows');
      return;
    }

    final headers = _parseCsvLine(lines.first);
    debugPrint('GoogleSheetsContentService: Headers: $headers');
    
    int successCount = 0;
    int skipCount = 0;
    int errorCount = 0;
    
    for (var i = 1; i < lines.length; i++) {
      try {
        final row = _parseCsvLine(lines[i]);
        if (row.isEmpty || row.every((c) => c.isEmpty)) {
          skipCount++;
          continue;
        }

        final map = <String, String>{};
        for (var j = 0; j < headers.length; j++) {
          if (j < row.length) {
            map[headers[j].toLowerCase().trim()] = row[j].trim();
          }
        }

        final topic = map['topic'];
        final level = map['level'];
        final subtopic = map['subtopic'];

        if (topic == null || level == null || subtopic == null) {
          skipCount++;
          continue;
        }

        // Track available content
        _availableTopics!.add(topic);
        _availableLevelsPerTopic!.putIfAbsent(topic, () => {});
        _availableLevelsPerTopic![topic]!.add(level);
        
        final comboKey = '${topic}_$level';
        _availableSubtopicsPerCombo!.putIfAbsent(comboKey, () => {});
        _availableSubtopicsPerCombo![comboKey]!.add(subtopic);

        // Create question
        final question = _createQuestionFromMap(map, isTest: isTest);
        if (question.questionText.isEmpty) {
          skipCount++;
          continue;
        }

        final cacheKey = '${topic}_${level}_$subtopic';
        final cache = isTest ? _testCache! : _studyCache!;
        cache.putIfAbsent(cacheKey, () => []);
        cache[cacheKey]!.add(question);
        successCount++;
        
      } catch (e, stackTrace) {
        errorCount++;
        debugPrint('GoogleSheetsContentService: ERROR parsing row $i: $e');
        debugPrint('Row content: ${lines[i].substring(0, lines[i].length > 100 ? 100 : lines[i].length)}...');
        debugPrint('Stack: $stackTrace');
        // Continue processing next row - don't let one bad row stop everything
      }
    }
    
    debugPrint('GoogleSheetsContentService: ${isTest ? "TEST" : "STUDY"} fetch complete - Success: $successCount, Skipped: $skipCount, Errors: $errorCount');
    debugPrint('GoogleSheetsContentService: Topics found: ${_availableTopics?.length}, Test cache entries: ${_testCache?.length}, Study cache entries: ${_studyCache?.length}');
  }

  /// Save current data to Hive (REPLACES existing data - no duplication)
  Future<void> _saveToLocalStorage() async {
    if (_cacheBox == null || !_cacheBox!.isOpen) {
      debugPrint('GoogleSheetsContentService: ERROR - Cache box not available for saving');
      return;
    }

    try {
      // Convert caches to JSON-serializable format
      final studyData = _convertCacheToJson(_studyCache!);
      final testData = _convertCacheToJson(_testCache!);
      
      debugPrint('GoogleSheetsContentService: Saving ${studyData.length} study entries, ${testData.length} test entries, ${_availableTopics!.length} topics');
      
      // Save data to Hive (REPLACES old data - no duplication)
      await _cacheBox!.put(_hiveStudyData, jsonEncode(studyData));
      await _cacheBox!.put(_hiveTestData, jsonEncode(testData));
      await _cacheBox!.put(_hiveTopics, _availableTopics!.toList());
      await _cacheBox!.put(_hiveLevels, jsonEncode(_availableLevelsPerTopic!.map(
        (k, v) => MapEntry(k, v.toList()),
      )));
      await _cacheBox!.put(_hiveSubtopics, jsonEncode(_availableSubtopicsPerCombo!.map(
        (k, v) => MapEntry(k, v.toList()),
      )));
      await _cacheBox!.put(_hiveLastSync, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('GoogleSheetsContentService: Data saved to Hive successfully');
    } catch (e, stackTrace) {
      debugPrint('GoogleSheetsContentService: ERROR saving to Hive: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Load data from Hive
  Future<bool> _loadFromLocalStorage() async {
    if (_cacheBox == null || !_cacheBox!.isOpen) {
      debugPrint('GoogleSheetsContentService: Cache box not available');
      return false;
    }

    final topicsList = _cacheBox!.get(_hiveTopics);
    final levelsJson = _cacheBox!.get(_hiveLevels);
    final subtopicsJson = _cacheBox!.get(_hiveSubtopics);
    final studyJson = _cacheBox!.get(_hiveStudyData);
    final testJson = _cacheBox!.get(_hiveTestData);
    final lastSync = _cacheBox!.get(_hiveLastSync);

    debugPrint('GoogleSheetsContentService: Hive data - topics=${topicsList != null}, study=${studyJson != null}, test=${testJson != null}');

    // CRITICAL FIX: Only require topics list, not both study AND test data
    // This allows offline mode to work if only one type of content was cached
    if (topicsList == null) {
      debugPrint('GoogleSheetsContentService: No cached topics available');
      return false;
    }

    try {
      // Restore topics first (essential for offline mode)
      _availableTopics = (topicsList as List<dynamic>).cast<String>().toSet();
      debugPrint('GoogleSheetsContentService: Restored ${_availableTopics?.length} topics: $_availableTopics');

      // Restore levels
      if (levelsJson != null) {
        final levelsData = jsonDecode(levelsJson) as Map<String, dynamic>;
        _availableLevelsPerTopic = levelsData.map(
          (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>().toSet()),
        );
        debugPrint('GoogleSheetsContentService: Restored levels for ${_availableLevelsPerTopic?.length} topics');
      }

      // Restore subtopics
      if (subtopicsJson != null) {
        final subtopicsData = jsonDecode(subtopicsJson) as Map<String, dynamic>;
        _availableSubtopicsPerCombo = subtopicsData.map(
          (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>().toSet()),
        );
        debugPrint('GoogleSheetsContentService: Restored subtopics for ${_availableSubtopicsPerCombo?.length} combos');
      }

      // Restore study cache if available
      if (studyJson != null) {
        final studyData = jsonDecode(studyJson) as Map<String, dynamic>;
        _studyCache = _convertJsonToCache(studyData);
        debugPrint('GoogleSheetsContentService: Restored ${_studyCache?.length} study entries');
      } else {
        _studyCache = {};
      }

      // Restore test cache if available
      if (testJson != null) {
        final testData = jsonDecode(testJson) as Map<String, dynamic>;
        _testCache = _convertJsonToCache(testData);
        debugPrint('GoogleSheetsContentService: Restored ${_testCache?.length} test entries');
      } else {
        _testCache = {};
      }

      // Restore sync time
      if (lastSync != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
      } else {
        // If no sync time was stored (older app version), set a default
        // to prevent always showing "OFFLINE" badge
        _lastSyncTime = DateTime.now();
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('GoogleSheetsContentService: Error parsing cached data: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Convert cache map to JSON-serializable format
  Map<String, List<Map<String, dynamic>>> _convertCacheToJson(
    Map<String, List<Question>> cache,
  ) {
    return cache.map((key, questions) => MapEntry(
      key,
      questions.map((q) => q.toJson()).toList(),
    ));
  }

  /// Convert JSON data back to cache map
  Map<String, List<Question>> _convertJsonToCache(
    Map<String, dynamic> jsonData,
  ) {
    final result = <String, List<Question>>{};
    
    jsonData.forEach((key, value) {
      final questionsList = (value as List<dynamic>).map((json) {
        return Question.fromJson(json as Map<String, dynamic>);
      }).toList();
      result[key] = questionsList;
    });
    
    return result;
  }

  /// Parse CSV line handling quoted values
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    result.add(buffer.toString().trim());
    return result;
  }

  /// Create Question from CSV map
  Question _createQuestionFromMap(Map<String, String> map, {required bool isTest}) {
    // Extract options for test questions
    List<String>? options;
    if (isTest) {
      // Create fixed 4-slot array to preserve index alignment with correct_option
      final rawOptions = [
        map['option_a'] ?? '',
        map['option_b'] ?? '',
        map['option_c'] ?? '',
        map['option_d'] ?? '',
      ];
      // Only create options if at least one exists
      if (rawOptions.any((o) => o.isNotEmpty)) {
        options = rawOptions; // Keep all 4 slots including empty ones to maintain A/B/C/D indices
      }
    }

    // Convert correct option letter to answer text
    String? correctAnswer;
    final correctOption = map['correct_option']?.toUpperCase();
    if (correctOption != null && options != null && options.isNotEmpty) {
      final index = correctOption.codeUnitAt(0) - 'A'.codeUnitAt(0);
      // Only use correct answer if index is valid AND the option text is not empty
      if (index >= 0 && index < options.length && options[index].isNotEmpty) {
        correctAnswer = options[index];
      }
    }

    return Question(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      questionText: map['question'] ?? '',
      options: options?.isNotEmpty == true ? options : null,
      correctAnswer: correctAnswer,
      answer: map['answer'] ?? map['explanation'] ?? '',
      topic: map['topic'],
      level: map['level'],
      subtopic: map['subtopic'],
    );
  }

  // ==================== Public API ====================

  /// Get all topics that have content
  /// Ordered: English, Computer, Digital Marketing, Web Development
  List<String> getAvailableTopics() {
    if (_availableTopics == null || _availableTopics!.isEmpty) return [];
    final topics = _availableTopics!.toList();
    final topicOrder = ['English', 'Computer', 'Digital Marketing', 'Web Development'];
    topics.sort((a, b) {
      final indexA = topicOrder.indexOf(a);
      final indexB = topicOrder.indexOf(b);
      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      return a.compareTo(b);
    });
    return topics;
  }

  /// Get levels for a specific topic
  /// Ordered: Basic, Intermediate, Advance, Pro Master
  List<String> getAvailableLevelsForTopic(String topic) {
    if (_availableLevelsPerTopic == null) return [];
    final levels = _availableLevelsPerTopic![topic];
    if (levels == null) return [];
    final levelsList = levels.toList();
    final levelOrder = ['Basic', 'Intermediate', 'Advance', 'Pro Master'];
    levelsList.sort((a, b) {
      final indexA = levelOrder.indexOf(a);
      final indexB = levelOrder.indexOf(b);
      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      return a.compareTo(b);
    });
    return levelsList;
  }

  /// Get subtopics for a topic+level combination
  List<String> getAvailableSubtopics(String topic, String level) {
    if (_availableSubtopicsPerCombo == null) return [];
    final key = '${topic}_$level';
    final subtopics = _availableSubtopicsPerCombo![key];
    if (subtopics == null) return [];
    return subtopics.toList()..sort();
  }

  /// Load study questions - tries memory cache first, then Hive storage
  Future<List<Question>> loadStudyQuestions({
    required String topic,
    required String level,
    required String subtopic,
  }) async {
    final cacheKey = '${topic}_${level}_$subtopic';
    
    // Try memory cache first
    if (_studyCache?.containsKey(cacheKey) == true) {
      return _studyCache![cacheKey]!;
    }
    
    // Try loading from Hive if memory cache is empty
    if (_cacheBox == null || !_cacheBox!.isOpen) {
      _cacheBox = HiveService.gsheetsCacheBox;
    }
    
    // Load from local storage if not already loaded
    if (_studyCache == null || _studyCache!.isEmpty) {
      final loaded = await _loadFromLocalStorage();
      if (loaded && _studyCache?.containsKey(cacheKey) == true) {
        return _studyCache![cacheKey]!;
      }
    }
    
    return [];
  }

  /// Load test questions - tries memory cache first, then Hive storage
  Future<List<Question>> loadTestQuestions({
    required String topic,
    required String level,
    required String subtopic,
  }) async {
    final cacheKey = '${topic}_${level}_$subtopic';
    
    // Try memory cache first
    if (_testCache?.containsKey(cacheKey) == true) {
      return _testCache![cacheKey]!;
    }
    
    // Try loading from Hive if memory cache is empty
    if (_cacheBox == null || !_cacheBox!.isOpen) {
      _cacheBox = HiveService.gsheetsCacheBox;
    }
    
    // Load from local storage if not already loaded
    if (_testCache == null || _testCache!.isEmpty) {
      final loaded = await _loadFromLocalStorage();
      if (loaded && _testCache?.containsKey(cacheKey) == true) {
        return _testCache![cacheKey]!;
      }
    }
    
    return [];
  }

  /// Check if study content exists
  bool hasStudyContent(String topic, String level, String subtopic) {
    final cacheKey = '${topic}_${level}_$subtopic';
    return _studyCache?.containsKey(cacheKey) == true && 
           (_studyCache![cacheKey]?.isNotEmpty ?? false);
  }

  /// Check if test content exists (checks both memory cache and Hive storage)
  bool hasTestContent(String topic, String level, String subtopic) {
    final cacheKey = '${topic}_${level}_$subtopic';

    // Check memory cache first
    if (_testCache?.containsKey(cacheKey) == true &&
        (_testCache![cacheKey]?.isNotEmpty ?? false)) {
      return true;
    }

    // Fallback: Check if data exists in Hive storage without loading full cache
    if (_cacheBox?.isOpen == true) {
      try {
        final testJson = _cacheBox!.get(_hiveTestData);
        if (testJson != null && testJson is String) {
          final testData = jsonDecode(testJson) as Map<String, dynamic>;
          final questions = testData[cacheKey] as List<dynamic>?;
          return questions != null && questions.isNotEmpty;
        }
      } catch (e) {
        debugPrint('Error checking Hive for test content: $e');
      }
    }

    return false;
  }

  /// Load all test questions for a specific topic across all levels and subtopics
  /// Returns aggregated list for certificate test
  Future<List<Question>> loadAllTestQuestionsForTopic(String topic) async {
    final allQuestions = <Question>[];
    
    // Get all levels for this topic
    final levels = getAvailableLevelsForTopic(topic);
    
    for (final level in levels) {
      // Get all subtopics for this topic+level combo
      final subtopics = getAvailableSubtopics(topic, level);
      
      for (final subtopic in subtopics) {
        final questions = await loadTestQuestions(
          topic: topic,
          level: level,
          subtopic: subtopic,
        );
        allQuestions.addAll(questions);
      }
    }
    
    return allQuestions;
  }

  /// Check if certificate test is available (has test content across levels)
  bool hasCertificateContent(String topic) {
    final levels = getAvailableLevelsForTopic(topic);
    int totalQuestions = 0;
    
    for (final level in levels) {
      final subtopics = getAvailableSubtopics(topic, level);
      for (final subtopic in subtopics) {
        if (hasTestContent(topic, level, subtopic)) {
          totalQuestions++;
          if (totalQuestions >= 5) return true; // Minimum 5 questions needed
        }
      }
    }
    return totalQuestions >= 5;
  }

  /// Clear cache and local storage (useful for full refresh)
  /// SAFE: Clears both memory and Hive storage
  Future<void> clearCache() async {
    _clearAllCaches();
    _isInitialized = false;
    _lastSyncTime = null;
    
    // Clear Hive storage
    if (_cacheBox != null && _cacheBox!.isOpen) {
      await _cacheBox!.clear();
    }
  }
}
