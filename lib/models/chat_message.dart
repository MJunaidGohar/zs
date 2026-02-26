import 'package:flutter/material.dart';

/// Chat Message Model
/// Represents a single message in the chat conversation
/// Stored in memory only (no persistence as per requirements)
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });

  /// Create a user message
  factory ChatMessage.user({
    required String content,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: timestamp ?? DateTime.now(),
      status: MessageStatus.sent,
    );
  }

  /// Create an AI (ZS Assistant) message
  factory ChatMessage.assistant({
    required String content,
    DateTime? timestamp,
    MessageStatus status = MessageStatus.sending,
  }) {
    return ChatMessage(
      id: 'zs_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      isUser: false,
      timestamp: timestamp ?? DateTime.now(),
      status: status,
    );
  }

  /// Copy with modified fields
  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'ChatMessage{id: $id, isUser: $isUser, status: $status, content: ${content.substring(0, content.length > 20 ? 20 : content.length)}...}';
  }
}

/// Message Status Enum
enum MessageStatus {
  sending,
  sent,
  error,
}

/// Extension for MessageStatus
extension MessageStatusExtension on MessageStatus {
  String get displayName {
    switch (this) {
      case MessageStatus.sending:
        return 'Sending...';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.error:
        return 'Error';
    }
  }

  bool get isLoading => this == MessageStatus.sending;
}
