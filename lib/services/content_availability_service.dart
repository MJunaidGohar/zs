import 'package:flutter/services.dart' show rootBundle;

/// Service to detect which topic/level/subtopic combinations have content
/// This scans the assets to determine what's actually available
/// Tracks both study and test content availability separately
class ContentAvailabilityService {
  static final ContentAvailabilityService _instance = ContentAvailabilityService._internal();
  factory ContentAvailabilityService() => _instance;
  ContentAvailabilityService._internal();

  // Cache for study content availability
  Map<String, Set<String>>? _availableSubtopicsStudy;
  Set<String>? _availableTopicsStudy;
  Map<String, Set<String>>? _availableLevelsPerTopicStudy;

  // Cache for test content availability
  Map<String, Set<String>>? _availableSubtopicsTest;
  Set<String>? _availableTopicsTest;
  Map<String, Set<String>>? _availableLevelsPerTopicTest;

  /// Scan all defined combinations and check which ones have actual content files
  Future<void> initialize() async {
    if (_availableSubtopicsStudy != null) return; // Already initialized

    _availableSubtopicsStudy = {};
    _availableTopicsStudy = {};
    _availableLevelsPerTopicStudy = {};

    _availableSubtopicsTest = {};
    _availableTopicsTest = {};
    _availableLevelsPerTopicTest = {};

    final topics = [
      'English',
      'YouTube',
      'Computer',
      'Digital Marketing',
      'Web Development',
    ];
    final levels = ['Basic', 'Intermediate', 'Advanced', 'Pro Master'];

    for (final topic in topics) {
      final subtopics = _getSubtopicsForTopic(topic);
      final key = '${topic.toLowerCase().replaceAll(' ', '_')}';

      for (final level in levels) {
        final levelKey = level.toLowerCase().replaceAll(' ', '_');

        for (final subtopic in subtopics) {
          final subtopicKey = subtopic.toLowerCase().replaceAll(' ', '_');
          final studyPath = 'assets/content/$key/$levelKey/$subtopicKey/study.json';
          final testPath = 'assets/content/$key/$levelKey/$subtopicKey/test.json';

          // Check for study content
          final hasStudyContent = await _checkFileExists(studyPath);
          if (hasStudyContent) {
            _availableTopicsStudy!.add(topic);
            _availableLevelsPerTopicStudy!.putIfAbsent(topic, () => {});
            _availableLevelsPerTopicStudy![topic]!.add(level);
            final studyComboKey = '${topic}_$level';
            _availableSubtopicsStudy!.putIfAbsent(studyComboKey, () => {});
            _availableSubtopicsStudy![studyComboKey]!.add(subtopic);
          }

          // Check for test content
          final hasTestContent = await _checkFileExists(testPath);
          if (hasTestContent) {
            _availableTopicsTest!.add(topic);
            _availableLevelsPerTopicTest!.putIfAbsent(topic, () => {});
            _availableLevelsPerTopicTest![topic]!.add(level);
            final testComboKey = '${topic}_$level';
            _availableSubtopicsTest!.putIfAbsent(testComboKey, () => {});
            _availableSubtopicsTest![testComboKey]!.add(subtopic);
          }
        }
      }
    }
  }

  /// Check if a file exists in assets by attempting to load it
  Future<bool> _checkFileExists(String path) async {
    try {
      await rootBundle.loadString(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get subtopics for a topic (internal helper)
  List<String> _getSubtopicsForTopic(String topic) {
    switch (topic) {
      case 'English':
        return ['Learning', 'Speaking', 'Writing', 'Listening'];
      case 'YouTube':
        return ['Shorts', 'Long Videos'];
      case 'Digital Marketing':
        return ['Google Ads', 'Meta Ads'];
      case 'Web Development':
        return ['Wix', 'Shopify', 'WordPress'];
      case 'Computer':
        return ['Basics', 'MS Office'];
      default:
        return [];
    }
  }

  /// Get all topics that have at least one study content file
  List<String> getAvailableTopics() {
    if (_availableTopicsStudy == null) return [];
    return _availableTopicsStudy!.toList()..sort();
  }

  /// Get all topics that have at least one test content file
  List<String> getAvailableTopicsForTest() {
    if (_availableTopicsTest == null) return [];
    return _availableTopicsTest!.toList()..sort();
  }

  /// Get levels that have study content for a specific topic
  List<String> getAvailableLevelsForTopic(String topic) {
    if (_availableLevelsPerTopicStudy == null) return [];
    final list = _availableLevelsPerTopicStudy![topic]?.toList();
    if (list == null) return [];
    list.sort();
    return list;
  }

  /// Get levels that have test content for a specific topic
  List<String> getAvailableLevelsForTopicTest(String topic) {
    if (_availableLevelsPerTopicTest == null) return [];
    final list = _availableLevelsPerTopicTest![topic]?.toList();
    if (list == null) return [];
    list.sort();
    return list;
  }

  /// Get subtopics that have study content for a specific topic+level combination
  List<String> getAvailableSubtopics(String topic, String level) {
    if (_availableSubtopicsStudy == null) return [];
    final key = '${topic}_$level';
    final list = _availableSubtopicsStudy![key]?.toList();
    if (list == null) return [];
    list.sort();
    return list;
  }

  /// Get subtopics that have test content for a specific topic+level combination
  List<String> getAvailableSubtopicsTest(String topic, String level) {
    if (_availableSubtopicsTest == null) return [];
    final key = '${topic}_$level';
    final list = _availableSubtopicsTest![key]?.toList();
    if (list == null) return [];
    list.sort();
    return list;
  }

  /// Check if a specific combination has study content (for Study Mode)
  bool hasStudyContent(String topic, String level, String subtopic) {
    final availableSubtopics = getAvailableSubtopics(topic, level);
    return availableSubtopics.contains(subtopic);
  }

  /// Check if a specific combination has test content (for Test Mode)
  bool hasTestContent(String topic, String level, String subtopic) {
    final availableSubtopics = getAvailableSubtopicsTest(topic, level);
    return availableSubtopics.contains(subtopic);
  }

  /// Check if a topic has any study content
  bool topicHasContent(String topic) {
    return getAvailableTopics().contains(topic);
  }

  /// Check if a topic has any test content
  bool topicHasTestContent(String topic) {
    return getAvailableTopicsForTest().contains(topic);
  }

  /// Get count of available study combinations for display
  int get totalAvailableCombinations {
    int count = 0;
    _availableSubtopicsStudy?.forEach((_, subtopics) {
      count += subtopics.length;
    });
    return count;
  }

  /// Reset cache (useful for testing or hot reload)
  void reset() {
    _availableSubtopicsStudy = null;
    _availableTopicsStudy = null;
    _availableLevelsPerTopicStudy = null;
    _availableSubtopicsTest = null;
    _availableTopicsTest = null;
    _availableLevelsPerTopicTest = null;
  }
}
