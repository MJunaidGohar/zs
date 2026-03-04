import 'package:flutter/material.dart';
import '../services/floating_button_service.dart';
import '../services/chat_quota_service.dart';

/// Floating Chat Button
/// A small, draggable floating button that doesn't block screen interactions
/// Positioned absolutely on screen with proper hit testing
class FloatingChatButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isVisible;

  const FloatingChatButton({
    super.key,
    required this.onTap,
    required this.isVisible,
  });

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with SingleTickerProviderStateMixin {
  final FloatingButtonService _buttonService = FloatingButtonService();
  final ChatQuotaService _quotaService = ChatQuotaService();

  Offset _position = Offset.zero;
  bool _isDragging = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Button size - SMALL and non-intrusive
  static const double _buttonSize = 52;
  static const double _padding = 16;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Initialize position after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePosition();
    });
  }

  @override
  void didUpdateWidget(FloatingChatButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _fadeController.forward();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _fadeController.reverse();
    }
  }

  void _initializePosition() {
    try {
      final size = MediaQuery.of(context).size;
      final position = _buttonService.getPosition(size.width, size.height);

      setState(() {
        _position = position.toOffset();
      });
    } catch (e) {
      debugPrint('Button position error: $e');
      // Use default position
      final size = MediaQuery.of(context).size;
      setState(() {
        _position = Offset(
          size.width - _buttonSize - _padding,
          size.height - _buttonSize - _padding - 80,
        );
      });
    }

    if (widget.isVisible) {
      _fadeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Get quota for badge
    final remainingQuota = _quotaService.remainingQuota;
    final showLowQuotaBadge = remainingQuota <= 3 && remainingQuota > 0;

    // Use Stack with tight constraints - only the button size
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: _position.dx,
            top: _position.dy,
            width: _buttonSize,
            height: _buttonSize,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                type: MaterialType.transparency,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _handleTap,
                  onLongPressStart: (_) => setState(() => _isDragging = true),
                  onPanUpdate: _handleDrag,
                  onPanEnd: _handleDragEnd,
                  child: Container(
                    width: _buttonSize,
                    height: _buttonSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withOpacity(0.8)
                              ]
                            : [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withBlue(200)
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Chat icon - smaller
                        const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 24,
                        ),

                        // Low quota badge
                        if (showLowQuotaBadge)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  '$remainingQuota',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDrag(DragUpdateDetails details) {
    final size = MediaQuery.of(context).size;

    setState(() {
      _isDragging = true;
      _position += details.delta;
      // Clamp to screen bounds
      _position = _buttonService.clampPosition(
        _position,
        Size(size.width, size.height),
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) async {
    setState(() => _isDragging = false);

    final size = MediaQuery.of(context).size;

    // Check if near edge and snap
    if (_buttonService.isNearEdge(_position, Size(size.width, size.height))) {
      final snapped =
          _buttonService.snapToEdge(_position, Size(size.width, size.height));

      setState(() {
        _position = snapped;
      });
    }

    // Save position
    await _buttonService.savePosition(_position);
  }

  void _handleTap() {
    debugPrint('Chat button tapped!');
    widget.onTap();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}
