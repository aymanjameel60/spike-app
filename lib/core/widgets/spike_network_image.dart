import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SpikeNetworkImage extends StatelessWidget {
  const SpikeNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final value = (url ?? '').trim();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fallback = Icon(
      LucideIcons.image,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .18),
    );

    Widget child;
    if (value.isEmpty) {
      child = Center(child: fallback);
    } else {
      child = CachedNetworkImage(
        imageUrl: value,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fadeInDuration: const Duration(milliseconds: 180),
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => SpikeImageShimmer(dark: dark),
        errorWidget: (_, __, ___) => Center(child: fallback),
      );
    }

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return SizedBox(width: width, height: height, child: child);
  }
}

class SpikeImageShimmer extends StatefulWidget {
  const SpikeImageShimmer({super.key, this.dark = false, this.borderRadius});

  final bool dark;
  final BorderRadius? borderRadius;

  @override
  State<SpikeImageShimmer> createState() => _SpikeImageShimmerState();
}

class _SpikeImageShimmerState extends State<SpikeImageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.dark ? const Color(0xFF242428) : const Color(0xFFECECEC);
    final highlight = widget.dark ? const Color(0xFF34343A) : const Color(0xFFF8F8F8);
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.6 + (_controller.value * 3.2), 0),
                end: Alignment(-.6 + (_controller.value * 3.2), 0),
                colors: [base, highlight, base],
                stops: const [0.25, 0.5, 0.75],
              ),
            ),
          );
        },
      ),
    );
  }
}
