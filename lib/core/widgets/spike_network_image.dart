import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:spike_flutter_app/core/api_config.dart';

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
    final value = ApiConfig.resolveMedia((url ?? '').trim());
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
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: const Duration(milliseconds: 80),
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

class SpikeImageShimmer extends StatelessWidget {
  const SpikeImageShimmer({super.key, this.dark = false, this.borderRadius});

  final bool dark;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final base = dark ? const Color(0xFF242428) : const Color(0xFFECECEC);
    final highlight = dark ? const Color(0xFF303036) : const Color(0xFFF6F6F6);
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [base, highlight, base],
            stops: const [0, .5, 1],
          ),
        ),
      ),
    );
  }
}
