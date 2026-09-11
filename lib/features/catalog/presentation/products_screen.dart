import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../models/product.dart';
import '../../../widgets/product_card.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key, this.categoryId, this.collectionId, this.title = 'المنتجات'});

  final String? categoryId;
  final String? collectionId;
  final String title;

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _sort = 'relevance';
  String _specialFilter = 'all';
  final Set<String> _favoriteBusy = {};

  double _discount(ProductModel p) {
    final original = p.originalPrice ?? 0;
    return original > p.price && original > 0 ? (original - p.price) / original : 0;
  }

  String _productsLocation({String? categoryId, required String title}) {
    final params = <String, String>{'title': title};
    if (categoryId != null && categoryId.isNotEmpty) params['category'] = categoryId;
    if ((widget.collectionId ?? '').isNotEmpty) params['collection'] = widget.collectionId!;
    return Uri(path: '/products', queryParameters: params).toString();
  }

  void _showFilters() {
    final categories = ref.read(categoriesProvider).valueOrNull ?? const [];
    var localSort = _sort;
    var localSpecial = _specialFilter;
    String? localCategoryId = widget.categoryId;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setLocal) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 22, 18, MediaQuery.viewInsetsOf(sheetContext).bottom + 26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: Theme.of(sheetContext).dividerColor, borderRadius: BorderRadius.circular(5)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Text('فلترة وترتيب المنتجات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(LucideIcons.x, size: 20)),
                TextButton(
                  onPressed: () => setLocal(() {
                    localSort = 'relevance';
                    localSpecial = 'all';
                    localCategoryId = null;
                  }),
                  child: const Text('مسح الكل', style: TextStyle(fontSize: 10, color: spikeRed)),
                ),
              ]),
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
                    _Chip('الكل', localCategoryId == null, () => setLocal(() => localCategoryId = null)),
                    for (final category in categories)
                      _Chip(category.name, localCategoryId == category.id, () => setLocal(() => localCategoryId = category.id)),
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
                  style: FilledButton.styleFrom(backgroundColor: spikeRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                  onPressed: () {
                    final selectedCategory = categories.where((c) => c.id == localCategoryId).firstOrNull;
                    setState(() {
                      _sort = localSort;
                      _specialFilter = localSpecial;
                    });
                    Navigator.pop(sheetContext);
                    if (localCategoryId != widget.categoryId) {
                      final title = selectedCategory?.name ?? (widget.collectionId == null ? 'المنتجات' : widget.title);
                      context.go(_productsLocation(categoryId: localCategoryId, title: title));
                    }
                  },
                  child: const Text('عرض النتائج', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
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
      if (mounted) showSpikeToast(context, active ? 'تمت إزالة المنتج من المفضلة' : 'تمت إضافة المنتج إلى المفضلة');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _favoriteBusy.remove(p.id));
    }
  }

  Future<void> _add(ProductModel p) async {
    final variant = p.cheapestVariant;
    if (variant == null || !p.purchasable) return;
    try {
      await ref.read(cartRepositoryProvider).add(variantId: variant.id, product: p);
      ref.invalidate(cartCountProvider);
      if (mounted) showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
    } catch (e) {
      if (mounted) showSpikeToast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider((widget.categoryId, widget.collectionId)));
    final favorites = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Row(children: [
                SizedBox(
                  width: 50,
                  height: 40,
                  child: Material(
                    color: dark ? spikeDarkPanel : const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => context.canPop() ? context.pop() : context.go('/'),
                      child: const Icon(LucideIcons.arrowRight, size: 23),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(widget.title, maxLines: 1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                Material(
                  color: dark ? spikeDarkPanel : const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _showFilters,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.slidersHorizontal, size: 16),
                        SizedBox(width: 6),
                        Text('ترتيب حسب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const SpikeLoading(),
              error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(productsProvider((widget.categoryId, widget.collectionId)))),
              data: (products) {
                final list = products.where((p) => _specialFilter != 'offers' || _discount(p) > 0).toList();
                if (_sort == 'price-low') list.sort((a, b) => a.price.compareTo(b.price));
                if (_sort == 'price-high') list.sort((a, b) => b.price.compareTo(a.price));
                if (_sort == 'rating') list.sort((a, b) => b.rating.compareTo(a.rating));
                if (_sort == 'discount') list.sort((a, b) => _discount(b).compareTo(_discount(a)));
                if (list.isEmpty) return const SpikeEmptyState(message: 'لا توجد منتجات في هذا القسم حالياً');

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(17, 4, 17, 24),
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
                      onStore: p.storeId == null ? null : () => context.push('/store/${p.storeId}'),
                      onAdd: p.purchasable && p.cheapestVariant != null ? () => _add(p) : null,
                      onFavorite: _favoriteBusy.contains(p.id) ? null : () => _toggleFavorite(p),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 9),
            Wrap(spacing: 8, runSpacing: 8, children: children),
          ]),
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
            color: selected ? spikeRed : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF24252A) : const Color(0xFFF1F1F1)),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: selected ? spikeRed : Theme.of(context).dividerColor),
          ),
          child: Text(label, style: TextStyle(fontSize: 10, color: selected ? Theme.of(context).colorScheme.surface : null)),
        ),
      );
}
