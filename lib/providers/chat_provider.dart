import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';
import '../services/chat_quota_service.dart';

/// Chat Provider
/// Manages chat state, messages, and quota
/// Optimized for performance with proper state updates
class ChatProvider extends ChangeNotifier {
  // Services
  final AIChatService _aiService = AIChatService();
  final ChatQuotaService _quotaService = ChatQuotaService();
  
  // State
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isChatOpen = false;
  
  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isChatOpen => _isChatOpen;
  
  // Quota getters (proxied from service)
  int get remainingQuota => _quotaService.remainingQuota;
  int get usedMessages => _quotaService.usedMessages;
  bool get hasQuota => _quotaService.hasQuota;
  bool get isQuotaExhausted => _quotaService.isExhausted;
  double get quotaPercentage => _quotaService.quotaPercentage;
  QuotaStatus get quotaStatus => _quotaService.status;
  String get quotaDisplay => _quotaService.quotaDisplay;
  
  /// Initialize provider
  Future<void> init() async {
    await _quotaService.init();
    notifyListeners();
  }
  
  /// Open chat
  void openChat() {
    _isChatOpen = true;
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Close chat
  void closeChat() {
    _isChatOpen = false;
    // Clear messages when closing (as per requirements - no history)
    _messages.clear();
    notifyListeners();
  }
  
  /// Toggle chat
  void toggleChat() {
    if (_isChatOpen) {
      closeChat();
    } else {
      openChat();
    }
  }
  
  /// Send message
  Future<void> sendMessage(String text) async {
    // Validate input
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;
    
    // Check quota
    if (!hasQuota) {
      _errorMessage = 'Daily quota exhausted. Try again tomorrow!';
      notifyListeners();
      return;
    }
    
    // Add user message
    final userMessage = ChatMessage.user(content: trimmedText);
    _messages.add(userMessage);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    // Decrement quota
    final quotaDecremented = await _quotaService.decrementQuota();
    if (!quotaDecremented) {
      _isLoading = false;
      _errorMessage = 'Unable to send message. Quota issue.';
      notifyListeners();
      return;
    }
    
    // Get AI response
    try {
      final aiMessage = await _aiService.generateResponse(trimmedText);
      
      _isLoading = false;
      
      if (aiMessage.status == MessageStatus.error) {
        _errorMessage = aiMessage.content;
      } else {
        _messages.add(aiMessage);
      }
      
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to get response. Please try again.';
      notifyListeners();
    }
  }
  
  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Get welcome message (for empty state)
  String get welcomeMessage {
    return "👋 Hi! I'm your ZS Assistant.\n\nAsk me anything about:\n• English\n• Computer\n• Digital Marketing\n• Web Development\n• YouTube\n\n💡 Tip: Be specific for better answers!";
  }
  
  /// Check if quota just ran out (for button disappearance animation)
  bool _wasQuotaAvailable = true;
  
  bool get shouldButtonDisappear {
    final shouldDisappear = isQuotaExhausted && _wasQuotaAvailable;
    _wasQuotaAvailable = !isQuotaExhausted;
    return shouldDisappear;
  }
  
  /// Refresh quota status
  void refreshQuota() {
    notifyListeners();
  }
  
  @override
  void dispose() {
    _aiService.dispose();
    _quotaService.dispose();
    super.dispose();
  }
}
