import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/providers.dart';
import '../core/theme.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة المنتج إلى السلة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _toggleFavorite(ProductModel product) async {
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
    } finally {
      if (mounted) setState(() => _favoriteBusy.remove(product.id));
    }
  }

  void _showAll(HomeSectionModel section) {
    final reference = section.referenceId;
    switch (section.contentType) {
      case 'stores':
        context.push('/stores');
        return;
      case 'categories':
        context.push('/categories');
        return;
      case 'collections':
        context.push('/collections');
        return;
      default:
        break;
    }

    if (section.sourceType == 'category' && reference != null) {
      context.push('/products?category=${Uri.encodeComponent(reference)}&title=${Uri.encodeComponent(section.title)}');
    } else if (section.sourceType == 'store' && reference != null) {
      context.push('/store/$reference');
    } else if (section.sourceType == 'collection' && reference != null) {
      context.push('/products?collection=${Uri.encodeComponent(reference)}&title=${Uri.encodeComponent(section.title)}');
    } else if (section.sourceType == 'discounts') {
      context.push('/offers');
    } else {
      context.push('/products');
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(wishlistIdsProvider).valueOrNull ?? <String>{};
    return Column(
      children: [
        for (final section in widget.sections) ...[
          const SizedBox(height: 32),
          _SectionTitle(
            title: section.title,
            showAll: section.showAll && section.items.isNotEmpty,
            onShowAll: () => _showAll(section),
          ),
          if (section.contentType == 'products')
            _ProductsStrip(
              items: section.items,
              favorites: favorites,
              favoriteBusy: _favoriteBusy,
              onAdd: _add,
              onFavorite: _toggleFavorite,
            )
          else if (section.contentType == 'stores')
            _StoresStrip(items: section.items)
          else if (section.contentType == 'categories')
            _CategoriesStrip(items: section.items)
          else if (section.contentType == 'collections')
            _CollectionsStrip(items: section.items),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.showAll, this.onShowAll});

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
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
              ),
              if (showAll)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
                  onPressed: onShowAll,
                  child: const Text('عرض الكل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
    if (products.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 246,
      child: ListView.separated(
        reverse: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final product = products[i];
          return SpikeProductCard(
            product: product,
            isFavorite: favorites.contains(product.id),
            onTap: () => context.push('/product/${product.id}'),
            onAdd: !product.purchasable || product.cheapestVariant == null ? null : () => onAdd(product),
            onFavorite: favoriteBusy.contains(product.id) ? null : () => onFavorite(product),
            onStore: product.storeId == null ? null : () => context.push('/store/${product.storeId}'),
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
    if (stores.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 69,
      child: ListView.separated(
        reverse: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        itemCount: stores.length,
        separatorBuilder: (_, __) => const SizedBox(width: 11),
        itemBuilder: (context, i) {
          final store = stores[i];
          return InkWell(
            onTap: () => context.push('/store/${store.id}'),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 154,
              height: 69,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dark ? spikeDarkPanel : const Color(0xFFE9E9E9),
                borderRadius: BorderRadius.circular(22),
              ),
              child: store.logoUrl == null
                  ? Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: CachedNetworkImage(
                        imageUrl: store.logoUrl!,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 120,
      child: ListView.separated(
        reverse: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final category = categories[i];
          return InkWell(
            onTap: () => context.push('/products?category=${Uri.encodeComponent(category.id)}&title=${Uri.encodeComponent(category.name)}'),
            borderRadius: BorderRadius.circular(21),
            child: SizedBox(
              width: 86,
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
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
                            errorWidget: (_, __, ___) => const Icon(LucideIcons.image),
                          ),
                  ),
                  const SizedBox(height: 7),
                  Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
    final collections = items.map(CollectionModel.fromJson).toList();
    if (collections.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 113,
      child: ListView.separated(
        reverse: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(17, 4, 17, 8),
        itemCount: collections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final collection = collections[i];
          return GestureDetector(
            onTap: () {
              final type = (collection.destinationType ?? '').toLowerCase();
              final id = collection.destinationId ?? '';
              if (id.isEmpty) return;
              if (type == 'product') {
                context.push('/product/$id');
              } else if (type == 'category') {
                context.push('/products?category=${Uri.encodeComponent(id)}&title=${Uri.encodeComponent(collection.name)}');
              } else if (type == 'store') {
                context.push('/store/$id');
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 153,
                height: 101,
                child: collection.imageUrl == null
                    ? Container(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08))
                    : CachedNetworkImage(
                        imageUrl: collection.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08)),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
