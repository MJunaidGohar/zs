import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

/// AI Chat Service
/// Handles communication with Google Gemini API
/// Optimized for production use with proper error handling and safety measures
class AIChatService {
  // API Configuration - Using stable model version instead of latest
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _baseUrl = 'generativelanguage.googleapis.com';
  static const String _model = 'models/gemini-1.5-flash'; // Stable version instead of -latest
  
  // Safety Settings - Block harmful content
  static const List<Map<String, dynamic>> _safetySettings = [
    {
      'category': 'HARM_CATEGORY_HARASSMENT',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
    {
      'category': 'HARM_CATEGORY_HATE_SPEECH',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
    {
      'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
    {
      'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
      'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
    },
  ];

  // System Prompt - Educational context for ZS Assistant
  static const String _systemPrompt = '''
You are ZS Assistant, an educational AI for the Zaroori Sawal app.

Your role:
- Help users learn: English, Computer basics, Digital Marketing, Web Development, and YouTube skills
- Answer questions related to these educational topics
- Keep responses concise (max 150 words) and educational
- Be encouraging and supportive in tone
- Use simple language suitable for learners

Rules:
- Stay within educational topics only
- If unsure, say "I don't know" rather than guessing
- Never provide harmful, illegal, or inappropriate content
- Do not write code that could be used maliciously
- Focus on learning and skill development

Current date: {date}
''';

  // HTTP Client with timeout configuration
  final http.Client _client = http.Client();
  
  // Request timeout
  static const Duration _timeout = Duration(seconds: 15);

  /// Check if API key is configured
  bool get isConfigured => _apiKey.isNotEmpty && _apiKey != 'null';

  /// Generate content using Gemini API
  /// Returns AI response or error message
  Future<ChatMessage> generateResponse(String userMessage) async {
    // Validate API configuration
    if (!isConfigured) {
      return ChatMessage.assistant(
        content: 'ZS Assistant is temporarily unavailable. Please try again later.',
        status: MessageStatus.error,
      );
    }

    // Input validation
    final sanitizedInput = _sanitizeInput(userMessage);
    if (sanitizedInput.isEmpty) {
      return ChatMessage.assistant(
        content: 'Please type a question to get started.',
        status: MessageStatus.sent,
      );
    }

    try {
      // Prepare request body
      final requestBody = _buildRequestBody(sanitizedInput);
      
      // Make API call
      final response = await _makeApiCall(requestBody);
      
      // Parse and return result
      return _parseResponse(response);
      
    } on TimeoutException {
      return ChatMessage.assistant(
        content: 'Connection is slow. Please check your internet and try again.',
        status: MessageStatus.error,
      );
    } on SocketException {
      return ChatMessage.assistant(
        content: 'No internet connection. Please connect to network and try again.',
        status: MessageStatus.error,
      );
    } catch (e) {
      return ChatMessage.assistant(
        content: 'Something went wrong. Please try again.',
        status: MessageStatus.error,
      );
    }
  }

  /// Build API request body
  Map<String, dynamic> _buildRequestBody(String userMessage) {
    final prompt = _systemPrompt.replaceAll(
      '{date}',
      DateTime.now().toIso8601String().split('T')[0],
    );

    return {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '$prompt\n\nUser question: $userMessage'},
          ],
        },
      ],
      'safetySettings': _safetySettings,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 256,
        'topP': 0.9,
      },
    };
  }

  /// Make HTTP API call to Gemini
  Future<http.Response> _makeApiCall(Map<String, dynamic> body) async {
    final uri = Uri.https(
      _baseUrl,
      '/v1beta/$_model:generateContent',
      {'key': _apiKey},
    );

    debugPrint('🔍 [AIChatService] Making API call to: ${uri.toString().replaceAll(_apiKey, '***')}');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      
      debugPrint('🔍 [AIChatService] Response status: ${response.statusCode}');
      debugPrint('🔍 [AIChatService] Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      
      return response;
    } catch (e) {
      debugPrint('🔍 [AIChatService] API call error: $e');
      rethrow;
    }
  }

  /// Parse API response
  ChatMessage _parseResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Check for blocked content
      if (data['promptFeedback']?['blockReason'] != null) {
        return ChatMessage.assistant(
          content: "I can't answer that. Let's focus on educational topics!",
          status: MessageStatus.sent,
        );
      }

      // Extract response text
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        final parts = content['parts'] as List<dynamic>?;
        
        if (parts != null && parts.isNotEmpty) {
          final text = parts[0]['text'] as String?;
          if (text != null && text.isNotEmpty) {
            return ChatMessage.assistant(
              content: text.trim(),
              status: MessageStatus.sent,
            );
          }
        }
      }
      
      return ChatMessage.assistant(
        content: "I didn't get a proper response. Please try rephrasing your question.",
        status: MessageStatus.error,
      );
    } 
    
    // Handle specific HTTP errors
    debugPrint('🔍 [AIChatService] Parsing response status: ${response.statusCode}');
    switch (response.statusCode) {
      case 400:
        return ChatMessage.assistant(
          content: "I can't answer that type of question. Try asking about English, Computer, Marketing, Web Dev, or YouTube!",
          status: MessageStatus.sent,
        );
      case 403:
        debugPrint('🔍 [AIChatService] 403 Forbidden - API key may have referrer restrictions or invalid model');
        return ChatMessage.assistant(
          content: "ZS Assistant service issue (403). API key may be restricted for web. Please try on mobile app.",
          status: MessageStatus.error,
        );
      case 429:
        return ChatMessage.assistant(
          content: "Service is busy. Please try again in a moment.",
          status: MessageStatus.error,
        );
      default:
        return ChatMessage.assistant(
          content: "Temporary issue (Status ${response.statusCode}). Please try again.",
          status: MessageStatus.error,
        );
    }
  }

  /// Sanitize user input
  String _sanitizeInput(String input) {
    // Trim whitespace
    String sanitized = input.trim();
    
    // Limit length
    if (sanitized.length > 500) {
      sanitized = sanitized.substring(0, 500);
    }
    
    // Remove potentially harmful characters (basic XSS prevention)
    sanitized = sanitized.replaceAll(RegExp(r'[<>]'), '');
    
    return sanitized;
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
