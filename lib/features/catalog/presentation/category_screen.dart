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
  int _page = 1;
  Object? _error;
  String _sort = 'relevance';
  String _filter = 'all';
  late String _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.id;
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CategoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _selectedCategoryId = widget.id;
      _sort = 'relevance';
      _filter = 'all';
      _load(reset: true);
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasNext) {
      return;
    }
    if (_scrollController.position.extentAfter < 500) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _page = 1;
        _hasNext = false;
        _products.clear();
      });
    } else {
      if (_loadingMore || !_hasNext) return;
      setState(() => _loadingMore = true);
    }

    try {
      final result = await ref.read(catalogRepositoryProvider).pagedProducts(
            categoryId: _selectedCategoryId,
            includeDescendants: true,
            page: reset ? 1 : _page + 1,
            pageSize: _pageSize,
          );
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error;
      });
    }
  }

  Future<void> _selectSubcategory(CategoryModel category) async {
    final target = category.effectiveCategoryId ?? category.id;

    if (category.effectiveCollectionId != null) {
      context.push(
        '/products?collection=${Uri.encodeComponent(category.effectiveCollectionId!)}&title=${Uri.encodeComponent(category.name)}',
      );
      return;
    }

    final nextId = _selectedCategoryId == target ? widget.id : target;
    if (nextId == _selectedCategoryId) return;

    setState(() {
      _selectedCategoryId = nextId;
      _sort = 'relevance';
      _filter = 'all';
    });

    if (_scrollController.hasClients) {
      final currentOffset = _scrollController.offset;
      await _load(reset: true);
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(
          currentOffset.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
      return;
    }

    await _load(reset: true);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة المنتج إلى السلة')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _favorite(ProductModel product) async {
    if (_favoriteBusy.contains(product.id)) return;
    setState(() => _favoriteBusy.add(product.id));
    final current = ref.read(wishlistIdsProvider).valueOrNull ?? <String>{};
    try {
      if (current.contains(product.id)) {
        await ref.read(engagementRepositoryProvider).removeWishlist(product.id);
      } else {
        await ref.read(engagementRepositoryProvider).addWishlist(product.id);
      }
      ref.invalidate(wishlistIdsProvider);
      ref.invalidate(favoritesProvider);
    } finally {
      if (mounted) setState(() => _favoriteBusy.remove(product.id));
    }
  }

  void _openCategory(CategoryModel category) {
    if (category.effectiveCollectionId != null) {
      context.push(
        '/products?collection=${Uri.encodeComponent(category.effectiveCollectionId!)}&title=${Uri.encodeComponent(category.name)}',
      );
      return;
    }
    context.push(
      '/category/${Uri.encodeComponent(category.effectiveCategoryId ?? category.id)}',
    );
  }

  List<CategoryModel> _rootCategories(List<CategoryModel> all) {
    return all.where((c) => c.enabled && c.isRoot).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> _showSort() async {
    final options = <(String, String)>[
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
    final options = <(String, String)>[
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
                  alignment: WrapAlignment.start,
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

  Widget _closeButton(VoidCallback onTap) {
    return Material(
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
  }

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
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: dark ? spikeDarkPanel : const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _rootPicker(List<CategoryModel> all) {
    final roots = _rootCategories(all);
    if (roots.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'الفئات',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 210, maxHeight: 320),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (id) {
        if (id == widget.id) {
          if (_selectedCategoryId != widget.id) {
            setState(() {
              _selectedCategoryId = widget.id;
              _sort = 'relevance';
              _filter = 'all';
            });
            _load(reset: true);
          }
          return;
        }
        final selected = roots.where((item) => item.id == id).firstOrNull;
        if (selected != null) _openCategory(selected);
      },
      itemBuilder: (context) => [
        for (final root in roots)
          PopupMenuItem<String>(
            value: root.id,
            height: 42,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: root.id == widget.id
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                root.name,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      root.id == widget.id ? FontWeight.w700 : FontWeight.w400,
                ),
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

  Widget _productSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 18,
        childAspectRatio: .68,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        final base = Theme.of(context).colorScheme.surfaceContainerHighest;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 7),
            FractionallySizedBox(
              widthFactor: .62,
              alignment: Alignment.centerRight,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final favoriteIds = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};

    return categories.when(
      loading: () => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Expanded(child: _productSkeletonGrid()),
            ],
          ),
        ),
      ),
      error: (error, _) => Scaffold(
        body: SpikeErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
      ),
      data: (all) {
        CategoryModel? category;
        for (final item in all) {
          if (item.id == widget.id) {
            category = item;
            break;
          }
        }

        if (category == null) {
          return const Scaffold(
            body: SafeArea(
              child: SpikeEmptyState(message: 'الفئة غير موجودة'),
            ),
          );
        }

        final current = category;
        final children = all
            .where((item) => item.parentId == current.id && item.enabled)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final visibleProducts = _visibleProducts();

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(categoriesProvider);
                await _load(reset: true);
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
                                current.name,
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
                  if (current.isRoot && current.bannerUrl != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 3,
                            child: SpikeNetworkImage(
                              url: current.bannerUrl,
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
                            tooltip: 'الترتيب',
                            onTap: _showSort,
                          ),
                          const SizedBox(width: 8),
                          _toolButton(
                            icon: LucideIcons.slidersHorizontal,
                            tooltip: 'الفلتر',
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
                            itemCount: children.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final child = children[index];
                              final target = child.effectiveCategoryId ?? child.id;
                              final selected = _selectedCategoryId == target;
                              final dark = Theme.of(context).brightness == Brightness.dark;

                              return Material(
                                color: selected
                                    ? (dark ? Colors.white : Colors.black)
                                    : (dark
                                        ? spikeDarkPanel
                                        : const Color(0xFFF1F1F1)),
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  onTap: () => _selectSubcategory(child),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: selected
                                            ? Colors.transparent
                                            : Colors.black.withValues(alpha: .08),
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      child.name,
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
                            },
                          ),
                        ),
                      ),
                    ),
                  if (_loading)
                    SliverToBoxAdapter(child: _productSkeletonGrid())
                  else if (_error != null)
                    SliverToBoxAdapter(
                      child: SpikeErrorState(
                        message: _error.toString(),
                        onRetry: () => _load(reset: true),
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
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 18,
                          childAspectRatio: .68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
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
                          childCount: visibleProducts.length,
                        ),
                      ),
                    ),
                  if (_loadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
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
}
