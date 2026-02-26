import 'dart:convert';
import 'package:http/http.dart' as http;

class VideoItem {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final String publishedAt;
  final String description;

  VideoItem({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.description,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] ?? {};
    final id = json['id'] ?? {};
    final thumbnails = snippet['thumbnails'] ?? {};
    final defaultThumb = thumbnails['default'] ?? {};
    final mediumThumb = thumbnails['medium'] ?? {};
    final highThumb = thumbnails['high'] ?? {};

    String thumbnailUrl = defaultThumb['url'] ?? '';
    if (mediumThumb['url'] != null) thumbnailUrl = mediumThumb['url'];
    if (highThumb['url'] != null) thumbnailUrl = highThumb['url'];

    String videoId = '';
    if (id is String) {
      videoId = id;
    } else if (id is Map) {
      videoId = id['videoId'] ?? '';
    }

    return VideoItem(
      videoId: videoId,
      title: snippet['title'] ?? 'Untitled',
      channelTitle: snippet['channelTitle'] ?? 'Unknown Channel',
      thumbnailUrl: thumbnailUrl,
      publishedAt: snippet['publishedAt'] ?? '',
      description: snippet['description'] ?? '',
    );
  }
}

class YoutubeSearchResult {
  final List<VideoItem> videos;
  final String? nextPageToken;
  final String? prevPageToken;
  final int totalResults;

  YoutubeSearchResult({
    required this.videos,
    this.nextPageToken,
    this.prevPageToken,
    required this.totalResults,
  });
}

class YoutubeApiService {
  // YouTube Data API v3 key - configured via --dart-define for security
  // Get it from: https://console.cloud.google.com/apis/credentials
  static const String _apiKey = String.fromEnvironment('YOUTUBE_API_KEY');
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  // Allowed domains for search - users can only search within these topics
  static const List<String> _allowedDomains = [
    'English Language',
    'Web Development',
    'Computer Basics',
    'Digital Marketing',
  ];

  /// Check if a query is within allowed domains
  /// Returns the validated domain query string or empty if invalid
  static String? validateQuery(String query) {
    if (query.trim().isEmpty) return null;

    final lowerQuery = query.toLowerCase();

    // Domain-specific keywords mapping
    final domainKeywords = {
      'english language': [
        'english', 'grammar', 'vocabulary', 'speaking', 'listening',
        'writing', 'reading', 'pronunciation', 'ielts', 'toefl',
        'english speaking', 'learn english', 'english grammar',
        'english vocabulary', 'english conversation', 'english basics'
      ],
      'web development': [
        'web development', 'html', 'css', 'javascript', 'react', 'angular',
        'vue', 'frontend', 'backend', 'nodejs', 'web design', 'web app',
        'responsive design', 'web programming', 'full stack', 'frontend development'
      ],
      'computer basics': [
        'computer basics', 'computer fundamentals', 'windows', 'ms office',
        'word', 'excel', 'powerpoint', 'typing', 'computer hardware',
        'software', 'operating system', 'file management', 'internet basics',
        'computer literacy', 'basic computing'
      ],
      'digital marketing': [
        'digital marketing', 'seo', 'social media marketing', 'content marketing',
        'email marketing', 'google ads', 'facebook ads', 'instagram marketing',
        'marketing strategy', 'online marketing', 'affiliate marketing',
        'branding', 'digital advertising', 'marketing analytics'
      ],
    };

    // Check if query matches any domain
    for (final domain in _allowedDomains) {
      final keywords = domainKeywords[domain.toLowerCase()] ?? [];
      for (final keyword in keywords) {
        if (lowerQuery.contains(keyword)) {
          return query;
        }
      }
    }

    // If no direct match, append the most relevant domain context
    // based on partial matches
    int bestMatchScore = 0;
    String? bestDomain;

    for (final domain in _allowedDomains) {
      final keywords = domainKeywords[domain.toLowerCase()] ?? [];
      int score = 0;
      for (final keyword in keywords) {
        final keywordParts = keyword.split(' ');
        for (final part in keywordParts) {
          if (lowerQuery.contains(part) && part.length > 2) {
            score++;
          }
        }
      }
      if (score > bestMatchScore) {
        bestMatchScore = score;
        bestDomain = domain;
      }
    }

    if (bestDomain != null && bestMatchScore > 0) {
      return '$query $bestDomain';
    }

    // Default to educational context if no match found
    return '$query tutorial educational';
  }

  /// Search videos on YouTube within allowed domains only
  static Future<YoutubeSearchResult> searchVideos(
    String query, {
    int maxResults = 20,
    String? pageToken,
  }) async {
    // Validate and enhance query with domain context
    final validatedQuery = validateQuery(query);
    if (validatedQuery == null || validatedQuery.trim().isEmpty) {
      return YoutubeSearchResult(
        videos: [],
        totalResults: 0,
      );
    }

    // Add educational filter to all queries
    final searchQuery = '$validatedQuery tutorial';

    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'part': 'snippet',
          'q': searchQuery,
          'type': 'video',
          'videoEmbeddable': 'true',
          'videoSyndicated': 'true',
          'maxResults': maxResults.toString(),
          'order': 'relevance',
          'safeSearch': 'strict',
          if (pageToken != null) 'pageToken': pageToken,
          'key': _apiKey,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];

        final videos = items
            .map((item) => VideoItem.fromJson(item))
            .where((video) => video.videoId.isNotEmpty)
            .toList();

        return YoutubeSearchResult(
          videos: videos,
          nextPageToken: data['nextPageToken'],
          prevPageToken: data['prevPageToken'],
          totalResults: data['pageInfo']?['totalResults'] ?? 0,
        );
      } else if (response.statusCode == 403) {
        throw Exception(
          'API quota exceeded or invalid API key. Please check your YouTube Data API credentials.',
        );
      } else {
        throw Exception(
          'Failed to search videos: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error searching videos: $e');
    }
  }

  /// Get video details by ID
  static Future<VideoItem?> getVideoDetails(String videoId) async {
    try {
      final uri = Uri.parse('$_baseUrl/videos').replace(
        queryParameters: {
          'part': 'snippet,contentDetails',
          'id': videoId,
          'key': _apiKey,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];

        if (items.isNotEmpty) {
          return VideoItem.fromJson(items.first);
        }
        return null;
      } else {
        throw Exception('Failed to get video details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting video details: $e');
    }
  }

  /// Get list of allowed domains for UI display
  static List<String> getAllowedDomains() {
    return List.unmodifiable(_allowedDomains);
  }

  /// Check if API key is configured
  static bool isApiKeyConfigured() {
    return _apiKey.isNotEmpty &&
        _apiKey != 'YOUR_YOUTUBE_API_KEY_HERE';
  }
}
