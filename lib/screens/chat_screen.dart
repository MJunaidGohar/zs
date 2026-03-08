import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/chat_provider.dart';
import '../services/daily_tip_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_header.dart';

/// Chat Screen
/// Main chat interface with App Theme styling
/// Shows messages, input field, and quota indicator
class ChatScreen extends StatefulWidget {
  final VoidCallback onClose;

  const ChatScreen({
    super.key,
    required this.onClose,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final DailyTipService _tipService = DailyTipService();

  @override
  void initState() {
    super.initState();
    _tipService.init();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<ChatProvider>();
    
    if (!provider.hasQuota) {
      _showQuotaExhaustedSnackbar();
      return;
    }

    _messageController.clear();
    provider.sendMessage(text).then((_) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });
  }

  void _showQuotaExhaustedSnackbar() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.onError),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.dailyQuotaReachedMessage),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : theme.colorScheme.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            Consumer<ChatProvider>(
              builder: (context, provider, _) {
                return ChatHeader(
                  onClose: widget.onClose,
                  remainingQuota: provider.remainingQuota,
                );
              },
            ),

            // Daily Tip Banner - only show when chat has no messages
            Consumer<ChatProvider>(
              builder: (context, provider, _) {
                if (provider.messages.isNotEmpty) {
                  return const SizedBox.shrink();
                }
                return _buildTipBanner(theme, isDark);
              },
            ),

            // Messages List
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, _) {
                  final messages = provider.messages;
                  final isLoading = provider.isLoading;

                  if (messages.isEmpty && !isLoading) {
                    return _buildWelcomeView(theme, isDark, l10n);
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length && isLoading) {
                        return const TypingIndicator();
                      }

                      final message = messages[index];
                      final isFirstInGroup = index == 0 ||
                          messages[index - 1].isUser != message.isUser;
                      final isLastInGroup = index == messages.length - 1 ||
                          (index < messages.length - 1 &&
                              messages[index + 1].isUser != message.isUser);

                      return ChatBubble(
                        message: message,
                        isFirstInGroup: isFirstInGroup,
                        isLastInGroup: isLastInGroup,
                      );
                    },
                  );
                },
              ),
            ),

            // Error Message
            Consumer<ChatProvider>(
              builder: (context, provider, _) {
                if (provider.errorMessage == null) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: provider.clearError,
                        child: Icon(
                          Icons.close,
                          color: theme.colorScheme.onErrorContainer,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Input Area
            _buildInputArea(theme, isDark, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildTipBanner(ThemeData theme, bool isDark) {
    final tip = _tipService.getTodayTip();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            tip.icon ?? Icons.lightbulb_outline,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip.tip,
              style: TextStyle(
                color: isDark ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeView(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.welcomeToZSAssistant,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.askYourQuestion,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                l10n.messagesPerDay,
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final hasQuota = context.select<ChatProvider, bool>((p) => p.hasQuota);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    enabled: hasQuota,
                    maxLines: null,
                    minLines: 1,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: hasQuota
                          ? l10n.typeYourQuestion
                          : l10n.dailyQuotaReached,
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
                          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: hasQuota ? _handleSend : null,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hasQuota
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.send,
                      color: hasQuota ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.3),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            
            // Quota indicator
            Consumer<ChatProvider>(
              builder: (context, provider, _) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        provider.isQuotaExhausted
                            ? Icons.info_outline
                            : Icons.chat_bubble_outline,
                        size: 14,
                        color: provider.isQuotaExhausted
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.isQuotaExhausted
                            ? l10n.quotaExhausted
                            : 'Quota: ${provider.quotaDisplay} messages today',
                        style: TextStyle(
                          color: provider.isQuotaExhausted
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
