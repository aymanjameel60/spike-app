import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../core/widgets/spike_network_image.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../widgets/product_card.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  static const _pageSize = 24;
  final _products = <ProductModel>[];
  final _favoriteBusy = <String>{};
  final _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = false;
  bool _rootSyncScheduled = false;
  int _page = 1;
  Object? _error;
  String _sort = 'relevance';
  String _filter = 'all';
  late String _rootId;
  String _activeChildId = 'all';
  String _loadedCategoryId = '';

  @override
  void initState() {
    super.initState();
    _rootId = widget.id;
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadCategory(widget.id, reset: true),
    );
  }

  @override
  void didUpdateWidget(covariant CategoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id == widget.id) return;
    _rootId = widget.id;
    _activeChildId = 'all';
    _sort = 'relevance';
    _filter = 'all';
    _rootSyncScheduled = false;
    _loadCategory(widget.id, reset: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  CategoryModel? _byId(List<CategoryModel> all, String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  CategoryModel? _rootFor(List<CategoryModel> all, CategoryModel? category) {
    var current = category;
    var guard = 0;
    while (current?.parentId != null && guard++ < 20) {
      final parent = _byId(all, current!.parentId!);
      if (parent == null) break;
      current = parent;
    }
    return current;
  }

  List<CategoryModel> _roots(List<CategoryModel> all) {
    return all.where((c) => c.enabled && c.isRoot).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  List<CategoryModel> _children(List<CategoryModel> all, String rootId) {
    return all.where((c) => c.enabled && c.parentId == rootId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasNext) {
      return;
    }
    if (_scrollController.position.extentAfter < 500 && _loadedCategoryId.isNotEmpty) {
      _loadCategory(_loadedCategoryId, reset: false);
    }
  }

  Future<void> _loadCategory(String categoryId, {required bool reset}) async {
    if (reset) {
      if (mounted) {
        setState(() {
          _loading = true;
          _loadingMore = false;
          _error = null;
          _page = 1;
          _hasNext = false;
          _products.clear();
          _loadedCategoryId = categoryId;
        });
      }
    } else {
      if (_loadingMore || !_hasNext) return;
      setState(() => _loadingMore = true);
    }

    try {
      final result = await ref.read(catalogRepositoryProvider).pagedProducts(
            categoryId: categoryId,
            includeDescendants: true,
            page: reset ? 1 : _page + 1,
            pageSize: _pageSize,
          );
      if (!mounted || categoryId != _loadedCategoryId) return;
      final known = _products.map((e) => e.id).toSet();
      setState(() {
        if (reset) _products.clear();
        _products.addAll(result.items.where((e) => !known.contains(e.id)));
        _page = result.page;
        _hasNext = result.hasNext;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || categoryId != _loadedCategoryId) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error;
      });
    }
  }

  Future<void> _selectAll() async {
    if (_activeChildId == 'all' && _loadedCategoryId == _rootId) return;
    setState(() => _activeChildId = 'all');
    await _loadCategory(_rootId, reset: true);
  }

  Future<void> _selectChild(CategoryModel category) async {
    if (category.effectiveCollectionId != null) {
      context.push(
        '/products?collection=${Uri.encodeComponent(category.effectiveCollectionId!)}&title=${Uri.encodeComponent(category.name)}',
      );
      return;
    }
    final id = category.id;
    if (_activeChildId == id && _loadedCategoryId == id) return;
    setState(() => _activeChildId = id);
    await _loadCategory(id, reset: true);
  }

  double _discount(ProductModel product) {
    final original = product.originalPrice ?? 0;
    return original > product.price && original > 0
        ? (original - product.price) / original
        : 0;
  }

  List<ProductModel> _visibleProducts() {
    var list = _products.toList();
    if (_filter == 'offers') {
      list = list.where((p) => _discount(p) > 0).toList();
    } else if (_filter == 'rating4') {
      list = list.where((p) => p.rating >= 4).toList();
    } else if (_filter == 'available') {
      list = list.where((p) => p.purchasable).toList();
    }

    if (_sort == 'price-low') {
      list.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sort == 'price-high') {
      list.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sort == 'rating') {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sort == 'discount') {
      list.sort((a, b) => _discount(b).compareTo(_discount(a)));
    }
    return list;
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

  Future<void> _favorite(ProductModel product) async {
    if (_favoriteBusy.contains(product.id)) return;
    setState(() => _favoriteBusy.add(product.id));
    final current = ref.read(wishlistIdsProvider).valueOrNull ?? <String>{};
    final active = current.contains(product.id);
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

  Future<void> _showSort() async {
    const options = <(String, String)>[
      ('relevance', 'الأكثر صلة'),
      ('price-low', 'السعر: من الأقل للأعلى'),
      ('price-high', 'السعر: من الأعلى للأقل'),
      ('rating', 'الأعلى تقييماً'),
      ('discount', 'الأعلى خصماً'),
    ];
    await showModalBottomSheet<void>(
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
                      'الترتيب حسب',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _closeButton(() => Navigator.pop(sheetContext)),
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

  Future<void> _showFilter() async {
    const options = <(String, String)>[
      ('all', 'كل المنتجات'),
      ('offers', 'العروض فقط'),
      ('rating4', '4 نجوم فأعلى'),
      ('available', 'المتوفر حالياً'),
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'فلترة المنتجات',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _filter = 'all');
                        setSheetState(() {});
                      },
                      child: const Text(
                        'مسح الكل',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    _closeButton(() => Navigator.pop(sheetContext)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'عرض المنتجات',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in options)
                      _filterChip(
                        label: option.$2,
                        selected: _filter == option.$1,
                        onTap: () {
                          setState(() => _filter = option.$1);
                          Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _closeButton(VoidCallback onTap) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 34,
            height: 34,
            child: Icon(LucideIcons.x, size: 19, color: Colors.black),
          ),
        ),
      );

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? (dark ? Colors.white : Colors.black)
          : (dark ? spikeDarkPanel : const Color(0xFFF1F1F1)),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? (dark ? Colors.black : Colors.white)
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? spikeDarkPanel : const Color(0xFFEDEDED),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rootPicker(List<CategoryModel> all) {
    final roots = _roots(all);
    if (roots.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'الفئات',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 210, maxHeight: 320),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (id) {
        if (id == _rootId) {
          _selectAll();
          return;
        }
        context.push('/category/${Uri.encodeComponent(id)}');
      },
      itemBuilder: (_) => [
        for (final root in roots)
          PopupMenuItem<String>(
            value: root.id,
            height: 42,
            child: Text(
              root.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    root.id == _rootId ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الفئات',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 6),
            Icon(LucideIcons.chevronDown, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final favoriteIds = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};

    return categories.when(
      loading: () => const Scaffold(body: SafeArea(child: SpikeLoading())),
      error: (error, _) => Scaffold(
        body: SpikeErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
      ),
      data: (all) {
        final routeCategory = _byId(all, widget.id);
        final root = _rootFor(all, routeCategory);
        if (root == null) {
          return const Scaffold(
            body: SafeArea(child: SpikeEmptyState(message: 'الفئة غير موجودة')),
          );
        }

        if (_rootId != root.id && !_rootSyncScheduled) {
          _rootSyncScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final enteredChild = routeCategory != null && !routeCategory.isRoot;
            setState(() {
              _rootId = root.id;
              _activeChildId = enteredChild ? routeCategory.id : 'all';
              _rootSyncScheduled = false;
            });
            _loadCategory(
              enteredChild ? routeCategory.id : root.id,
              reset: true,
            );
          });
        }

        final children = _children(all, root.id);
        final visibleProducts = _visibleProducts();

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(categoriesProvider);
                await _loadCategory(
                  _activeChildId == 'all' ? root.id : _activeChildId,
                  reset: true,
                );
              },
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 60,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/categories'),
                              icon: const Icon(LucideIcons.arrowRight, size: 22),
                            ),
                            Expanded(
                              child: Text(
                                root.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (root.bannerUrl != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 3,
                            child: SpikeNetworkImage(
                              url: root.bannerUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          _rootPicker(all),
                          const Spacer(),
                          _toolButton(
                            icon: LucideIcons.arrowUpDown,
                            label: 'الترتيب',
                            onTap: _showSort,
                          ),
                          const SizedBox(width: 8),
                          _toolButton(
                            icon: LucideIcons.slidersHorizontal,
                            label: 'الفلتر',
                            onTap: _showFilter,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (children.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 52,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                            itemCount: children.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, index) {
                              if (index == 0) {
                                return _subcategoryPill(
                                  label: 'الكل',
                                  selected: _activeChildId == 'all',
                                  onTap: _selectAll,
                                );
                              }
                              final child = children[index - 1];
                              return _subcategoryPill(
                                label: child.name,
                                selected: _activeChildId == child.id,
                                onTap: () => _selectChild(child),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  if (_loading)
                    const SliverToBoxAdapter(child: SpikeLoading())
                  else if (_error != null)
                    SliverToBoxAdapter(
                      child: SpikeErrorState(
                        message: _error.toString(),
                        onRetry: () => _loadCategory(
                          _activeChildId == 'all' ? root.id : _activeChildId,
                          reset: true,
                        ),
                      ),
                    )
                  else if (visibleProducts.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: SpikeEmptyState(
                          message: 'لا توجد منتجات في هذه الفئة حالياً',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(17, 0, 17, 24),
                      sliver: SliverGrid.builder(
                        itemCount: visibleProducts.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 11,
                          mainAxisSpacing: 11,
                          mainAxisExtent: 246,
                        ),
                        itemBuilder: (_, index) {
                          final product = visibleProducts[index];
                          return SpikeProductCard(
                            product: product,
                            isFavorite: favoriteIds.contains(product.id),
                            onTap: () => context.push('/product/${product.id}'),
                            onAdd: product.purchasable &&
                                    product.cheapestVariant != null
                                ? () => _add(product)
                                : null,
                            onFavorite: _favoriteBusy.contains(product.id)
                                ? null
                                : () => _favorite(product),
                            onStore: product.storeId == null
                                ? null
                                : () => context.push('/store/${product.storeId}'),
                          );
                        },
                      ),
                    ),
                  if (_loadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _subcategoryPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? (dark ? Colors.white : Colors.black)
          : (dark ? spikeDarkPanel : const Color(0xFFF1F1F1)),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? (dark ? Colors.black : Colors.white)
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
