import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
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
  String _category = 'الكل';
  String _specialFilter = 'all';
  final Set<String> _favoriteBusy = {};

  double _discount(ProductModel p) {
    final original = p.originalPrice ?? 0;
    return original > p.price && original > 0 ? (original - p.price) / original : 0;
  }

  void _showFilters(List<String> categories) {
    var localSort = _sort;
    var localCategory = _category;
    var localSpecial = _specialFilter;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setLocal) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              22,
              18,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 26,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext).dividerColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'فلترة وترتيب منتجات المتجر',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(LucideIcons.x, size: 20),
                    ),
                    TextButton(
                      onPressed: () => setLocal(() {
                        localSort = 'relevance';
                        localCategory = 'الكل';
                        localSpecial = 'all';
                      }),
                      child: const Text(
                        'مسح الكل',
                        style: TextStyle(fontSize: 10, color: spikeRed),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _FilterGroup(
                  title: 'الترتيب',
                  children: [
                    _Chip('الأكثر صلة', localSort == 'relevance', () => setLocal(() => localSort = 'relevance')),
                    _Chip('السعر: الأقل أولاً', localSort == 'price-low', () => setLocal(() => localSort = 'price-low')),
                    _Chip('السعر: الأعلى أولاً', localSort == 'price-high', () => setLocal(() => localSort = 'price-high')),
                    _Chip('الأعلى تقييمًا', localSort == 'rating', () => setLocal(() => localSort = 'rating')),
                    _Chip('الأعلى خصمًا', localSort == 'discount', () => setLocal(() => localSort = 'discount')),
                  ],
                ),
                if (categories.isNotEmpty)
                  _FilterGroup(
                    title: 'الفئة',
                    children: [
                      _Chip('الكل', localCategory == 'الكل', () => setLocal(() => localCategory = 'الكل')),
                      for (final category in categories)
                        _Chip(category, localCategory == category, () => setLocal(() => localCategory = category)),
                    ],
                  ),
                _FilterGroup(
                  title: 'نوع المنتجات',
                  children: [
                    _Chip('كل المنتجات', localSpecial == 'all', () => setLocal(() => localSpecial = 'all')),
                    _Chip('العروض فقط', localSpecial == 'offers', () => setLocal(() => localSpecial = 'offers')),
                  ],
                ),
                const SizedBox(height: 5),
                SizedBox(
                  height: 39,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: spikeRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    onPressed: () {
                      setState(() {
                        _sort = localSort;
                        _category = localCategory;
                        _specialFilter = localSpecial;
                      });
                      Navigator.pop(sheetContext);
                    },
                    child: const Text(
                      'عرض النتائج',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(ProductModel p) async {
    if (_favoriteBusy.contains(p.id)) return;
    setState(() => _favoriteBusy.add(p.id));
    final ids = ref.read(wishlistIdsProvider).valueOrNull ?? <String>{};
    final active = ids.contains(p.id);
    try {
      if (active) {
        await ref.read(engagementRepositoryProvider).removeWishlist(p.id);
      } else {
        await ref.read(engagementRepositoryProvider).addWishlist(p.id);
      }
      ref.invalidate(wishlistIdsProvider);
      ref.invalidate(favoritesProvider);
      if (mounted) {
        showSpikeToast(
          context,
          active ? 'تمت إزالة المنتج من المفضلة' : 'تمت إضافة المنتج إلى المفضلة',
        );
      }
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _favoriteBusy.remove(p.id));
    }
  }

  Future<void> _add(ProductModel p) async {
    final v = p.cheapestVariant;
    if (v == null || !p.purchasable) return;
    try {
      await ref.read(cartRepositoryProvider).add(variantId: v.id, product: p);
      ref.invalidate(cartCountProvider);
      if (mounted) showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(storesProvider);
    final products = ref.watch(allProductsProvider);
    final reviewsState = ref.watch(storeReviewsProvider(widget.id));
    final favorites = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: stores.when(
          loading: () => const SpikeLoading(),
          error: (e, _) => SpikeErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(storesProvider),
          ),
          data: (storeList) {
            final matching = storeList.where((s) => s.id == widget.id);
            if (matching.isEmpty) {
              return const SpikeEmptyState(message: 'المتجر غير متاح حالياً');
            }
            final store = matching.first;

            return products.when(
              loading: () => const SpikeLoading(),
              error: (e, _) => SpikeErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(allProductsProvider),
              ),
              data: (all) {
                final storeProducts = all.where((p) => p.storeId == store.id).toList();
                final categories = <String>{
                  for (final p in storeProducts)
                    if ((p.categoryName ?? '').trim().isNotEmpty) p.categoryName!.trim(),
                }.toList()
                  ..sort();

                final q = _query.toLowerCase();
                final list = storeProducts.where((p) {
                  final matchesQuery = q.isEmpty ||
                      p.name.toLowerCase().contains(q) ||
                      (p.categoryName ?? '').toLowerCase().contains(q);
                  final matchesCategory = _category == 'الكل' || p.categoryName == _category;
                  final matchesSpecial = _specialFilter != 'offers' || _discount(p) > 0;
                  return matchesQuery && matchesCategory && matchesSpecial;
                }).toList();

                if (_sort == 'price-low') list.sort((a, b) => a.price.compareTo(b.price));
                if (_sort == 'price-high') list.sort((a, b) => b.price.compareTo(a.price));
                if (_sort == 'rating') list.sort((a, b) => b.rating.compareTo(a.rating));
                if (_sort == 'discount') list.sort((a, b) => _discount(b).compareTo(_discount(a)));

                final storeRating = reviewsState.valueOrNull;
                final rating = double.tryParse('${storeRating?['average'] ?? store.rating}') ?? store.rating;
                final reviewsCount = int.tryParse('${storeRating?['count'] ?? store.reviewCount}') ?? store.reviewCount;
                final reviews = (storeRating?['reviews'] as List? ?? const [])
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(storesProvider);
                    ref.invalidate(allProductsProvider);
                    ref.invalidate(storeReviewsProvider(widget.id));
                    ref.invalidate(wishlistIdsProvider);
                    ref.invalidate(cartCountProvider);
                    await ref.read(allProductsProvider.future);
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
                                    child: IconButton.filledTonal(
                                      onPressed: () => context.canPop() ? context.pop() : context.go('/stores'),
                                      icon: const Icon(Icons.arrow_forward, size: 23),
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
                                        onChanged: (v) => setState(() => _query = v.trim()),
                                        decoration: InputDecoration(
                                          hintText: 'ابحث داخل ${store.name}',
                                          prefixIcon: const Icon(Icons.search, size: 20),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                                        ? Container(color: dark ? Colors.white10 : Colors.black12)
                                        : CachedNetworkImage(
                                            imageUrl: store.bannerUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Container(
                                              color: dark ? Colors.white10 : Colors.black12,
                                            ),
                                          ),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(0, -24),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 17),
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
                                              border: Border.all(color: const Color(0xFFEEEEEE)),
                                            ),
                                            child: store.logoUrl == null
                                                ? const Icon(Icons.storefront_outlined, color: Colors.black)
                                                : CachedNetworkImage(
                                                    imageUrl: store.logoUrl!,
                                                    fit: BoxFit.contain,
                                                    errorWidget: (_, __, ___) => const Icon(
                                                      Icons.storefront_outlined,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    store.name,
                                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  if ((store.categoryName ?? '').isNotEmpty)
                                                    Text(
                                                      store.categoryName!,
                                                      style: const TextStyle(fontSize: 9, color: spikeMuted),
                                                    ),
                                                  const Text(
                                                    'متجر موثوق على Spike',
                                                    style: TextStyle(fontSize: 9, color: spikeMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                            decoration: BoxDecoration(
                                              color: dark ? Colors.white10 : const Color(0xFFF1F1F1),
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5B400)),
                                                const SizedBox(width: 2),
                                                Text(
                                                  reviewsCount > 0 ? rating.toStringAsFixed(1) : '—',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                                if (reviewsCount > 0)
                                                  Text(
                                                    ' ($reviewsCount)',
                                                    style: const TextStyle(fontSize: 9, color: spikeMuted),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(0, -12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 17),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _stat('${storeProducts.length}', 'منتجات'),
                                          _stat('$reviewsCount', 'مراجعات'),
                                          _stat(reviewsCount > 0 ? rating.toStringAsFixed(1) : '—', 'التقييم'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(17, 14, 17, 0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Material(
                                  color: dark ? spikeDarkPanel : const Color(0xFFE8E8E8),
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    onTap: () => _showFilters(categories),
                                    borderRadius: BorderRadius.circular(20),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.slidersHorizontal, size: 16),
                                          SizedBox(width: 6),
                                          Text(
                                            'ترتيب حسب',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (reviews.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(17, 16, 17, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'تقييمات العملاء',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          '${reviews.length} تعليق',
                                          style: const TextStyle(fontSize: 10, color: spikeMuted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...reviews.take(3).map((r) {
                                      final stars = int.tryParse('${r['rating'] ?? 0}') ?? 0;
                                      final comment = '${r['comment'] ?? ''}'.trim();
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: dark ? spikeDarkPanel : spikePanel,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${r['name'] ?? 'عميل'}',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                                  ),
                                                ),
                                                Row(
                                                  children: List.generate(
                                                    5,
                                                    (i) => Icon(
                                                      Icons.star_rounded,
                                                      size: 14,
                                                      color: i < stars
                                                          ? const Color(0xFFF5B400)
                                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: .15),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (comment.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 8),
                                                child: Text(
                                                  comment,
                                                  style: const TextStyle(fontSize: 11, height: 1.45),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(17, 16, 17, 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'منتجات المتجر',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    '${list.length} منتج',
                                    style: const TextStyle(fontSize: 10, color: spikeMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (list.isEmpty)
                        const SliverToBoxAdapter(
                          child: SpikeEmptyState(message: 'لا توجد منتجات مطابقة'),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(17, 0, 17, 24),
                          sliver: SliverGrid.builder(
                            itemCount: list.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 11,
                              mainAxisSpacing: 11,
                              mainAxisExtent: 246,
                            ),
                            itemBuilder: (context, i) {
                              final p = list[i];
                              return SpikeProductCard(
                                product: p,
                                isFavorite: favorites.contains(p.id),
                                onTap: () => context.push('/product/${p.id}'),
                                onAdd: p.purchasable && p.cheapestVariant != null ? () => _add(p) : null,
                                onFavorite: _favoriteBusy.contains(p.id) ? null : () => _toggleFavorite(p),
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

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: spikeMuted)),
        ],
      );
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : spikePanel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 9),
              Wrap(spacing: 8, runSpacing: 8, children: children),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.selected, this.onTap);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? spikeRed
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF24252A)
                    : const Color(0xFFF1F1F1)),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? spikeRed : Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: selected ? Theme.of(context).colorScheme.surface : null,
            ),
          ),
        ),
      );
}
