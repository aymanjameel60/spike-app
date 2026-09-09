import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme.dart';
import '../models/product.dart';

class SpikeProductCard extends StatelessWidget {
  const SpikeProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAdd,
    this.onFavorite,
    this.onStore,
    this.isFavorite = false,
  });

  final ProductModel product;
  final VoidCallback? onTap, onAdd, onFavorite, onStore;
  final bool isFavorite;

  String _money(double amount, String currency) {
    final c = currency.toUpperCase();
    if (c == 'USD') return '\$${amount.toStringAsFixed(2)}';
    if (c == 'SAR') return '${amount.toStringAsFixed(2)} ر.س';
    if (c.startsWith('YER')) return '${amount.round()} ر.ي';
    if (c == 'TRY') return '${amount.toStringAsFixed(2)} ₺';
    return '${amount.toStringAsFixed(2)} $c';
  }

  @override
  Widget build(BuildContext context) {
    final old = product.originalPrice;
    final current = product.price;
    final hasDiscount = old != null && old > current && current > 0;
    final discount = hasDiscount ? ((1 - current / old) * 100).round() : 0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? spikeDarkPanel : spikeProductCard;
    final imageColor = dark ? Theme.of(context).colorScheme.surface : Colors.white;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: 154,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(SpikeRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Container(
                    height: 134,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: imageColor,
                      borderRadius: BorderRadius.circular(SpikeRadius.card),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: product.imageUrl == null
                        ? Center(child: Icon(LucideIcons.image, size: 38, color: textColor.withValues(alpha:.18)))
                        : CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.contain,
                            memCacheWidth: 320,
                            memCacheHeight: 280,
                            maxWidthDiskCache: 640,
                            maxHeightDiskCache: 560,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholder: (_, __) => Container(color: imageColor),
                            errorWidget: (_, __, ___) => Icon(LucideIcons.image, color: textColor.withValues(alpha:.18)),
                          ),
                  ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: _CircleButton(
                      icon: isFavorite ? Icons.favorite_rounded : LucideIcons.heart,
                      onTap: onFavorite,
                      foreground: isFavorite ? spikeRed : Colors.black,
                    ),
                  ),
                  if (discount > 0)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: spikeRed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '-$discount%',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, height: 1),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _CircleButton(
                      icon: LucideIcons.plus,
                      onTap: product.purchasable ? onAdd : null,
                      background: product.purchasable ? Colors.black : Colors.black26,
                      foreground: Colors.white,
                      border: false,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.45),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: current > 0
                    ? (hasDiscount
                        ? Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _money(current, product.currency),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  _money(old, product.currency),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: spikeMuted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _money(current, product.currency),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ))
                    : const Text(
                        'السعر غير متاح',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, color: spikeMuted, fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 0, 11, 10),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF5B400)),
                          const SizedBox(width: 3),
                          Text(
                            product.reviewCount > 0 ? product.rating.toStringAsFixed(1) : '—',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          if (product.reviewCount > 0)
                            Text(' (${product.reviewCount})', style: const TextStyle(fontSize: 10, color: spikeMuted, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Flexible(
                        child: GestureDetector(
                          onTap: onStore,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            product.storeName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: spikeMuted, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    this.onTap,
    this.background = Colors.white,
    this.foreground = Colors.black,
    this.border = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color background, foreground;
  final bool border;

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        shape: CircleBorder(
          side: BorderSide(color: border && onTap != null ? const Color(0xFFE5E5E5) : Colors.transparent),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 35, height: 35, child: Icon(icon, size: 19, color: foreground)),
        ),
      );
}
