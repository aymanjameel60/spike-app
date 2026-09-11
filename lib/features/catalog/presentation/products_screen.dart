import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_state_widgets.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../widgets/product_card.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({
    super.key,
    this.categoryId,
    this.collectionId,
    this.title = 'المنتجات',
  });

  final String? categoryId;
  final String? collectionId;
  final String title;

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  static const _pageSize = 24;

  final ScrollController _scrollController = ScrollController();
  final Set<String> _favoriteBusy = {};
  final List<ProductModel> _products = [];

  String _sort = 'relevance';
  String _specialFilter = 'all';
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasNext = false;
  int _page = 1;
  Object? _error;
  Object? _loadMoreError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirstPage());
  }

  @override
  void didUpdateWidget(covariant ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId ||
        oldWidget.collectionId != widget.collectionId) {
      _loadFirstPage();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loadingInitial ||
        _loadingMore ||
        !_hasNext) {
      return;
    }
    if (_scrollController.position.extentAfter < 650) {
      _loadNextPage();
    }
  }

  double _discount(ProductModel product) {
    final original = product.originalPrice ?? 0;
    return original > product.price && original > 0
        ? (original - product.price) / original
        : 0;
  }

  CategoryModel? _currentCategory(List<CategoryModel> categories) {
    final categoryId = widget.categoryId?.trim() ?? '';
    final collectionId = widget.collectionId?.trim() ?? '';

    for (final category in categories) {
      if (categoryId.isNotEmpty &&
          (category.effectiveCategoryId == categoryId ||
              category.id == categoryId)) {
        return category;
      }
      if (collectionId.isNotEmpty &&
          (category.effectiveCollectionId == collectionId ||
              category.id == collectionId)) {
        return category;
      }
    }
    return null;
  }

  String _productsLocation({
    String? categoryId,
    String? collectionId,
    required String title,
  }) {
    final params = <String, String>{'title': title};
    if ((categoryId ?? '').isNotEmpty) params['category'] = categoryId!;
    if ((collectionId ?? '').isNotEmpty) params['collection'] = collectionId!;
    return Uri(path: '/products', queryParameters: params).toString();
  }

  void _goToCategory(CategoryModel? category) {
    if (category == null) {
      context.go(_productsLocation(title: 'المنتجات'));
      return;
    }

    final categoryId = category.effectiveCategoryId;
    if (categoryId != null) {
      context.go(
        _productsLocation(categoryId: categoryId, title: category.name),
      );
      return;
    }

    final collectionId = category.effectiveCollectionId;
    if (collectionId != null) {
      context.go(
        _productsLocation(collectionId: collectionId, title: category.name),
      );
      return;
    }

    if (category.actionType == 'all_categories' || category.showAsMore) {
      context.go('/categories');
      return;
    }

    if (category.actionType == 'section') {
      context.go('/');
    }
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _error = null;
      _loadMoreError = null;
      _page = 1;
      _hasNext = false;
      _products.clear();
    });

    try {
      final result = await ref.read(catalogRepositoryProvider).pagedProducts(
            page: 1,
            pageSize: _pageSize,
            categoryId: widget.categoryId,
            collectionId: widget.collectionId,
            offersOnly: _specialFilter == 'offers',
          );
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(result.items);
        _page = result.page;
        _hasNext = result.hasNext;
        _loadingInitial = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingInitial = false;
        _error = error;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || !_hasNext) return;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final result = await ref.read(catalogRepositoryProvider).pagedProducts(
            page: _page + 1,
            pageSize: _pageSize,
            categoryId: widget.categoryId,
            collectionId: widget.collectionId,
            offersOnly: _specialFilter == 'offers',
          );
      if (!mounted) return;
      final known = _products.map((product) => product.id).toSet();
      setState(() {
        _products.addAll(
          result.items.where((product) => !known.contains(product.id)),
        );
        _page = result.page;
        _hasNext = result.hasNext;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = error;
      });
    }
  }

  List<ProductModel> _sortedProducts() {
    final list = _products.toList();
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

  void _showFilters() {
    final categories =
        ref.read(categoriesProvider).valueOrNull ?? const <CategoryModel>[];
    final navigableCategories =
        categories.where((category) => category.opensProducts).toList();
    final currentCategory = _currentCategory(navigableCategories);
    var localSort = _sort;
    var localSpecial = _specialFilter;
    String? localCategoryKey = currentCategory?.id;

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
                        'فلترة وترتيب المنتجات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(LucideIcons.x, size: 20),
                    ),
                    TextButton(
                      onPressed: () => setLocal(() {
                        localSort = 'relevance';
                        localSpecial = 'all';
                        localCategoryKey = null;
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
                    _Chip(
                      'الأكثر صلة',
                      localSort == 'relevance',
                      () => setLocal(() => localSort = 'relevance'),
                    ),
                    _Chip(
                      'السعر: الأقل أولاً',
                      localSort == 'price-low',
                      () => setLocal(() => localSort = 'price-low'),
                    ),
                    _Chip(
                      'السعر: الأعلى أولاً',
                      localSort == 'price-high',
                      () => setLocal(() => localSort = 'price-high'),
                    ),
                    _Chip(
                      'الأعلى تقييمًا',
                      localSort == 'rating',
                      () => setLocal(() => localSort = 'rating'),
                    ),
                    _Chip(
                      'الأعلى خصمًا',
                      localSort == 'discount',
                      () => setLocal(() => localSort = 'discount'),
                    ),
                  ],
                ),
                if (navigableCategories.isNotEmpty)
                  _FilterGroup(
                    title: 'الفئة',
                    children: [
                      _Chip(
                        'الكل',
                        localCategoryKey == null,
                        () => setLocal(() => localCategoryKey = null),
                      ),
                      for (final category in navigableCategories)
                        _Chip(
                          category.name,
                          localCategoryKey == category.id,
                          () => setLocal(() => localCategoryKey = category.id),
                        ),
                    ],
                  ),
                _FilterGroup(
                  title: 'نوع المنتجات',
                  children: [
                    _Chip(
                      'كل المنتجات',
                      localSpecial == 'all',
                      () => setLocal(() => localSpecial = 'all'),
                    ),
                    _Chip(
                      'العروض فقط',
                      localSpecial == 'offers',
                      () => setLocal(() => localSpecial = 'offers'),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                SizedBox(
                  height: 39,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: spikeRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    onPressed: () {
                      CategoryModel? selectedCategory;
                      if (localCategoryKey != null) {
                        for (final category in navigableCategories) {
                          if (category.id == localCategoryKey) {
                            selectedCategory = category;
                            break;
                          }
                        }
                      }

                      final selectedCategoryId =
                          selectedCategory?.effectiveCategoryId;
                      final selectedCollectionId =
                          selectedCategory?.effectiveCollectionId;
                      final currentCategoryId =
                          currentCategory?.effectiveCategoryId ?? widget.categoryId;
                      final currentCollectionId =
                          currentCategory?.effectiveCollectionId ??
                              widget.collectionId;
                      final destinationChanged =
                          selectedCategoryId != currentCategoryId ||
                              selectedCollectionId != currentCollectionId;
                      final specialChanged = localSpecial != _specialFilter;

                      setState(() {
                        _sort = localSort;
                        _specialFilter = localSpecial;
                      });
                      Navigator.pop(sheetContext);

                      if (destinationChanged) {
                        _goToCategory(selectedCategory);
                      } else if (specialChanged) {
                        _loadFirstPage();
                      }
                    },
                    child: const Text(
                      'عرض النتائج',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[];
    final currentCategory = _currentCategory(categories);
    final favorites = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    final dark = Theme.of(context).brightness == Brightness.dark;
    final displayTitle = widget.title != 'المنتجات'
        ? widget.title
        : (currentCategory?.name ?? widget.title);
    final list = _sortedProducts();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      height: 40,
                      child: Material(
                        color: dark
                            ? spikeDarkPanel
                            : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/'),
                          child: const Icon(
                            LucideIcons.arrowRight,
                            size: 23,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            displayTitle,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: dark
                          ? spikeDarkPanel
                          : const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _showFilters,
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.slidersHorizontal, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'ترتيب حسب',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
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
            Expanded(
              child: _loadingInitial
                  ? const SpikeLoading()
                  : _error != null
                      ? SpikeErrorState(
                          message: _error.toString(),
                          onRetry: _loadFirstPage,
                        )
                      : list.isEmpty
                          ? RefreshIndicator(
                              onRefresh: _loadFirstPage,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 180),
                                  SpikeEmptyState(
                                    message:
                                        'لا توجد منتجات في هذا القسم حالياً',
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadFirstPage,
                              child: CustomScrollView(
                                controller: _scrollController,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      17,
                                      4,
                                      17,
                                      12,
                                    ),
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
                                          isFavorite:
                                              favorites.contains(product.id),
                                          onTap: () => context.push(
                                            '/product/${product.id}',
                                          ),
                                          onStore: product.storeId == null
                                              ? null
                                              : () => context.push(
                                                    '/store/${product.storeId}',
                                                  ),
                                          onAdd: product.purchasable &&
                                                  product.cheapestVariant != null
                                              ? () => _add(product)
                                              : null,
                                          onFavorite:
                                              _favoriteBusy.contains(product.id)
                                                  ? null
                                                  : () =>
                                                      _toggleFavorite(product),
                                        );
                                      },
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        17,
                                        4,
                                        17,
                                        24,
                                      ),
                                      child: _loadingMore
                                          ? const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(12),
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            )
                                          : _loadMoreError != null
                                              ? Center(
                                                  child: TextButton.icon(
                                                    onPressed: _loadNextPage,
                                                    icon: const Icon(
                                                      LucideIcons.refreshCw,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'إعادة تحميل المزيد',
                                                    ),
                                                  ),
                                                )
                                              : const SizedBox(height: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
            ),
          ],
        ),
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
            color: Theme.of(context).brightness == Brightness.dark
                ? spikeDarkPanel
                : spikePanel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
              color: selected
                  ? Theme.of(context).colorScheme.surface
                  : null,
            ),
          ),
        ),
      );
}
