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
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = false;
  int _page = 1;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void didUpdateWidget(covariant CategoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _load(reset: true);
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
            categoryId: widget.id,
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
    context.push('/category/${Uri.encodeComponent(category.effectiveCategoryId ?? category.id)}');
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final favoriteIds = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    return categories.when(
      loading: () => const Scaffold(body: SpikeLoading()),
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
            body: SafeArea(child: SpikeEmptyState(message: 'الفئة غير موجودة')),
          );
        }
        final current = category;
        final children = all
            .where((item) => item.parentId == current.id && item.enabled)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(categoriesProvider);
                await _load(reset: true);
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 60,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 17),
                        child: Row(children: [
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
                              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ]),
                      ),
                    ),
                  ),
                  if (children.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(17, 14, 17, 10),
                        child: Text('الفئات الفرعية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 122,
                        child: ListView.separated(
                          reverse: true,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          itemCount: children.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final child = children[index];
                            return InkWell(
                              onTap: () => _openCategory(child),
                              borderRadius: BorderRadius.circular(21),
                              child: SizedBox(
                                width: 86,
                                child: Column(children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(21),
                                    ),
                                    child: child.imageUrl == null
                                        ? const Icon(LucideIcons.image)
                                        : SpikeNetworkImage(
                                            url: child.imageUrl,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    child.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(17, 20, 17, 12),
                      child: Text('المنتجات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (_loading)
                    const SliverToBoxAdapter(child: SpikeLoading())
                  else if (_error != null)
                    SliverToBoxAdapter(
                      child: SpikeErrorState(
                        message: _error.toString(),
                        onRetry: () => _load(reset: true),
                      ),
                    )
                  else if (_products.isEmpty)
                    const SliverToBoxAdapter(
                      child: SpikeEmptyState(message: 'لا توجد منتجات في هذه الفئة حالياً'),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(17, 0, 17, 18),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 18,
                          childAspectRatio: .68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = _products[index];
                            return SpikeProductCard(
                              product: product,
                              isFavorite: favoriteIds.contains(product.id),
                              onTap: () => context.push('/product/${product.id}'),
                              onAdd: product.purchasable && product.cheapestVariant != null
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
                          childCount: _products.length,
                        ),
                      ),
                    ),
                  if (_hasNext)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(17, 0, 17, 24),
                        child: OutlinedButton(
                          onPressed: _loadingMore ? null : () => _load(reset: false),
                          child: Text(_loadingMore ? 'جاري التحميل...' : 'عرض المزيد'),
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
