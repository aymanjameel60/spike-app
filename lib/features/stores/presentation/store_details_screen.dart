import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../core/widgets/spike_network_image.dart';
import '../../../models/product.dart';
import '../../../widgets/product_card.dart';

class StoreDetailsScreen extends ConsumerStatefulWidget {
  const StoreDetailsScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends ConsumerState<StoreDetailsScreen> {
  String _query = '';
  String _sort = 'relevance';
  bool _followed = false;
  final Set<String> _favoriteBusy = {};

  double _discount(ProductModel product) {
    final original = product.originalPrice ?? 0;
    return original > product.price && original > 0
        ? (original - product.price) / original
        : 0;
  }

  void _showSort() {
    const options = <(String, String)>[
      ('relevance', 'الترتيب الافتراضي'),
      ('rating', 'الأعلى تقييماً'),
      ('price-low', 'السعر: الأقل أولاً'),
      ('price-high', 'السعر: الأعلى أولاً'),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ترتيب منتجات المتجر',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.pop(sheetContext),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(LucideIcons.x, size: 19, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final option in options)
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: option.$1,
                  groupValue: _sort,
                  title: Text(option.$2, style: const TextStyle(fontSize: 14)),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sort = value);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(ProductModel product) async {
    if (_favoriteBusy.contains(product.id)) return;
    setState(() => _favoriteBusy.add(product.id));
    final ids = ref.read(wishlistIdsProvider).valueOrNull ?? <String>{};
    final active = ids.contains(product.id);
    try {
      if (active) {
        await ref.read(engagementRepositoryProvider).removeWishlist(product.id);
      } else {
        await ref.read(engagementRepositoryProvider).addWishlist(product.id);
      }
      ref.invalidate(wishlistIdsProvider);
      ref.invalidate(favoritesProvider);
      if (mounted) {
        showSpikeToast(
          context,
          active ? 'تمت إزالة المنتج من المفضلة' : 'تمت إضافة المنتج إلى المفضلة',
        );
      }
    } catch (error) {
      if (mounted) showSpikeToast(context, error.toString());
    } finally {
      if (mounted) setState(() => _favoriteBusy.remove(product.id));
    }
  }

  Future<void> _add(ProductModel product) async {
    final variant = product.cheapestVariant;
    if (variant == null || !product.purchasable) return;
    try {
      await ref.read(cartRepositoryProvider).add(
            variantId: variant.id,
            product: product,
          );
      ref.invalidate(cartCountProvider);
      if (mounted) showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
    } catch (error) {
      if (mounted) showSpikeToast(context, error.toString());
    }
  }

  List<ProductModel> _visible(List<ProductModel> source) {
    final query = _query.trim().toLowerCase();
    final list = source.where((product) {
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          (product.categoryName ?? '').toLowerCase().contains(query);
    }).toList();

    if (_sort == 'price-low') {
      list.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sort == 'price-high') {
      list.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sort == 'rating') {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(storesProvider);
    final products = ref.watch(storeProductsProvider(widget.id));
    final reviewsState = ref.watch(storeReviewsProvider(widget.id));
    final favorites = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: stores.when(
          loading: () => const SpikeLoading(),
          error: (error, _) => SpikeErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(storesProvider),
          ),
          data: (storeList) {
            final matching = storeList.where((store) => store.id == widget.id);
            if (matching.isEmpty) {
              return const SpikeEmptyState(message: 'المتجر غير متاح حالياً');
            }
            final store = matching.first;

            return products.when(
              loading: () => const SpikeLoading(),
              error: (error, _) => SpikeErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(storeProductsProvider(widget.id)),
              ),
              data: (storeProducts) {
                final list = _visible(storeProducts);
                final storeRating = reviewsState.valueOrNull;
                final rating = double.tryParse(
                      '${storeRating?['average'] ?? store.rating}',
                    ) ??
                    store.rating;
                final reviewsCount = int.tryParse(
                      '${storeRating?['count'] ?? store.reviewCount}',
                    ) ??
                    store.reviewCount;

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(storesProvider);
                    ref.invalidate(storeProductsProvider(widget.id));
                    ref.invalidate(storeReviewsProvider(widget.id));
                    ref.invalidate(wishlistIdsProvider);
                    ref.invalidate(cartCountProvider);
                    await ref.read(storeProductsProvider(widget.id).future);
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 50,
                                    height: 42,
                                    child: Material(
                                      color: dark ? spikeDarkPanel : spikeField,
                                      borderRadius: BorderRadius.circular(22),
                                      child: InkWell(
                                        onTap: () => context.canPop()
                                            ? context.pop()
                                            : context.go('/stores'),
                                        borderRadius: BorderRadius.circular(22),
                                        child: const Icon(
                                          LucideIcons.arrowRight,
                                          size: 23,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Container(
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: dark ? spikeDarkPanel : spikeField,
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: TextField(
                                        onChanged: (value) =>
                                            setState(() => _query = value),
                                        decoration: InputDecoration(
                                          hintText: 'ابحث داخل ${store.name}',
                                          prefixIcon: const Icon(
                                            LucideIcons.search,
                                            size: 20,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              color: dark ? spikeDarkPanel : Colors.white,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 185,
                                    width: double.infinity,
                                    child: store.bannerUrl == null
                                        ? Container(
                                            color: dark
                                                ? Colors.white10
                                                : Colors.black12,
                                          )
                                        : SpikeNetworkImage(
                                            url: store.bannerUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 185,
                                          ),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(0, -24),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 17,
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            width: 70,
                                            height: 70,
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFFEEEEEE),
                                              ),
                                            ),
                                            child: store.logoUrl == null
                                                ? const Icon(
                                                    LucideIcons.store,
                                                    color: Colors.black,
                                                  )
                                                : SpikeNetworkImage(
                                                    url: store.logoUrl,
                                                    fit: BoxFit.cover,
                                                    width: 70,
                                                    height: 70,
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          store.name,
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                      if (store.isVerified) ...[
                                                        const SizedBox(width: 4),
                                                        const Icon(
                                                          LucideIcons.badgeCheck,
                                                          size: 15,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    store.isVerified
                                                        ? 'متجر موثوق على Spike'
                                                        : 'متجر على Spike',
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      color: spikeMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Material(
                                            color: _followed
                                                ? (dark
                                                    ? Colors.white
                                                    : Colors.black)
                                                : (dark
                                                    ? Colors.white10
                                                    : const Color(0xFFF1F1F1)),
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            child: InkWell(
                                              onTap: () => setState(
                                                () => _followed = !_followed,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _followed
                                                          ? LucideIcons.check
                                                          : LucideIcons.plus,
                                                      size: 17,
                                                      color: _followed
                                                          ? (dark
                                                              ? Colors.black
                                                              : Colors.white)
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _followed
                                                          ? 'متابَع'
                                                          : 'متابعة',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: _followed
                                                            ? (dark
                                                                ? Colors.black
                                                                : Colors.white)
                                                            : null,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(0, -10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 17,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _stat(
                                            '${storeProducts.length}',
                                            'منتجات',
                                          ),
                                          _stat('$reviewsCount', 'مراجعات'),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                reviewsCount > 0
                                                    ? rating.toStringAsFixed(1)
                                                    : '—',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                              const Icon(
                                                Icons.star_rounded,
                                                size: 15,
                                                color: Color(0xFFF5B400),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(17, 16, 17, 12),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'منتجات المتجر',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _toolButton(
                                    icon: LucideIcons.share2,
                                    tooltip: 'مشاركة',
                                    onTap: () => Share.share(store.name),
                                  ),
                                  const SizedBox(width: 8),
                                  _toolButton(
                                    icon: LucideIcons.arrowUpDown,
                                    tooltip: 'ترتيب حسب',
                                    onTap: _showSort,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (list.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: 18),
                            child: SpikeEmptyState(
                              message: 'لا توجد منتجات مطابقة',
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(17, 0, 17, 24),
                          sliver: SliverGrid.builder(
                            itemCount: list.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 11,
                              mainAxisSpacing: 11,
                              mainAxisExtent: 246,
                            ),
                            itemBuilder: (context, index) {
                              final product = list[index];
                              return SpikeProductCard(
                                product: product,
                                isFavorite: favorites.contains(product.id),
                                onTap: () =>
                                    context.push('/product/${product.id}'),
                                onAdd: product.purchasable &&
                                        product.cheapestVariant != null
                                    ? () => _add(product)
                                    : null,
                                onFavorite:
                                    _favoriteBusy.contains(product.id)
                                        ? null
                                        : () => _toggleFavorite(product),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: dark ? spikeDarkPanel : const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 39,
            height: 39,
            child: Icon(icon, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: spikeMuted),
          ),
        ],
      );
}
