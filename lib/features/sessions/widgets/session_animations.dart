import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Milliseconds between each card's stagger delay.
const kStaggerStep = 30;

/// Duration (ms) for each card's slide + fade animation.
const kSlideDuration = 250;

/// Staggered slide-in animation wrapper.
///
/// Each card slides up from 24 px below its final position, with an
/// opacity fade, delayed by [index] * [kStaggerStep] ms.
///
/// When [animate] is `false`, the child is rendered directly without
/// creating an [AnimationController], avoiding the overhead of dozens
/// of idle controllers in already-visible lists.
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
  AnimationController? _controller;
  Animation<double>? _opacity;
  Animation<Offset>? _slide;

  @override
  void initState() {
    super.initState();
    if (!widget.animate) return;

    final ctrl = AnimationController(
      duration: const Duration(milliseconds: kSlideDuration),
      vsync: this,
    );
    _controller = ctrl;
    _opacity = CurvedAnimation(parent: ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));

    final delayMs = (kStaggerStep * widget.index).clamp(0, 300);
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (mounted && !AppMotion.reduceMotion(context)) ctrl.forward();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return RepaintBoundary(child: widget.child);
    }
    final opacity = _opacity;
    final slide = _slide;
    if (opacity == null || slide == null) {
      return RepaintBoundary(child: widget.child);
    }
    return RepaintBoundary(
      child: FadeTransition(
        opacity: opacity,
        child: SlideTransition(position: slide, child: widget.child),
      ),
    );
  }
}

/// Fade-in for non-card elements (headers).
class FadeInSection extends StatefulWidget {
  const FadeInSection({required this.delay, required this.child, super.key});

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
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    Future.delayed(widget.delay, () {
      if (mounted && !AppMotion.reduceMotion(context)) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return widget.child;
    }
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
