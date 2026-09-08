import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../models/product.dart';
import '../../../widgets/product_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery);
  final Set<String> _favoriteBusy = {};
  String _query = '';
  String _sort = 'relevance';
  String _category = 'الكل';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _discount(ProductModel p) {
    final o = p.originalPrice ?? 0;
    return o > p.price && o > 0 ? (o - p.price) / o : 0;
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
            for (final o in const [
              ('relevance', 'الأكثر صلة'),
              ('price-low', 'السعر الأقل'),
              ('price-high', 'السعر الأعلى'),
              ('rating', 'الأعلى تقييماً'),
              ('discount', 'الأعلى خصماً'),
            ])
              InkWell(
                onTap: () {
                  setState(() => _sort = o.$1);
                  Navigator.pop(sheetContext);
                },
                child: SizedBox(
                  height: 48,
                  child: Row(children: [
                    Expanded(child: Text(o.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    Icon(_sort == o.$1 ? Icons.radio_button_checked : Icons.radio_button_off, size: 19),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allProductsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final favorites = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    final dark = Theme.of(context).brightness == Brightness.dark;
    final field = dark ? spikeDarkPanel : const Color(0xFFE7E7E7);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 8, 17, 8),
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
              const SizedBox(width: 9),
              Expanded(
                child: Container(
                  height: 39,
                  decoration: BoxDecoration(color: field, borderRadius: BorderRadius.circular(22)),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن المنتجات ...',
                      hintStyle: spikeTextStyle(fontSize: 12, color: const Color(0xFFBDBDBD)),
                      prefixIcon: const Icon(LucideIcons.search, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(LucideIcons.x, size: 17),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                            ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                width: 50,
                height: 40,
                child: Material(
                  color: dark ? spikeDarkPanel : const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(onTap: _showSort, borderRadius: BorderRadius.circular(22), child: const Icon(LucideIcons.arrowUpDown, size: 19)),
                ),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(17, 8, 17, 14),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SizedBox(
              height: 36,
              child: ListView(
                reverse: true,
                scrollDirection: Axis.horizontal,
                children: [
                  _QuickChip(label: 'عروض', selected: _category == 'عروض', onTap: () => setState(() => _category = 'عروض')),
                  const SizedBox(width: 8),
                  _QuickChip(label: 'الكل', selected: _category == 'الكل', onTap: () => setState(() => _category = 'الكل')),
                  for (final c in categories) ...[
                    const SizedBox(width: 8),
                    _QuickChip(label: c.name, selected: _category == c.name, onTap: () => setState(() => _category = c.name)),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const SpikeLoading(),
              error: (e, _) => SpikeErrorState(message: e.toString(), onRetry: () => ref.invalidate(allProductsProvider)),
              data: (products) {
                final q = _query.toLowerCase();
                final list = products.where((p) {
                  final matches = q.isEmpty || p.name.toLowerCase().contains(q) || p.storeName.toLowerCase().contains(q) || (p.categoryName ?? '').toLowerCase().contains(q);
                  return matches && (_category == 'الكل' || _category == 'عروض' || p.categoryName == _category) && (_category != 'عروض' || _discount(p) > 0);
                }).toList();

                if (_sort == 'price-low') list.sort((a, b) => a.price.compareTo(b.price));
                if (_sort == 'price-high') list.sort((a, b) => b.price.compareTo(a.price));
                if (_sort == 'rating') list.sort((a, b) => b.rating.compareTo(a.rating));
                if (_sort == 'discount') list.sort((a, b) => _discount(b).compareTo(_discount(a)));

                if (list.isEmpty) {
                  return SpikeEmptyState(message: _query.isEmpty ? 'ابدأ بكتابة اسم المنتج أو المتجر' : 'لا توجد نتائج لـ "$_query"');
                }

                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(17, 4, 17, 7),
                    child: Align(alignment: Alignment.centerRight, child: Text('${list.length} نتيجة', style: const TextStyle(fontSize: 10, color: spikeMuted))),
                  ),
                  Expanded(
                    child: GridView.builder(
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
                          onAdd: p.purchasable && p.cheapestVariant != null
                              ? () async {
                                  try {
                                    await ref.read(cartRepositoryProvider).add(variantId: p.cheapestVariant!.id, product: p);
                                    ref.invalidate(cartCountProvider);
                                    if (context.mounted) showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
                                  } catch (e) {
                                    if (context.mounted) showSpikeToast(context, e.toString());
                                  }
                                }
                              : null,
                          onFavorite: _favoriteBusy.contains(p.id) ? null : () => _toggleFavorite(p),
                        );
                      },
                    ),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.onSurface : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF24252A) : const Color(0xFFE8E8E8)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: selected ? Theme.of(context).colorScheme.surface : null)),
        ),
      );
}
