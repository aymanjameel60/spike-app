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
  String _category = 'الكل';
  final Set<String> _favoriteBusy = {};

  double _discount(ProductModel p) {
    final original = p.originalPrice ?? 0;
    return original > p.price && original > 0 ? (original - p.price) / original : 0;
  }

  void _showSort() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 20, 17, 25),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('الترتيب حسب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(LucideIcons.x, size: 20)),
            ]),
            const SizedBox(height: 10),
            for (final option in const [
              ('relevance', 'الأكثر صلة'),
              ('price-low', 'السعر: من الأقل للأعلى'),
              ('price-high', 'السعر: من الأعلى للأقل'),
              ('rating', 'الأعلى تقييماً'),
              ('discount', 'الأعلى خصماً'),
            ])
              InkWell(
                onTap: () {
                  setState(() => _sort = option.$1);
                  Navigator.pop(sheetContext);
                },
                child: SizedBox(
                  height: 48,
                  child: Row(children: [
                    Expanded(child: Text(option.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    Icon(_sort == option.$1 ? Icons.radio_button_checked : Icons.radio_button_off, size: 19),
                  ]),
                ),
              ),
          ]),
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
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final favorites = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    final chips = <String>['الكل', ...categories.map((e) => e.name), 'عروض'];
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
                    onTap: _showSort,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.slidersHorizontal, size: 16), SizedBox(width: 6), Text('ترتيب حسب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(17, 8, 17, 14),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: chips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final item = chips[i];
                  final active = _category == item;
                  return InkWell(
                    onTap: () => setState(() => _category = item),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? spikeRed : (dark ? const Color(0xFF24252A) : const Color(0xFFE8E8E8)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? spikeRed : Theme.of(context).dividerColor),
                      ),
                      child: Text(item, style: TextStyle(fontSize: 12, color: active ? Theme.of(context).colorScheme.surface : null)),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const SpikeLoading(),
              error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(productsProvider((widget.categoryId, widget.collectionId)))),
              data: (products) {
                final list = products.where((p) {
                  if (_category == 'الكل') return true;
                  if (_category == 'عروض') return _discount(p) > 0;
                  return p.categoryName == _category;
                }).toList();
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
