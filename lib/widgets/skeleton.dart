import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';

/// A neutral placeholder block used while content loads.
///
/// Preferred over a centred spinner whenever the shape of the incoming content
/// is known, because the layout stops jumping when the real data lands.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (MediaQuery.maybeOf(context)?.disableAnimations != true) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = widget.borderRadius ?? BorderRadius.circular(AppRadii.chip);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              scheme.surfaceContainerHigh,
              scheme.surfaceContainerHighest,
              _controller.value,
            ),
            borderRadius: radius,
          ),
        );
      },
    );
  }
}

/// A skeleton shaped like one row of the Bluetooth device list.
class SkeletonDeviceTile extends StatelessWidget {
  const SkeletonDeviceTile({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          SkeletonBox(
            width: 44,
            height: 44,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SkeletonBox(width: 140, height: 14),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: 90,
                  height: 12,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder rows shown while a scan is starting up.
class SkeletonDeviceList extends StatelessWidget {
  const SkeletonDeviceList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: count,
      itemBuilder: (_, __) => const SkeletonDeviceTile(),
    );
  }
}
