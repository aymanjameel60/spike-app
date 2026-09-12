import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/providers.dart';
import '../core/widgets/async_state_widgets.dart';
import '../models/category.dart';
import '../models/collection.dart';
import '../models/home_section.dart';
import '../models/product.dart';
import '../models/store.dart';
import 'product_card.dart';

class DynamicHomeSections extends ConsumerStatefulWidget {
  const DynamicHomeSections({super.key, required this.sections});

  final List<HomeSectionModel> sections;

  @override
  ConsumerState<DynamicHomeSections> createState() => _DynamicHomeSectionsState();
}

class _DynamicHomeSectionsState extends ConsumerState<DynamicHomeSections> {
  final Set<String> _favoriteBusy = {};

  Future<void> _add(ProductModel product) async {
    if (!product.purchasable || product.cheapestVariant == null) return;
    try {
      await ref.read(cartRepositoryProvider).add(
            variantId: product.cheapestVariant!.id,
            product: product,
          );
      ref.invalidate(cartCountProvider);
      if (mounted) showSpikeToast(context, 'تمت إضافة المنتج إلى السلة');
    } catch (error) {
      if (mounted) showSpikeToast(context, error.toString());
    }
  }

  Future<void> _toggleFavorite(ProductModel product) async {
    if (_favoriteBusy.contains(product.id)) return;
    setState(() => _favoriteBusy.add(product.id));
    final current = ref.read(wishlistIdsProvider).valueOrNull ?? <String>{};
    final active = current.contains(product.id);
    try {
      if (active) {
        await ref
            .read(engagementRepositoryProvider)
            .removeWishlist(product.id);
      } else {
        await ref.read(engagementRepositoryProvider).addWishlist(product.id);
      }
      ref.invalidate(wishlistIdsProvider);
      ref.invalidate(favoritesProvider);
    } finally {
      if (mounted) setState(() => _favoriteBusy.remove(product.id));
    }
  }

  void _showAll(HomeSectionModel section) {
    final type = section.showAllTargetType;
    final id = section.showAllTargetId;
    if (type == 'section') {
      context.push('/section/${id ?? section.id}');
      return;
    }
    if (type == 'category' && id != null) {
      context.push('/category/${Uri.encodeComponent(id)}');
      return;
    }
    if (type == 'collection' && id != null) {
      context.push(
        '/products?collection=${Uri.encodeComponent(id)}&title=${Uri.encodeComponent(section.title)}',
      );
      return;
    }
    if (type == 'store' && id != null) {
      context.push('/store/$id');
      return;
    }
    if (type == 'offers') {
      context.push('/offers');
      return;
    }
    if (type == 'categories') {
      context.push('/categories');
      return;
    }
    if (type == 'stores') {
      context.push('/stores');
      return;
    }
    context.push('/section/${section.id}');
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    return Column(
      children: [
        for (var index = 0; index < widget.sections.length; index++) ...[
          if (index > 0) const SizedBox(height: 18),
          _SectionTitle(
            title: widget.sections[index].title,
            showAll: widget.sections[index].showAll,
            onShowAll: () => _showAll(widget.sections[index]),
          ),
          if (widget.sections[index].contentType == 'products')
            _ProductsStrip(
              items: widget.sections[index].items,
              favorites: favorites,
              favoriteBusy: _favoriteBusy,
              onAdd: _add,
              onFavorite: _toggleFavorite,
            )
          else if (widget.sections[index].contentType == 'stores')
            _StoresStrip(items: widget.sections[index].items)
          else if (widget.sections[index].contentType == 'categories')
            _CategoriesStrip(items: widget.sections[index].items)
          else if (widget.sections[index].contentType == 'collections')
            _CollectionsStrip(items: widget.sections[index].items),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.showAll,
    this.onShowAll,
  });

  final String title;
  final bool showAll;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showAll)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: onShowAll,
                  child: const Text(
                    'عرض الكل',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _ProductsStrip extends StatelessWidget {
  const _ProductsStrip({
    required this.items,
    required this.favorites,
    required this.favoriteBusy,
    required this.onAdd,
    required this.onFavorite,
  });

  final List<Map<String, dynamic>> items;
  final Set<String> favorites;
  final Set<String> favoriteBusy;
  final ValueChanged<ProductModel> onAdd;
  final ValueChanged<ProductModel> onFavorite;

  @override
  Widget build(BuildContext context) {
    final products = items.map(ProductModel.fromJson).toList();
    if (products.isEmpty) {
      return const SpikeEmptyState(message: 'لا توجد عناصر في هذا القسم');
    }
    return SizedBox(
      height: 246,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          return SpikeProductCard(
            product: product,
            isFavorite: favorites.contains(product.id),
            onTap: () => context.push('/product/${product.id}'),
            onAdd: !product.purchasable || product.cheapestVariant == null
                ? null
                : () => onAdd(product),
            onFavorite: favoriteBusy.contains(product.id)
                ? null
                : () => onFavorite(product),
            onStore: product.storeId == null
                ? null
                : () => context.push('/store/${product.storeId}'),
          );
        },
      ),
    );
  }
}

class _StoresStrip extends StatelessWidget {
  const _StoresStrip({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final stores = items.map(StoreModel.fromJson).toList();
    if (stores.isEmpty) {
      return const SpikeEmptyState(message: 'لا توجد متاجر');
    }
    return SizedBox(
      height: 69,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        itemCount: stores.length,
        separatorBuilder: (_, __) => const SizedBox(width: 11),
        itemBuilder: (context, index) {
          final store = stores[index];
          return InkWell(
            onTap: () => context.push('/store/${store.id}'),
            borderRadius: BorderRadius.circular(25),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: SizedBox(
                width: 153,
                height: 69,
                child: store.logoUrl == null
                    ? Center(
                        child: Text(
                          store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: store.logoUrl!,
                        fit: BoxFit.cover,
                        width: 153,
                        height: 69,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            store.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoriesStrip extends StatelessWidget {
  const _CategoriesStrip({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final categories = items.map(CategoryModel.fromJson).toList();
    if (categories.isEmpty) {
      return const SpikeEmptyState(message: 'لا توجد فئات');
    }
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 11),
        itemBuilder: (context, index) {
          final category = categories[index];
          return InkWell(
            onTap: () {
              if (category.showAsMore || category.actionType == 'all_categories') {
                context.push('/categories');
                return;
              }
              if (category.actionType == 'section' &&
                  (category.actionTarget ?? '').isNotEmpty) {
                context.push('/section/${category.actionTarget}');
                return;
              }
              if (category.actionType == 'collection' &&
                  (category.actionTarget ?? '').isNotEmpty) {
                context.push(
                  '/products?collection=${Uri.encodeComponent(category.actionTarget!)}&title=${Uri.encodeComponent(category.name)}',
                );
                return;
              }
              context.push(
                '/category/${Uri.encodeComponent(category.effectiveCategoryId ?? category.id)}',
              );
            },
            borderRadius: BorderRadius.circular(21),
            child: SizedBox(
              width: 81,
              child: Column(
                children: [
                  Container(
                    width: 81,
                    height: 81,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: category.imageUrl == null
                        ? const Icon(LucideIcons.image)
                        : CachedNetworkImage(
                            imageUrl: category.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const Icon(LucideIcons.image),
                          ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CollectionsStrip extends StatelessWidget {
  const _CollectionsStrip({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final collections = items.map(CollectionModel.fromJson).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (collections.isEmpty) {
      return const SpikeEmptyState(message: 'لا توجد مجموعات');
    }
    return SizedBox(
      height: 113,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(17, 4, 17, 8),
        itemCount: collections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final collection = collections[index];
          return GestureDetector(
            onTap: () {
              final type = (collection.destinationType ?? '').toLowerCase();
              final id = collection.destinationId ?? '';
              if (id.isEmpty) return;
              if (type == 'product') {
                context.push('/product/$id');
              } else if (type == 'category') {
                context.push('/category/${Uri.encodeComponent(id)}');
              } else if (type == 'store') {
                context.push('/store/$id');
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 153,
                height: 101,
                child: collection.imageUrl == null
                    ? Container(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .08),
                      )
                    : CachedNetworkImage(
                        imageUrl: collection.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .08),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
