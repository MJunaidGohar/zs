import 'package:flutter/material.dart';
import '../services/chat_quota_service.dart';

/// Chat Header Widget
/// App Theme styled header for chat screen with ZS Assistant branding
class ChatHeader extends StatelessWidget {
  final VoidCallback onClose;
  final int remainingQuota;

  const ChatHeader({
    super.key,
    required this.onClose,
    required this.remainingQuota,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : theme.colorScheme.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Close button
            GestureDetector(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? theme.colorScheme.onSurface : Colors.white)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: isDark ? theme.colorScheme.onSurface : Colors.white,
                  size: 20,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [theme.colorScheme.primary, theme.colorScheme.primaryContainer]
                      : [Colors.white.withOpacity(0.9), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.school,
                  color: isDark ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                  size: 24,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ZS Assistant',
                    style: TextStyle(
                      color: isDark ? theme.colorScheme.onSurface : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Your Educational Companion',
                    style: TextStyle(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Quota badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getQuotaColor(remainingQuota).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getQuotaColor(remainingQuota).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: _getQuotaColor(remainingQuota),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$remainingQuota/${ChatQuotaService.maxDailyMessages}',
                    style: TextStyle(
                      color: _getQuotaColor(remainingQuota),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getQuotaColor(int quota) {
    if (quota <= 3) return Colors.red;
    if (quota <= 8) return Colors.orange;
    return Colors.green;
  }
}
