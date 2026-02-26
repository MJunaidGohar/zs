import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/chat_quota_service.dart';
import '../services/floating_button_service.dart';
import '../widgets/floating_chat_button.dart';
import '../screens/chat_screen.dart';

/// Global Chat Overlay
/// Wraps the entire app to provide floating chat button on all screens
/// (except Game and Learning Video screens)
class GlobalChatOverlay extends StatefulWidget {
  final Widget child;
  final ValueNotifier<bool>? showButtonNotifier;

  const GlobalChatOverlay({
    super.key,
    required this.child,
    this.showButtonNotifier,
  });

  @override
  State<GlobalChatOverlay> createState() => _GlobalChatOverlayState();
}

class _GlobalChatOverlayState extends State<GlobalChatOverlay>
    with SingleTickerProviderStateMixin {
  final ChatQuotaService _quotaService = ChatQuotaService();
  final FloatingButtonService _buttonService = FloatingButtonService();

  late AnimationController _chatController;
  late Animation<double> _chatAnimation;
  late Animation<double> _backdropAnimation;

  Offset _chatPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _initServices();
    _initAnimations();
  }

  Future<void> _initServices() async {
    await _buttonService.init();
    await _quotaService.init();
  }

  void _initAnimations() {
    _chatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _chatAnimation = CurvedAnimation(
      parent: _chatController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    _backdropAnimation = CurvedAnimation(
      parent: _chatController,
      curve: Curves.easeInOut,
    );
  }

  void _openChat(Offset buttonPosition) {
    final provider = context.read<ChatProvider>();

    // Don't open if quota exhausted
    if (!provider.hasQuota) {
      _showQuotaExhausted();
      return;
    }

    // Calculate chat position based on button location
    final screenSize = MediaQuery.of(context).size;
    _chatPosition = _calculateChatPosition(buttonPosition, screenSize);

    provider.openChat();
    _chatController.forward();
  }

  void _closeChat() {
    final provider = context.read<ChatProvider>();
    provider.closeChat();
    _chatController.reverse();
  }

  void _toggleChat(Offset buttonPosition) {
    final provider = context.read<ChatProvider>();
    if (provider.isChatOpen) {
      _closeChat();
    } else {
      _openChat(buttonPosition);
    }
  }

  Offset _calculateChatPosition(Offset buttonPos, Size screenSize) {
    const double chatWidth = 360;
    const double chatHeight = 500;
    const double padding = 16;

    // Determine which quadrant the button is in
    final isLeftSide = buttonPos.dx < screenSize.width / 2;
    final isTopSide = buttonPos.dy < screenSize.height / 2;

    double x, y;

    // Horizontal positioning
    if (isLeftSide) {
      x = padding;
    } else {
      x = screenSize.width - chatWidth - padding;
    }

    // Vertical positioning
    if (isTopSide) {
      // Button in top half, open chat below
      y = buttonPos.dy + 70;
    } else {
      // Button in bottom half, open chat above
      y = buttonPos.dy - chatHeight - 20;
    }

    // Clamp to safe area
    x = x.clamp(padding, screenSize.width - chatWidth - padding);
    y = y.clamp(100.0, screenSize.height - chatHeight - padding);

    return Offset(x, y);
  }

  void _showQuotaExhausted() {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Daily quota reached! Come back tomorrow.'),
        backgroundColor: theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: widget.showButtonNotifier ?? ValueNotifier<bool>(true),
          builder: (context, showByRoute, _) {
            // Only show button when: route allows, quota not exhausted, and chat is CLOSED
            final shouldShowButton = showByRoute &&
                !provider.isQuotaExhausted &&
                !provider.isChatOpen;

            return Stack(
              children: [
                // App content - always at bottom
                widget.child,

                // Chat backdrop - only when chat is open
                if (provider.isChatOpen)
                  FadeTransition(
                    opacity: _backdropAnimation,
                    child: GestureDetector(
                      onTap: _closeChat,
                      behavior: HitTestBehavior.opaque, // Block touches to app
                      child: Container(
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ),
                  ),

                // Chat screen - only when chat is open
                if (provider.isChatOpen)
                  AnimatedBuilder(
                    animation: _chatAnimation,
                    builder: (context, child) {
                      return Positioned(
                        left: _chatPosition.dx,
                        top: _chatPosition.dy + (1 - _chatAnimation.value) * 50,
                        child: Opacity(
                          opacity: _chatAnimation.value,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.9, end: 1.0).animate(_chatAnimation),
                            child: Material(
                              type: MaterialType.transparency,
                              child: ChatScreen(onClose: _closeChat),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // Floating button - ONLY when shouldShowButton is true
                // Uses IgnorePointer to let touches pass through to app
                if (shouldShowButton)
                  IgnorePointer(
                    ignoring: false,
                    child: FloatingChatButton(
                      onTap: () {
                        final size = MediaQuery.of(context).size;
                        final pos = _buttonService.getPosition(size.width, size.height);
                        _toggleChat(pos.toOffset());
                      },
                      isVisible: shouldShowButton,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }
}

/// Route observer to hide/show button based on current route
class ChatButtonRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  final ValueNotifier<bool> showButtonNotifier;

  ChatButtonRouteObserver({required this.showButtonNotifier});

  // Routes where chat button should be hidden
  static const hiddenRoutes = [
    '/game',
    '/learning_video',
    '/video_player',
    '/onboarding',
  ];

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _updateVisibility(route);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _updateVisibility(newRoute);
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _updateVisibility(previousRoute);
    }
  }

  void _updateVisibility(Route route) {
    final routeName = route.settings.name;
    final shouldShow = routeName == null || !hiddenRoutes.contains(routeName);
    showButtonNotifier.value = shouldShow;
  }
}
