import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';

/// Wraps a child so it shrinks slightly while held down.
///
/// The feedback is the point: on a terminal being tapped dozens of times an
/// hour, a control that gives nothing back reads as unresponsive, and one that
/// bounces reads as a toy. A 4% scale over 150ms lands in between.
///
/// Honours the platform's reduced-motion setting, where the press produces no
/// animation at all.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = AppMotion.pressScale,
    this.enabled = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;
  final String? semanticLabel;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget content = widget.child;
    if (widget.semanticLabel != null) {
      content = Semantics(
        button: true,
        enabled: _interactive,
        label: widget.semanticLabel,
        excludeSemantics: true,
        child: content,
      );
    }

    if (!_interactive) return content;

    return AnimatedScale(
      scale: _pressed && !reduceMotion ? widget.scale : 1.0,
      duration: reduceMotion ? Duration.zero : AppMotion.fast,
      curve: AppMotion.curve,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: content,
      ),
    );
  }
}
