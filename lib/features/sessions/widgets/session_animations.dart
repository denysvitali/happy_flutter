import 'package:flutter/material.dart';

/// Milliseconds between each card's stagger delay.
const kStaggerStep = 30;

/// Duration (ms) for each card's slide + fade animation.
const kSlideDuration = 250;

/// Staggered slide-in animation wrapper.
///
/// Each card slides up from 24 px below its final position, with an
/// opacity fade, delayed by [index] * [kStaggerStep] ms.
class StaggeredSlideIn extends StatefulWidget {
  const StaggeredSlideIn({
    required this.index,
    required this.animate,
    required this.child,
    super.key,
  });

  final int index;
  final bool animate;
  final Widget child;

  @override
  State<StaggeredSlideIn> createState() => _StaggeredSlideInState();
}

class _StaggeredSlideInState extends State<StaggeredSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: kSlideDuration),
      vsync: this,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.animate) {
      final delayMs =
          (kStaggerStep * widget.index).clamp(0, 300);
      final delay = Duration(milliseconds: delayMs);
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fade-in for non-card elements (headers).
class FadeInSection extends StatefulWidget {
  const FadeInSection({
    required this.delay,
    required this.child,
    super.key,
  });

  final Duration delay;
  final Widget child;

  @override
  State<FadeInSection> createState() => _FadeInSectionState();
}

class _FadeInSectionState extends State<FadeInSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
