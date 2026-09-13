import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme.dart';
import '../core/widgets/spike_network_image.dart';
import '../models/product.dart';

class SpikeProductCard extends StatefulWidget {
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

  @override
  State<SpikeProductCard> createState() => _SpikeProductCardState();
}

class _SpikeProductCardState extends State<SpikeProductCard> {
  late final PageController _galleryController;
  int _galleryIndex = 0;

  ProductModel get product => widget.product;

  @override
  void initState() {
    super.initState();
    _galleryController = PageController();
  }

  @override
  void didUpdateWidget(covariant SpikeProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _galleryIndex = 0;
      if (_galleryController.hasClients) {
        _galleryController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  String _money(double amount, String currency) {
    final c = currency.toUpperCase();
    if (c == 'USD') return '\$${amount.toStringAsFixed(2)}';
    if (c == 'SAR') return '${amount.toStringAsFixed(2)} ر.س';
    if (c.startsWith('YER')) return '${amount.round()} ر.ي';
    if (c == 'TRY') return '${amount.toStringAsFixed(2)} ₺';
    return '${amount.toStringAsFixed(2)} $c';
  }

  List<String> _gallery() {
    final values = <String>[];
    for (final value in product.images) {
      final normalized = value.trim();
      if (normalized.isNotEmpty && !values.contains(normalized)) {
        values.add(normalized);
      }
    }
    final primary = product.imageUrl?.trim() ?? '';
    if (primary.isNotEmpty && !values.contains(primary)) values.insert(0, primary);
    return values;
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
    final gallery = _gallery();

    return SizedBox(
      width: 154,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(SpikeRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
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
                    child: gallery.length <= 1
                        ? SpikeNetworkImage(
                            url: gallery.isEmpty ? product.imageUrl : gallery.first,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: 134,
                            memCacheWidth: 320,
                            memCacheHeight: 280,
                          )
                        : PageView.builder(
                            controller: _galleryController,
                            itemCount: gallery.length,
                            onPageChanged: (index) {
                              if (mounted) setState(() => _galleryIndex = index);
                            },
                            itemBuilder: (_, index) => SpikeNetworkImage(
                              url: gallery[index],
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: 134,
                              memCacheWidth: 320,
                              memCacheHeight: 280,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: _CircleButton(
                      icon: widget.isFavorite
                          ? Icons.favorite_rounded
                          : LucideIcons.heart,
                      onTap: widget.onFavorite,
                      foreground: widget.isFavorite ? spikeRed : Colors.black,
                    ),
                  ),
                  if (discount > 0)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: spikeRed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '-$discount%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _CircleButton(
                      icon: LucideIcons.plus,
                      onTap: product.purchasable ? widget.onAdd : null,
                      background:
                          product.purchasable ? Colors.black : Colors.black26,
                      foreground: Colors.white,
                      border: false,
                    ),
                  ),
                  if (gallery.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: IgnorePointer(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            gallery.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: index == _galleryIndex ? 13 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: index == _galleryIndex
                                    ? const Color(0xFF9C9C9C)
                                    : const Color(0xFFD1D1D1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ))
                    : const Text(
                        'السعر غير متاح',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: spikeMuted,
                          fontWeight: FontWeight.w700,
                        ),
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
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: Color(0xFFF5B400),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            product.reviewCount > 0
                                ? product.rating.toStringAsFixed(1)
                                : '—',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (product.reviewCount > 0)
                            Text(
                              ' (${product.reviewCount})',
                              style: const TextStyle(
                                fontSize: 10,
                                color: spikeMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      Flexible(
                        child: GestureDetector(
                          onTap: widget.onStore,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            product.storeName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              color: spikeMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
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
          side: BorderSide(
            color: border && onTap != null
                ? const Color(0xFFE5E5E5)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 35,
            height: 35,
            child: Icon(icon, size: 19, color: foreground),
          ),
        ),
      );
}
