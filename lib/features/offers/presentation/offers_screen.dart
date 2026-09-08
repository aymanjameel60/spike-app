import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../models/product.dart';
import '../../../widgets/product_card.dart';

class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key});

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  String sort = 'discount_desc';
  int minDiscount = 0;
  String price = 'all';
  double minRating = 0;
  final Set<String> _favoriteBusy = {};

  int _discount(ProductModel p) {
    final o = p.originalPrice;
    final c = p.price;
    if (o == null || o <= c || c <= 0) return 0;
    return ((o - c) / o * 100).round();
  }

  List<ProductModel> _apply(List<ProductModel> all) {
    var x = all.where((p) => _discount(p) > 0).toList();
    if (minDiscount > 0) x = x.where((p) => _discount(p) >= minDiscount).toList();
    if (price == 'under5') x = x.where((p) => p.price < 5).toList();
    if (price == '5to25') x = x.where((p) => p.price >= 5 && p.price <= 25).toList();
    if (price == 'over25') x = x.where((p) => p.price > 25).toList();
    if (minRating > 0) x = x.where((p) => p.rating >= minRating).toList();
    if (sort == 'newest') {
      x.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    } else if (sort == 'price_asc') {
      x.sort((a, b) => a.price.compareTo(b.price));
    } else if (sort == 'price_desc') {
      x.sort((a, b) => b.price.compareTo(a.price));
    } else if (sort == 'rating_desc') {
      x.sort((a, b) => b.rating.compareTo(a.rating));
    } else {
      x.sort((a, b) => _discount(b).compareTo(_discount(a)));
    }
    return x;
  }

  void _reset() {
    setState(() {
      sort = 'discount_desc';
      minDiscount = 0;
      price = 'all';
      minRating = 0;
    });
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

  void _filters() {
    var localSort = sort;
    var localDiscount = minDiscount;
    var localPrice = price;
    var localRating = minRating;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setLocal) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 22, 18, MediaQuery.viewInsetsOf(sheetContext).bottom + 26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Theme.of(sheetContext).dividerColor, borderRadius: BorderRadius.circular(5)))),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Text('فلترة وترتيب العروض', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(LucideIcons.x, size: 20)),
                TextButton(
                  onPressed: () => setLocal(() {
                    localSort = 'discount_desc';
                    localDiscount = 0;
                    localPrice = 'all';
                    localRating = 0;
                  }),
                  child: const Text('مسح الكل', style: TextStyle(fontSize: 10, color: spikeRed)),
                ),
              ]),
              const SizedBox(height: 14),
              _FilterGroup(
                title: 'الترتيب',
                children: [
                  _Chip('أعلى خصم', localSort == 'discount_desc', () => setLocal(() => localSort = 'discount_desc')),
                  _Chip('الأحدث', localSort == 'newest', () => setLocal(() => localSort = 'newest')),
                  _Chip('السعر: الأقل أولاً', localSort == 'price_asc', () => setLocal(() => localSort = 'price_asc')),
                  _Chip('السعر: الأعلى أولاً', localSort == 'price_desc', () => setLocal(() => localSort = 'price_desc')),
                  _Chip('الأعلى تقييمًا', localSort == 'rating_desc', () => setLocal(() => localSort = 'rating_desc')),
                ],
              ),
              _FilterGroup(
                title: 'نسبة الخصم',
                children: [
                  for (final v in const [0, 10, 20, 30, 40])
                    _Chip(v == 0 ? 'كل العروض' : 'خصم $v% فأكثر', localDiscount == v, () => setLocal(() => localDiscount = v)),
                ],
              ),
              _FilterGroup(
                title: 'السعر بعد الخصم',
                children: [
                  _Chip('كل الأسعار', localPrice == 'all', () => setLocal(() => localPrice = 'all')),
                  _Chip(r'أقل من $5', localPrice == 'under5', () => setLocal(() => localPrice = 'under5')),
                  _Chip(r'$5 – $25', localPrice == '5to25', () => setLocal(() => localPrice = '5to25')),
                  _Chip(r'أكثر من $25', localPrice == 'over25', () => setLocal(() => localPrice = 'over25')),
                ],
              ),
              _FilterGroup(
                title: 'التقييم',
                children: [
                  _Chip('كل التقييمات', localRating == 0, () => setLocal(() => localRating = 0)),
                  _Chip('4 نجوم فأعلى', localRating == 4, () => setLocal(() => localRating = 4)),
                  _Chip('4.5 نجوم فأعلى', localRating == 4.5, () => setLocal(() => localRating = 4.5)),
                ],
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 39,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: spikeRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                  onPressed: () {
                    setState(() {
                      sort = localSort;
                      minDiscount = localDiscount;
                      price = localPrice;
                      minRating = localRating;
                    });
                    Navigator.pop(sheetContext);
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allProductsProvider);
    final favorites = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: state.when(
        loading: () => const SpikeLoading(),
        error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(allProductsProvider)),
        data: (all) {
          final list = _apply(all);
          return Column(children: [
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
                        onTap: () => context.canPop() ? context.pop() : context.go('/'),
                        borderRadius: BorderRadius.circular(22),
                        child: const Icon(LucideIcons.arrowRight, size: 23),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('العروض والخصومات', maxLines: 1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  Material(
                    color: dark ? spikeDarkPanel : const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: _filters,
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
              child: list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(LucideIcons.badgePercent, size: 34),
                          const SizedBox(height: 10),
                          const Text('لا توجد عروض فعالة حالياً', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          const Text('سنظهر الخصومات هنا فور إضافتها.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: spikeMuted)),
                          const SizedBox(height: 15),
                          SizedBox(height: 39, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: spikeRed), onPressed: () => context.go('/'), child: const Text('تصفح المنتجات'))),
                        ]),
                      ),
                    )
                  : GridView.builder(
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
                          onAdd: p.cheapestVariant == null
                              ? null
                              : () async {
                                  try {
                                    await ref.read(cartRepositoryProvider).add(variantId: p.cheapestVariant!.id, product: p);
                                    ref.invalidate(cartCountProvider);
                                    if (context.mounted) showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
                                  } catch (e) {
                                    if (context.mounted) showSpikeToast(context, e.toString());
                                  }
                                },
                          onFavorite: _favoriteBusy.contains(p.id) ? null : () => _toggleFavorite(p),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }

  void _noop() {}
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
          decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? spikeDarkPanel : spikePanel, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ])),
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
